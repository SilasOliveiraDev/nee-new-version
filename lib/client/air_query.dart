import '../models.dart';

const nearbyAirKm = 8.0;

List<Professional> onAirNearby(
  Iterable<Professional> all, {
  bool includeVerified = false,
}) {
  final active = all
      .where((p) => p.isActive && p.isProvider)
      .where((p) => includeVerified || !p.verified)
      .toList()
    ..sort((a, b) => (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));
  final close = active
      .where((p) => p.hasMapPin && p.distanceKm != null && p.distanceKm! <= nearbyAirKm)
      .toList();
  return close.isNotEmpty ? close : active;
}

List<Professional> featuredOnAir(Iterable<Professional> all) {
  return all
      .where((p) => p.isActive && p.isProvider && p.verified)
      .toList()
    ..sort((a, b) => (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));
}
