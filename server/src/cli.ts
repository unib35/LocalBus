import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { collect } from './collect.ts';
import { openCheckpoint } from './checkpoint.ts';
import { kstDay, nextDay, instant, validateSnapshot } from './contract.ts';
import { schedule } from './schedule.ts';
import type { Config, Timetable } from './schedule.ts';
import { kakaoProvider, validateRouteConfig } from './provider.ts';
import { atomicJSON, loadSnapshot, publish, reserveBudget, withLock } from './store.ts';

const root = fileURLToPath(new URL('..', import.meta.url));
const [mode = 'plan', requestedStart] = process.argv.slice(2);
const json = async (path: string) => JSON.parse(await readFile(path, 'utf8'));
async function main() {
  if (!['plan', 'demo', 'collect'].includes(mode)) throw Error('Use plan, demo, or collect [YYYY-MM-DD]');
  const today = kstDay(new Date());
  const start = requestedStart ?? nextDay(today, 1);
  const config: Config = await json(resolve(root, 'config/routes.json'));
  const timetable: Timetable = await json(resolve(root, '../LocalBusApp/LocalBusApp/Resources/timetable.json'));
  if (!Number.isInteger(config.maxRequests) || config.maxRequests < 1 || config.maxRequests > 10000
      || !Number.isInteger(config.monthlyLimit) || config.monthlyLimit < 1) throw Error('Invalid request budget');
  const slots = schedule(config, timetable, start);
  if (mode === 'plan') {
    console.log(JSON.stringify({ start, endExclusive: nextDay(start, 7), requests: slots.length,
      maxRequestsIncludingRetries: config.maxRequests, reviewedRoutes: config.routes.filter(r => r.verified).length,
      routes: config.routes.length, usageApproved: config.usageApproved }, null, 2));
    return;
  }
  const production = mode === 'collect';
  if (production) {
    if (!config.usageApproved || !process.env.KAKAO_REST_API_KEY) throw Error('Usage approval and KAKAO_REST_API_KEY required');
    config.routes.forEach(validateRouteConfig);
  }
  const output = resolve(root, production ? 'dist/live' : 'dist/demo');
  await withLock(output, async () => {
    const previous = await loadSnapshot(output);
    const checkpoint = await openCheckpoint(output, start, slots,
      production ? 'kakao-future' : 'synthetic', previous);
    const provider = production ? kakaoProvider(process.env.KAKAO_REST_API_KEY!) : async (slot: typeof slots[number]) => ({
      durationSeconds: timetable.routes[slot.route.routeId].duration_minutes * 60 + (slot.departureMinute >= 420 && slot.departureMinute <= 540 ? 300 : 0),
      source: 'synthetic' as const,
    });
    const result = await collect(slots, start, provider, {
      maxRequests: config.maxRequests, previous: checkpoint.previous, onSample: checkpoint.save,
      reserve: () => reserveBudget(output, kstDay(new Date()).slice(0, 7), config.monthlyLimit),
    });
    // Preserve today's still-valid coverage when preparing tomorrow's week.
    if (previous?.enabled && start === nextDay(today, 1) && Date.parse(previous.validUntil) > Date.now()) {
      const retained = previous.samples.filter(s => s.serviceDate === today
        && s.source === (production ? 'kakao-future' : 'synthetic')
        && +instant(s.serviceDate, s.departureMinute) >= Date.parse(previous.validFrom)
        && config.routes.some(r => r.routeId === s.routeId && r.variantId === s.variantId
          && r.routeVersion === s.routeVersion && r.correctionVersion === s.correctionVersion
          && r.correctionSeconds === s.correctionSeconds));
      if (retained.length) {
        result.snapshot.validFrom = `${today}T00:00:00+09:00`;
        result.snapshot.samples.unshift(...retained);
      }
    }
    validateSnapshot(result.snapshot);
    await atomicJSON(resolve(output, 'last-run.json'), { generatedAt: result.snapshot.generatedAt,
      requests: result.requests, samples: result.snapshot.samples.length, failures: result.failures });
    await publish(output, result.snapshot, production);
    console.log(JSON.stringify({ mode, requests: result.requests, samples: result.snapshot.samples.length,
      failures: result.failures.length, output: resolve(output, 'latest.json') }, null, 2));
  });
}
main().catch(error => { console.error(error instanceof Error ? error.message : 'Collection failed'); process.exitCode = 1; });
