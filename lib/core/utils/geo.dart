import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Distance à vol d'oiseau entre deux points (formule de haversine), en km.
double haversineKm(LatLng a, LatLng b) {
  const earthRadiusKm = 6371.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final sinLat = math.sin(dLat / 2);
  final sinLon = math.sin(dLon / 2);
  final h = sinLat * sinLat +
      math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * sinLon * sinLon;
  return 2 * earthRadiusKm * math.asin(math.sqrt(h));
}

double _rad(double deg) => deg * math.pi / 180.0;

/// Point situé à la fraction `t` (0 → a, 1 → b) du segment [a, b].
/// Utilisé par la simulation pour faire « rouler » le chauffeur.
LatLng interpolate(LatLng a, LatLng b, double t) {
  final double k = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
  return LatLng(
    a.latitude + (b.latitude - a.latitude) * k,
    a.longitude + (b.longitude - a.longitude) * k,
  );
}
