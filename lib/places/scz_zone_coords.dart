import 'dart:math';

/// Centroides aproximados de Santa Cruz de la Sierra.
/// Não é GPS do profissional: é a zona do perfil com um deslocamento estável.
class ZonePin {
  const ZonePin({
    required this.latitude,
    required this.longitude,
    this.approximate = true,
  });

  final double latitude;
  final double longitude;
  final bool approximate;
}

const sczPlazaLat = -17.7833;
const sczPlazaLng = -63.1821;

ZonePin resolveZonePin(String? zone, {String id = ''}) {
  final centroid = _centroidFor(zone);
  final offset = _jitterMeters(id);
  return ZonePin(
    latitude: centroid.$1 + _metersToLat(offset.$1),
    longitude: centroid.$2 + _metersToLng(offset.$2, centroid.$1),
  );
}

(double, double) _centroidFor(String? zone) {
  final key = _normalize(zone);
  if (key.isEmpty) return (sczPlazaLat, sczPlazaLng);

  final anillo = _anilloNumber(key);
  if (anillo != null) {
    return _anilloPoint(anillo);
  }

  final distrito = _distritoNumber(key);
  if (distrito != null) {
    return _distritoPoint(distrito);
  }

  for (final entry in _namedZones.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return (sczPlazaLat, sczPlazaLng);
}

(double, double) _anilloPoint(int n) {
  final clamped = n.clamp(1, 10);
  final km = 0.7 * clamped;
  return _offsetKm(sczPlazaLat, sczPlazaLng, km, 45);
}

(double, double) _distritoPoint(int n) {
  const points = <int, (double, double)>{
    1: (sczPlazaLat, sczPlazaLng),
    3: (-17.755, -63.175),
    4: (-17.760, -63.145),
    6: (-17.780, -63.135),
    8: (-17.815, -63.185),
    9: (-17.805, -63.210),
    10: (-17.775, -63.215),
    11: (-17.755, -63.205),
    12: (-17.770, -63.115),
    13: (-17.830, -63.170),
    14: (-17.745, -63.230),
  };
  return points[n] ?? _offsetKm(sczPlazaLat, sczPlazaLng, 3.5, n * 24.0);
}

int? _anilloNumber(String key) {
  final match = RegExp(r'(\d+)\s*anillo').firstMatch(key);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

int? _distritoNumber(String key) {
  final match = RegExp(r'distrito(?:\s+municipal)?\s+(\d+)').firstMatch(key);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// Deslocamento em metros (norte, leste), 300–700 m, estável por id.
(double, double) _jitterMeters(String id) {
  final hash = id.hashCode;
  final angle = ((hash % 360) * pi) / 180;
  final radius = 300.0 + (hash.abs() % 401);
  return (cos(angle) * radius, sin(angle) * radius);
}

(double, double) _offsetKm(double lat, double lng, double km, double bearingDeg) {
  final bearing = bearingDeg * pi / 180;
  return (
    lat + _metersToLat(km * 1000 * cos(bearing)),
    lng + _metersToLng(km * 1000 * sin(bearing), lat),
  );
}

double _metersToLat(double meters) => meters / 111320;

double _metersToLng(double meters, double lat) =>
    meters / (111320 * cos(lat * pi / 180));

String _normalize(String? raw) {
  var value = (raw ?? '').trim().toLowerCase();
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  for (var i = 0; i < from.length; i++) {
    value = value.replaceAll(from[i], to[i]);
  }
  return value.replaceAll(RegExp(r'\s+'), ' ');
}

const _namedZones = <String, (double, double)>{
  'urubo': (-17.750, -63.225),
  'plan 3000': (-17.775, -63.125),
  'el trompillo': (-17.812, -63.171),
  'pampa de la isla': (-17.765, -63.105),
  'zona sur': (-17.810, -63.185),
  'san antonio': (-17.795, -63.165),
  'nuevo mundo': (-17.770, -63.145),
  'estacion argentina': (-17.798, -63.155),
  'equipetrol': (-17.766, -63.195),
};
