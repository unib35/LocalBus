import { ProviderError } from './collect.ts';
import type { Provider } from './collect.ts';
import type { RouteConfig } from './schedule.ts';

// Coordinates are [longitude, latitude], including the reviewed road corridor.
function distanceToSegment(p: number[], a: number[], b: number[]): number {
  const scale = Math.cos(p[1] * Math.PI / 180);
  const x = (p[0] - a[0]) * scale, y = p[1] - a[1];
  const dx = (b[0] - a[0]) * scale, dy = b[1] - a[1];
  const t = Math.max(0, Math.min(1, (x * dx + y * dy) / (dx * dx + dy * dy || 1)));
  return Math.hypot(x - t * dx, y - t * dy) * 111320;
}
export function validateRouteConfig(route: RouteConfig) {
  const coordinate = (p: number[]) => Array.isArray(p) && p.length === 2
    && Number.isFinite(p[0]) && Math.abs(p[0]) <= 180 && Number.isFinite(p[1]) && Math.abs(p[1]) <= 90;
  if (!route.verified || !route.routeVersion || !route.correctionVersion
      || route.waypoints.length < 2 || route.waypoints.length > 7
      || !route.waypoints.every(coordinate) || route.corridor.length < 2 || !route.corridor.every(coordinate)
      || !(route.minDistanceMeters > 0 && route.maxDistanceMeters > route.minDistanceMeters)
      || !(route.corridorToleranceMeters > 0 && route.corridorToleranceMeters <= 500)) throw Error('Route review required');
}
export function kakaoProvider(apiKey: string, request: typeof fetch = fetch): Provider {
  return async slot => {
    validateRouteConfig(slot.route);
    const points = slot.route.waypoints.map(p => p.join(','));
    const url = new URL('https://apis-navi.kakaomobility.com/v1/future/directions');
    const hour = Math.floor(slot.departureMinute / 60).toString().padStart(2, '0');
    const minute = (slot.departureMinute % 60).toString().padStart(2, '0');
    url.search = new URLSearchParams({ origin: points[0], destination: points.at(-1)!,
      departure_time: slot.serviceDate.replaceAll('-', '') + hour + minute,
      priority: 'RECOMMEND', summary: 'false', alternatives: 'false' }).toString();
    if (points.length > 2) url.searchParams.set('waypoints', points.slice(1, -1).join('|'));
    let response: Response;
    try { response = await request(url, { headers: { Authorization: `KakaoAK ${apiKey}` }, signal: AbortSignal.timeout(15000) }); }
    catch { throw new ProviderError(503); }
    if (!response.ok) throw new ProviderError(response.status);
    let body: any;
    try { body = await response.json(); } catch { throw new ProviderError(422); }
    const route = body?.routes?.[0];
    const distance = route?.summary?.distance;
    if (route?.result_code !== 0 || !Number.isFinite(distance)
        || distance < slot.route.minDistanceMeters || distance > slot.route.maxDistanceMeters
        || !Array.isArray(route.sections) || route.sections.length === 0) throw new ProviderError(422);
    const vertices: number[][] = [];
    for (const section of route.sections) {
      if (!Array.isArray(section.roads) || !section.roads.length) throw new ProviderError(422);
      for (const road of section.roads) {
        const values = road.vertexes;
        if (!Array.isArray(values) || values.length < 2 || values.length % 2 !== 0 || !values.every(Number.isFinite)) throw new ProviderError(422);
        for (let i = 0; i < values.length; i += 2) vertices.push([values[i], values[i + 1]]);
      }
    }
    const corridor = slot.route.corridor;
    if (vertices.some(p => !corridor.slice(1).some((b, i) => distanceToSegment(p, corridor[i], b) <= slot.route.corridorToleranceMeters))) throw new ProviderError(422);
    return { durationSeconds: route.summary.duration, source: 'kakao-future' };
  };
}
