import { instant, key, nextDay, validateSnapshot } from './contract.ts';
import type { Sample, Snapshot } from './contract.ts';
import type { Slot } from './schedule.ts';
export class BudgetExhaustedError extends Error {}
export class ProviderError extends Error {
  status: number;
  constructor(status: number) { super(`Provider status ${status}`); this.status = status; }
}
export type Provider = (slot: Slot) => Promise<{ durationSeconds: number; source: Sample['source'] }>;
export async function collect(slots: Slot[], start: string, provider: Provider, options: {
  maxRequests: number; reserve: () => Promise<void>; now?: () => Date;
  wait?: (ms: number) => Promise<void>; previous?: Sample[];
  onSample?: (sample: Sample) => Promise<void>;
}) {
  const now = options.now ?? (() => new Date());
  const wait = options.wait ?? (ms => new Promise(r => setTimeout(r, ms)));
  const samples: Sample[] = [];
  const failures: { key: string; reason: string }[] = [];
  if (!Number.isInteger(options.maxRequests) || options.maxRequests < 1) throw Error('Invalid request budget');
  let requests = 0;
  let stopReason: string | undefined;
  for (const slot of slots) {
    const identity = { ...slot.route, serviceDate: slot.serviceDate, departureMinute: slot.departureMinute };
    const old = options.previous?.find(s => key(s) === key(identity)
      && s.correctionVersion === slot.route.correctionVersion && s.correctionSeconds === slot.route.correctionSeconds);
    if (old) { samples.push(old); continue; }
    if (+instant(slot.serviceDate, slot.departureMinute) <= +now()) {
      failures.push({ key: key(identity), reason: 'past-departure' }); continue;
    }
    let success = false;
    let reason = stopReason ?? 'provider-failure';
    for (let attempt = 0; attempt < 3 && !stopReason; attempt++) {
      if (requests >= options.maxRequests) { stopReason = 'request-budget-exhausted'; break; }
      try { await options.reserve(); }
      catch (error) {
        if (error instanceof BudgetExhaustedError) { stopReason = 'monthly-budget-exhausted'; break; }
        throw error; // Storage failures must not be treated as upstream API failures.
      }
      requests++;
      try {
        const result = await provider(slot);
        if (!Number.isInteger(result.durationSeconds) || result.durationSeconds <= 0 || result.durationSeconds > 21600) throw new ProviderError(422);
        samples.push({ routeId: slot.route.routeId, variantId: slot.route.variantId,
          routeVersion: slot.route.routeVersion, correctionVersion: slot.route.correctionVersion,
          serviceDate: slot.serviceDate, departureMinute: slot.departureMinute,
          durationSeconds: result.durationSeconds, correctionSeconds: slot.route.correctionSeconds,
          fetchedAt: now().toISOString().replace('.000Z', 'Z').replace(/\.\d{3}Z$/, 'Z'), source: result.source });
        success = true; break;
      } catch (error) {
        if (!(error instanceof ProviderError)) throw error;
        reason = `provider-${error.status}`;
        if ([401, 403, 429].includes(error.status)) { stopReason = reason; break; }
        if (error.status < 500 || attempt === 2) break;
        await wait(500 * 2 ** attempt);
      }
    }
    if (success) await options.onSample?.(samples.at(-1)!);
    else failures.push({ key: key(identity), reason: stopReason ?? reason });
  }
  const generatedAt = now().toISOString().replace(/\.\d{3}Z$/, 'Z');
  const snapshot: Snapshot = { schemaVersion: 1, snapshotId: crypto.randomUUID(), generatedAt,
    timezone: 'Asia/Seoul', validFrom: `${start}T00:00:00+09:00`,
    validUntil: `${nextDay(start, 7)}T00:00:00+09:00`, enabled: true, samples };
  return { snapshot: validateSnapshot(snapshot), requests, failures };
}
