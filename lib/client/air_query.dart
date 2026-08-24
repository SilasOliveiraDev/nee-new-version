import '../models.dart';

const nearbyAirKm = 8.0;

List<Professional> onAirNearby(Iterable<Professional> all) {
  final list = all.where((p) => p.isDestaque).toList()
    ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  final close = list
      .where((p) => p.hasMapPin && p.distanceKm <= nearbyAirKm)
      .toList();
  return close.isNotEmpty ? close : list;
}

List<Professional> featuredOnAir(Iterable<Professional> all) {
  return all.where((p) => p.isDestaque).take(8).toList();
}
