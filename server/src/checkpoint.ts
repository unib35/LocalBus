import { key, nextDay, validateSnapshot } from './contract.ts';
import type { Sample, Snapshot } from './contract.ts';
import type { Slot } from './schedule.ts';
import { atomicJSON, loadSnapshot } from './store.ts';
import { join } from 'node:path';

// Caller holds the collection directory lock. A checkpoint is never a public document.
export async function openCheckpoint(directory: string, start: string, slots: Slot[],
  source: Sample['source'], previous?: Snapshot, now: () => Date = () => new Date()) {
  const checkpoint = await loadSnapshot(directory, 'checkpoint.json');
  const planned = new Map(slots.map(slot => [key({ ...slot.route, ...slot }), slot.route]));
  const samples = new Map<string, Sample>();
  for (const snapshot of [previous, checkpoint]) {
    if (!snapshot?.enabled || Date.parse(snapshot.validUntil) <= +now()) continue;
    for (const sample of snapshot.samples) {
      const route = planned.get(key(sample));
      if (!route || sample.source !== source || sample.serviceDate < start
          || sample.serviceDate >= nextDay(start, 7)
          || sample.correctionVersion !== route.correctionVersion
          || sample.correctionSeconds !== route.correctionSeconds) continue;
      const existing = samples.get(key(sample));
      if (!existing || Date.parse(sample.fetchedAt) > Date.parse(existing.fetchedAt)) samples.set(key(sample), sample);
    }
  }
  return {
    previous: [...samples.values()],
    async save(sample: Sample) {
      samples.set(key(sample), sample);
      const snapshot: Snapshot = {
        schemaVersion: 1, snapshotId: 'checkpoint', timezone: 'Asia/Seoul', enabled: true,
        generatedAt: now().toISOString().replace(/\.\d{3}Z$/, 'Z'),
        validFrom: `${start}T00:00:00+09:00`, validUntil: `${nextDay(start, 7)}T00:00:00+09:00`,
        samples: [...samples.values()],
      };
      await atomicJSON(join(directory, 'checkpoint.json'), validateSnapshot(snapshot));
    },
  };
}
