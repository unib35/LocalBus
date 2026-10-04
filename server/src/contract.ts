export type Sample = {
  routeId: string; variantId: string; routeVersion: string; correctionVersion: string;
  serviceDate: string; departureMinute: number; durationSeconds: number;
  correctionSeconds: number; fetchedAt: string; source: 'synthetic' | 'kakao-future';
};
export type Snapshot = {
  schemaVersion: 1; snapshotId: string; generatedAt: string; timezone: 'Asia/Seoul';
  validFrom: string; validUntil: string; enabled: boolean; samples: Sample[];
};
export const key = (s: Pick<Sample, 'routeId' | 'variantId' | 'routeVersion' | 'serviceDate' | 'departureMinute'>) =>
  [s.routeId, s.variantId, s.routeVersion, s.serviceDate, s.departureMinute].join('|');
export const kstDay = (date: Date) => new Date(date.getTime() + 9 * 3600000).toISOString().slice(0, 10);
export function dayStart(day: string): Date {
  const value = new Date(`${day}T00:00:00+09:00`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !Number.isFinite(+value) || kstDay(value) !== day) throw Error('Invalid service date');
  return value;
}
export const nextDay = (day: string, offset: number) => kstDay(new Date(+dayStart(day) + offset * 86400000));
export const instant = (day: string, minute: number) => new Date(+dayStart(day) + minute * 60000);
const validDate = (v: unknown): v is string => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})$/.test(v) && Number.isFinite(Date.parse(v));
const text = (v: unknown) => typeof v === 'string' && v.length > 0;
const integer = (v: unknown, min: number, max: number) => Number.isInteger(v) && Number(v) >= min && Number(v) <= max;

export function validateSnapshot(input: unknown): Snapshot {
  const s = input as Snapshot;
  if (!s || s.schemaVersion !== 1 || !text(s.snapshotId) || s.timezone !== 'Asia/Seoul'
      || typeof s.enabled !== 'boolean' || !validDate(s.generatedAt) || !validDate(s.validFrom)
      || !validDate(s.validUntil) || Date.parse(s.validFrom) >= Date.parse(s.validUntil)
      || Date.parse(s.generatedAt) >= Date.parse(s.validUntil)
      || Date.parse(s.validUntil) - Date.parse(s.validFrom) > 8 * 86400000
      || !Array.isArray(s.samples) || s.samples.length > 10000) throw Error('Invalid snapshot');
  const keys = new Set<string>();
  for (const row of s.samples) {
    if (!row || ![row.routeId, row.variantId, row.routeVersion, row.correctionVersion].every(text)
        || !integer(row.departureMinute, 0, 1439) || !integer(row.durationSeconds, 1, 21600)
        || !integer(row.correctionSeconds, 0, 3600) || !validDate(row.fetchedAt)
        || Date.parse(row.fetchedAt) > Date.parse(s.generatedAt)
        || !['synthetic', 'kakao-future'].includes(row.source)) throw Error('Invalid sample');
    const departure = +instant(row.serviceDate, row.departureMinute);
    if (departure < Date.parse(s.validFrom) || departure >= Date.parse(s.validUntil) || keys.has(key(row))) throw Error('Invalid sample coverage');
    keys.add(key(row));
  }
  return s;
}
