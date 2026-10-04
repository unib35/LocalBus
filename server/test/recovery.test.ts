import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { collect, ProviderError, BudgetExhaustedError } from '../src/collect.ts';
import { openCheckpoint } from '../src/checkpoint.ts';
import { atomicJSON, loadSnapshot, publish, withLock } from '../src/store.ts';
import type { Snapshot } from '../src/contract.ts';
import type { Config, Slot } from '../src/schedule.ts';

const fixture: Snapshot = JSON.parse(await readFile(new URL('../fixtures/arrival-estimates.json', import.meta.url), 'utf8'));
const config: Config = JSON.parse(await readFile(new URL('../config/routes.json', import.meta.url), 'utf8'));
const route = { ...config.routes[0], routeVersion: 'test-v1', correctionVersion: 'test-v1', correctionSeconds: 120 };
const slots: Slot[] = [420, 480].map(departureMinute => ({ route, serviceDate: '2026-10-05', departureMinute }));
const now = () => new Date('2026-10-04T10:00:00Z');
const options = { maxRequests: 10, reserve: async () => {}, now, wait: async () => {} };
const response = { durationSeconds: 1800, source: 'synthetic' as const };
async function temporary(action: (directory: string) => Promise<void>) {
  const directory = await mkdtemp(join(tmpdir(), 'localbus-recovery-'));
  try { await action(directory); } finally { await rm(directory, { recursive: true, force: true }); }
}

test('interrupted collection resumes persisted successes before any public snapshot exists', async () => {
  await temporary(async directory => {
    await assert.rejects(withLock(directory, async () => {
      const checkpoint = await openCheckpoint(directory, '2026-10-05', slots, 'synthetic', undefined, now);
      let calls = 0;
      await collect(slots, '2026-10-05', async () => {
        if (++calls === 2) throw Error('interrupted');
        return response;
      }, { ...options, onSample: checkpoint.save });
    }), /interrupted/);
    assert.equal(await loadSnapshot(directory), undefined);
    await withLock(directory, async () => {
      const checkpoint = await openCheckpoint(directory, '2026-10-05', slots, 'synthetic', undefined, now);
      assert.equal(checkpoint.previous.length, 1);
      const called: number[] = [];
      const result = await collect(slots, '2026-10-05', async slot => {
        called.push(slot.departureMinute); return response;
      }, { ...options, previous: checkpoint.previous, onSample: checkpoint.save });
      assert.deepEqual(called, [480]);
      assert.equal(result.snapshot.samples.length, 2);
      await publish(directory, result.snapshot, false);
      assert.equal((await loadSnapshot(directory))?.samples.length, 2);
    });
  });
});

test('checkpoint storage failure aborts without retrying a successful API call', async () => {
  let calls = 0;
  await assert.rejects(collect(slots, '2026-10-05', async () => { calls++; return response; }, {
    ...options, onSample: async () => { throw Error('disk unavailable'); },
  }), /disk unavailable/);
  assert.equal(calls, 1);
});

test('checkpoint rejects changed routes, corrections, source and expired coverage', async () => {
  await temporary(async directory => {
    await atomicJSON(join(directory, 'checkpoint.json'), fixture);
    for (const changed of [
      { ...route, routeVersion: 'new-route' },
      { ...route, correctionVersion: 'new-correction' },
      { ...route, correctionSeconds: 180 },
    ]) {
      const checkpoint = await openCheckpoint(directory, '2026-10-05', slots.map(s => ({ ...s, route: changed })), 'synthetic', undefined, now);
      assert.equal(checkpoint.previous.length, 0);
    }
    assert.equal((await openCheckpoint(directory, '2026-10-05', slots, 'kakao-future', undefined, now)).previous.length, 0);
    assert.equal((await openCheckpoint(directory, '2026-10-05', slots, 'synthetic', undefined,
      () => new Date(fixture.validUntil))).previous.length, 0);
  });
});

test('checkpoint merges newer results without losing other already successful slots', async () => {
  await temporary(async directory => {
    await atomicJSON(join(directory, 'checkpoint.json'), { ...fixture, samples: [fixture.samples[0]] });
    const latest: Snapshot = { ...fixture, generatedAt: '2026-10-04T11:00:00Z', samples: fixture.samples.map(s => ({
      ...s, durationSeconds: 3000, fetchedAt: '2026-10-04T11:00:00Z',
    })) };
    const checkpoint = await openCheckpoint(directory, '2026-10-05', slots, 'synthetic', latest,
      () => new Date('2026-10-04T12:00:00Z'));
    assert.deepEqual(checkpoint.previous.map(s => s.durationSeconds), [3000, 3000]);
    await checkpoint.save({ ...latest.samples[0], durationSeconds: 3100 });
    assert.deepEqual((await loadSnapshot(directory, 'checkpoint.json'))?.samples.map(s => s.durationSeconds), [3100, 3000]);
  });
});

test('corrupted checkpoints fail closed rather than silently spending the API budget again', async () => {
  await temporary(async directory => {
    await writeFile(join(directory, 'checkpoint.json'), '{broken');
    await assert.rejects(openCheckpoint(directory, '2026-10-05', slots, 'synthetic', undefined, now));
  });
});

test('failure report distinguishes authentication, rate limits, request budget and monthly budget', async () => {
  for (const status of [401, 403, 429]) {
    const result = await collect(slots, '2026-10-05', async () => { throw new ProviderError(status); }, options);
    assert.equal(result.requests, 1);
    assert.deepEqual(result.failures.map(f => f.reason), [`provider-${status}`, `provider-${status}`]);
  }
  const limited = await collect(slots, '2026-10-05', async () => response, { ...options, maxRequests: 1 });
  assert.equal(limited.failures[0].reason, 'request-budget-exhausted');
  const monthly = await collect(slots, '2026-10-05', async () => response, {
    ...options, reserve: async () => { throw new BudgetExhaustedError(); },
  });
  assert.equal(monthly.requests, 0);
  assert.ok(monthly.failures.every(f => f.reason === 'monthly-budget-exhausted'));
  await assert.rejects(collect(slots, '2026-10-05', async () => response, {
    ...options, reserve: async () => { throw Error('ledger corrupted'); },
  }), /ledger corrupted/);
});

test('temporary failures retry at most twice and invalid responses are not retried', async () => {
  const unavailable = await collect(slots, '2026-10-05', async () => { throw new ProviderError(503); }, options);
  assert.equal(unavailable.requests, 6);
  assert.ok(unavailable.failures.every(f => f.reason === 'provider-503'));
  const invalid = await collect(slots, '2026-10-05', async () => ({ ...response, durationSeconds: -1 }), options);
  assert.equal(invalid.requests, 2);
  assert.ok(invalid.failures.every(f => f.reason === 'provider-422'));
});


test('publish resumes after history write and keeps latest unchanged on snapshot id collision', async () => {
  await temporary(async directory => {
    await withLock(directory, async () => {
      await mkdir(join(directory, 'snapshots'));
      await atomicJSON(join(directory, 'snapshots', `${fixture.snapshotId}.json`), fixture);
      assert.equal(await loadSnapshot(directory), undefined);
      await publish(directory, fixture, false);
      await publish(directory, fixture, false);
      await assert.rejects(publish(directory, { ...fixture, enabled: false }, false), /different data/);
      assert.deepEqual(await loadSnapshot(directory), fixture);
    });
  });
});
