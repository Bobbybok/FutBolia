/** Shared geo helpers — Haversine only, no paid maps APIs. */

export function parseCoord(raw: string | undefined): number | null {
  if (raw == null || raw === '') return null;
  const n = Number(raw);
  if (!Number.isFinite(n)) return null;
  return n;
}

export function assertLatLng(latitude: number, longitude: number): void {
  if (latitude < -90 || latitude > 90) {
    throw new Error('latitude out of range');
  }
  if (longitude < -180 || longitude > 180) {
    throw new Error('longitude out of range');
  }
}

/** Approximate distance in km (Haversine). */
export function distanceKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** SQL fragment: distance in km from (:lat, :lng) to table columns. */
export function haversineSql(
  latColumn: string,
  lngColumn: string,
): string {
  return `(
    6371 * acos(
      LEAST(1.0, GREATEST(-1.0,
        cos(radians(:lat)) * cos(radians(${latColumn}))
        * cos(radians(${lngColumn}) - radians(:lng))
        + sin(radians(:lat)) * sin(radians(${latColumn}))
      ))
    )
  )`;
}
