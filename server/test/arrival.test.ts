import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { validateSnapshot, key } from '../src/contract.ts';
import { collect, ProviderError } from '../src/collect.ts';
import { schedule } from '../src/schedule.ts';
import type { Config, Slot, Timetable } from '../src/schedule.ts';
import { loadSnapshot, publish, reserveBudget, withLock } from '../src/store.ts';
import { kakaoProvider } from '../src/provider.ts';

const fixture = JSON.parse(await readFile(new URL('../fixtures/arrival-estimates.json', import.meta.url), 'utf8'));
const config: Config = JSON.parse(await readFile(new URL('../config/routes.json', import.meta.url), 'utf8'));
const route = { ...config.routes[0], routeVersion: 'test-v1', correctionVersion: 'test-v1', correctionSeconds: 120 };
const timetable: Timetable = { holidays: ['2026-10-09'], routes: {
  [route.routeId]: { duration_minutes: 26, via_times: ['08:20'], timetable: {
    weekday: ['06:20', '08:20', '09:40'], weekend: ['07:30', '08:20', '10:00'],
  } },
} };
const slots: Slot[] = [420, 480].map(departureMinute => ({ route, serviceDate: '2026-10-05', departureMinute }));
const now = () => new Date('2026-10-04T10:00:00Z');
const options = { maxRequests: 10, reserve: async () => {}, now, wait: async () => {} };

test('shared contract accepts fixture and rejects duplicate, date, version, duration and coverage corruption', () => {
  assert.equal(validateSnapshot(fixture).samples.length, 2);
  for (const mutate of [
    (v: any) => v.samples.push(v.samples[0]),
    (v: any) => v.schemaVersion = 2,
    (v: any) => v.samples[0].durationSeconds = -1,
    (v: any) => v.samples[0].serviceDate = '2026-02-30',
    (v: any) => v.samples[0].serviceDate = '2026-10-12',
    (v: any) => v.samples[0].fetchedAt = '2026-10-05T10:00:00Z',
    (v: any) => v.validUntil = '2027-01-01T00:00:00Z',
  ]) { const copy = structuredClone(fixture); mutate(copy); assert.throws(() => validateSnapshot(copy)); }
});
test('schedule separates holiday, regular and via slots, covers endpoints without duplicates', () => {
  const result = schedule({ ...config, routes: [route, { ...route, variantId: 'via' }] }, timetable, '2026-10-05');
  assert.deepEqual(result.filter(s => s.serviceDate === '2026-10-05' && s.route.variantId === 'regular').map(s => s.departureMinute), [380, 420, 480, 540, 580]);
  assert.deepEqual(result.filter(s => s.serviceDate === '2026-10-09' && s.route.variantId === 'regular').map(s => s.departureMinute), [450, 480, 540, 600]);
  assert.equal(result.filter(s => s.route.variantId === 'via').length, 7);
  assert.equal(new Set(result.map(s => key({ ...s.route, ...s }))).size, result.length);
});
test('temporary provider errors retry, fatal authentication stops whole batch', async () => {
  let calls = 0;
  const result = await collect(slots, '2026-10-05', async () => {
    calls++; if (calls <= 2) throw new ProviderError(503);
    return { durationSeconds: 1800, source: 'synthetic' };
  }, options);
  assert.equal(result.requests, 4); assert.equal(result.snapshot.samples.length, 2);
  for (const status of [401, 403, 429]) {
    const failed = await collect(slots, '2026-10-05', async () => { throw new ProviderError(status); }, options);
    assert.equal(failed.requests, 1); assert.equal(failed.failures.length, 2);
  }
});
test('request budget includes retries; previous success is reused and missing slot stays missing', async () => {
  const result = await collect(slots, '2026-10-05', async () => { throw new ProviderError(503); }, { ...options, maxRequests: 1 });
  assert.equal(result.requests, 1); assert.equal(result.snapshot.samples.length, 0);
  const resumed = await collect(slots, '2026-10-05', async () => { throw new ProviderError(422); }, { ...options, previous: [fixture.samples[0]] });
  assert.equal(resumed.requests, 1); assert.deepEqual(resumed.snapshot.samples, [fixture.samples[0]]);
});
test('past slots never call provider', async () => {
  const result = await collect(slots, '2026-10-05', async () => { throw Error('must not call'); }, { ...options, now: () => new Date('2026-10-06T00:00:00Z') });
  assert.equal(result.requests, 0); assert.equal(result.failures.length, 2);
});
test('publisher preserves last valid version, rejects synthetic production and overlapping collectors', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'localbus-publish-'));
  try {
    await withLock(directory, async () => {
      await publish(directory, fixture, false);
      await assert.rejects(withLock(directory, async () => {}));
      await assert.rejects(publish(directory, { ...fixture, snapshotId: 'bad' }, true));
      await assert.rejects(publish(directory, { ...fixture, snapshotId: 'empty', samples: [] }, false));
      assert.equal((await loadSnapshot(directory))?.snapshotId, fixture.snapshotId);
      await reserveBudget(directory, '2026-10', 1);
      await assert.rejects(reserveBudget(directory, '2026-10', 1));
    });
    await withLock(directory, async () => { await reserveBudget(directory, '2026-11', 1); });
  } finally { await rm(directory, { recursive: true, force: true }); }
});
test('live provider enforces reviewed corridor and sends future departure and waypoints', async () => {
  const reviewed = { ...route, verified: true, waypoints: [[128.8, 35.2], [128.81, 35.2]] as [number, number][],
    corridor: [[128.8, 35.2], [128.81, 35.2]] as [number, number][], minDistanceMeters: 500, maxDistanceMeters: 2000 };
  let outside = false;
  const request = (async (url: URL, init: RequestInit) => {
    assert.equal(url.searchParams.get('departure_time'), '202610050700');
    assert.equal(new Headers(init.headers).get('Authorization'), 'KakaoAK test-only');
    return Response.json({ routes: [{ result_code: 0, summary: { duration: 120, distance: 1000 },
      sections: [{ roads: [{ vertexes: outside ? [130, 36] : [128.8, 35.2, 128.81, 35.2] }] }] }] });
  }) as typeof fetch;
  const provider = kakaoProvider('test-only', request);
  assert.equal((await provider({ ...slots[0], route: reviewed })).durationSeconds, 120);
  outside = true;
  await assert.rejects(provider({ ...slots[0], route: reviewed }), ProviderError);
  await assert.rejects(provider(slots[0]), /review/);
});
