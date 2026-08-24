import '../models.dart';

const nearbyAirKm = 8.0;

List<Professional> onAirNearby(
  Iterable<Professional> all, {
  bool includeVerified = true,
}) {
  final active = all
      .where((p) => p.isActive && p.isProvider)
      .where((p) => includeVerified || !p.verified)
      .toList();
  final close = active
      .where((p) => p.hasMapPin && p.distanceKm != null && p.distanceKm! <= nearbyAirKm)
      .toList();
  final nearby = close.isNotEmpty ? close : active;
  if (!includeVerified) {
    return nearby..sort(_verifiedThenNear);
  }
  final byId = <String, Professional>{
    for (final pro in nearby) pro.id: pro,
    for (final pro in active.where((p) => p.verified)) pro.id: pro,
  };
  return byId.values.toList()..sort(_verifiedThenNear);
}

int _verifiedThenNear(Professional a, Professional b) {
  final verifiedCmp = (b.verified ? 1 : 0).compareTo(a.verified ? 1 : 0);
  if (verifiedCmp != 0) return verifiedCmp;
  return (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9);
}

List<Professional> featuredOnAir(Iterable<Professional> all) {
  return all
      .where((p) => p.isActive && p.isProvider && p.verified)
      .toList()
    ..sort((a, b) => (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));
}

const nearbyPageSize = 15;

int nearbyPageCount(int total, {int size = nearbyPageSize}) {
  if (total <= 0) return 0;
  return (total + size - 1) ~/ size;
}

List<Professional> nearbyPageOf(
  List<Professional> all,
  int page, {
  int size = nearbyPageSize,
}) {
  if (all.isEmpty) return const [];
  final last = nearbyPageCount(all.length, size: size) - 1;
  final safe = page.clamp(0, last < 0 ? 0 : last);
  final start = safe * size;
  if (start >= all.length) return const [];
  final end = (start + size).clamp(0, all.length);
  return all.sublist(start, end);
}
