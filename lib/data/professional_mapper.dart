import '../mock_data.dart';
import '../models.dart';
import '../places/geo_match.dart';

const _categoryByDbId = <int, String>{
  2: 'reparaciones',
  3: 'limpieza',
  5: 'belleza',
  7: 'tech',
  8: 'jardineria',
  10: 'construccion',
  13: 'plomeria',
  14: 'electricidad',
};

({double? lat, double? lng}) parseLatLng(dynamic raw) {
  if (raw == null) return (lat: null, lng: null);
  final text = '$raw'.trim();
  if (text.isEmpty) return (lat: null, lng: null);
  final parts = text.split(RegExp(r'\s*,\s*'));
  if (parts.length < 2) return (lat: null, lng: null);
  final lat = double.tryParse(parts[0]);
  final lng = double.tryParse(parts[1]);
  if (lat == null || lng == null) return (lat: null, lng: null);
  return (lat: lat, lng: lng);
}

String mapCategoryId({
  dynamic categoriaId,
  String? categoria,
  String? subcategoria,
}) {
  if (categoriaId is num) {
    final mapped = _categoryByDbId[categoriaId.toInt()];
    if (mapped != null) return mapped;
  }
  final blob = '${categoria ?? ''} ${subcategoria ?? ''}'.toLowerCase();
  for (final category in categories) {
    if (blob.contains(category.name.toLowerCase()) || blob.contains(category.id)) {
      return category.id;
    }
  }
  if (blob.contains('tecnolog')) return 'tech';
  if (blob.contains('repar')) return 'reparaciones';
  return '';
}

String initialsFrom(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'Ñ';
  if (parts.length == 1) {
    final word = parts.first;
    return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

Professional professionalFromUserRow(
  Map<String, dynamic> row, {
  double? originLat,
  double? originLng,
}) {
  final name = (row['name'] as String?)?.trim();
  final displayName = (name == null || name.isEmpty) ? 'Profesional Ñee' : name;
  final coords = parseLatLng(row['latlng']);
  final categoryId = mapCategoryId(
    categoriaId: row['categoriaId'],
    categoria: row['Categoria'] as String?,
    subcategoria: row['Subcategoria'] as String?,
  );
  final specialty = (row['Subcategoria'] as String?)?.trim().isNotEmpty == true
      ? row['Subcategoria'] as String
      : ((row['Categoria'] as String?)?.trim().isNotEmpty == true
          ? row['Categoria'] as String
          : 'Servicio');
  final zone = (row['Zona'] as String?)?.trim() ?? '';
  final city = (row['cidade'] as String?)?.trim().isNotEmpty == true
      ? row['cidade'] as String
      : ((row['city'] as String?) ?? '');
  final cityLine = [
    if (city.isNotEmpty) city,
    if (zone.isNotEmpty) zone,
  ].join(' · ');
  final blocked = row['isBloqueado'] == true || row['isDeletado'] == true;
  final suspended = row['isSuspenso'] == true;
  final docs = '${row['statusDocumentos'] ?? ''}'.toUpperCase();
  var distance = 99.0;
  if (originLat != null &&
      originLng != null &&
      coords.lat != null &&
      coords.lng != null) {
    distance = distanceKm(
      fromLat: originLat,
      fromLng: originLng,
      toLat: coords.lat!,
      toLng: coords.lng!,
    );
  }
  return Professional(
    id: '${row['UUID'] ?? row['id']}',
    name: displayName,
    specialty: specialty,
    categoryId: categoryId,
    city: cityLine.isEmpty ? 'Bolivia' : cityLine,
    initials: initialsFrom(displayName),
    rating: (row['rateAvaliacao'] as num?)?.toDouble() ?? 0,
    jobs: 0,
    distanceKm: distance,
    available: !blocked && !suspended,
    isActive: !blocked,
    documentsVerified: docs == 'VERIFIED' || docs == 'PRO',
    latitude: coords.lat ?? -17.7833,
    longitude: coords.lng ?? -63.1821,
    hasMapPin: coords.lat != null && coords.lng != null,
    isDestaque: row['isDestacado'] == true,
    tags: [
      if (zone.isNotEmpty) zone,
      if ((row['zona_atendimento'] as String?)?.trim().isNotEmpty == true)
        row['zona_atendimento'] as String,
    ],
  );
}
