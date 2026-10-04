import { dayStart, nextDay } from './contract.ts';
export type RouteConfig = {
  routeId: string; variantId: 'regular' | 'via'; routeVersion: string;
  verified: boolean; correctionVersion: string; correctionSeconds: number;
  intervalMinutes: number; waypoints: [number, number][];
  minDistanceMeters: number; maxDistanceMeters: number;
  corridor: [number, number][]; corridorToleranceMeters: number;
};
export type Config = { usageApproved: boolean; maxRequests: number; monthlyLimit: number; routes: RouteConfig[] };
export type Timetable = { holidays: string[]; routes: Record<string, {
  duration_minutes: number; via_times?: string[];
  timetable: { weekday: string[]; weekend: string[] };
}> };
export type Slot = { route: RouteConfig; serviceDate: string; departureMinute: number };
export function minute(time: string): number {
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) throw Error('Invalid timetable time');
  const [h, m] = time.split(':').map(Number); return h * 60 + m;
}
export function schedule(config: Config, timetable: Timetable, start: string): Slot[] {
  dayStart(start);
  const result: Slot[] = [];
  const seen = new Set<string>();
  for (const route of config.routes) {
    const routeKey = `${route.routeId}|${route.variantId}`;
    if (seen.has(routeKey) || ![30, 60].includes(route.intervalMinutes)
        || !Number.isInteger(route.correctionSeconds) || route.correctionSeconds < 0 || route.correctionSeconds > 3600) throw Error('Invalid route configuration');
    seen.add(routeKey);
    const entry = timetable.routes[route.routeId];
    if (!entry) throw Error('Unknown route');
    for (let d = 0; d < 7; d++) {
      const serviceDate = nextDay(start, d);
      // UTC weekday of the local calendar date, not of KST midnight.
      const weekday = new Date(`${serviceDate}T12:00:00Z`).getUTCDay();
      const times = entry.timetable[weekday === 0 || weekday === 6 || timetable.holidays.includes(serviceDate) ? 'weekend' : 'weekday'];
      const departures = times.filter(t => (entry.via_times?.includes(t) ?? false) === (route.variantId === 'via')).map(minute).sort((a, b) => a - b);
      if (!departures.length) continue;
      const slots = new Set<number>([departures[0], departures.at(-1)!]);
      if (route.variantId === 'via') departures.forEach(v => slots.add(v));
      else for (let m = Math.ceil(departures[0] / route.intervalMinutes) * route.intervalMinutes; m < departures.at(-1)!; m += route.intervalMinutes) slots.add(m);
      for (const departureMinute of [...slots].sort((a, b) => a - b)) result.push({ route, serviceDate, departureMinute });
    }
  }
  return result;
}
