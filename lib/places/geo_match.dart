import 'dart:math';

/// Distância em km entre duas coordenadas (haversine).
/// Matching futuro: especialidade + este raio + disponibilidade, não só cidade.
double distanceKm({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  const earthKm = 6371.0;
  final dLat = _rad(toLat - fromLat);
  final dLng = _rad(toLng - fromLng);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(fromLat)) *
          cos(_rad(toLat)) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return earthKm * 2 * atan2(sqrt(a), sqrt(1 - a));
}

bool isWithinRadiusKm({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
  required num radiusKm,
}) {
  return distanceKm(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      ) <=
      radiusKm;
}

double _rad(double deg) => deg * pi / 180;
