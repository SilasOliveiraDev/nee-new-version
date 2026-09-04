import '../domain/availability.dart';
import '../domain/phone_mask.dart';
import '../domain/review_criteria.dart';
import '../mock_data.dart';
import '../models.dart';
import '../places/geo_match.dart';
import '../places/scz_zone_coords.dart';

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
    return '${categoriaId.toInt()}';
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

bool isProviderType(String? userType) {
  final value = (userType ?? '').trim().toLowerCase();
  return value == 'servicio' || value == 'provider' || value == 'profesional';
}

Professional professionalFromUserRow(
  Map<String, dynamic> row, {
  double? originLat,
  double? originLng,
}) {
  final name = (row['display_name'] as String?)?.trim() ??
      (row['display_name'] as String?)?.trim() ??
      (row['name'] as String?)?.trim() ??
      '';
  var coords = parseLatLng(row['latlng']);
  var pinApproximate = false;
  final rawCategoria = (row['Categoria'] as String?)?.trim();
  final viewCategory = (row['category_name'] as String?)?.trim();
  final tradeName = _asTradeLabel(viewCategory) ?? _asTradeLabel(rawCategoria);
  final categoryId = mapCategoryId(
    categoriaId: row['category_id'] ?? row['categoriaId'],
    categoria: tradeName,
    subcategoria: (row['specialty'] as String?) ?? (row['Subcategoria'] as String?),
  );
  var categoryName = tradeName;
  if (categoryName == null || categoryName.isEmpty) {
    for (final category in categories) {
      if (category.id == categoryId || category.id == '${row['category_id']}') {
        categoryName = category.name;
        break;
      }
    }
  }
  final specialtyRaw = (row['specialty'] as String?)?.trim().isNotEmpty == true
      ? row['specialty'] as String
      : ((row['Subcategoria'] as String?)?.trim().isNotEmpty == true
          ? row['Subcategoria'] as String
          : (categoryName ?? ''));
  final specialty = _asTradeLabel(specialtyRaw) ?? specialtyRaw;
  var zone = (row['zone'] as String?)?.trim() ??
      (row['Zona'] as String?)?.trim() ??
      '';
  if (zone.isEmpty && rawCategoria != null && looksLikeAreaLabel(rawCategoria)) {
    zone = rawCategoria;
  }
  final city = (row['city'] as String?)?.trim().isNotEmpty == true
      ? row['city'] as String
      : ((row['cidade'] as String?)?.trim() ?? '');
  final serviceArea = (row['service_area'] as String?)?.trim() ??
      (row['zona_atendimento'] as String?)?.trim() ??
      '';
  final cityLine = [
    if (city.isNotEmpty) city,
    if (zone.isNotEmpty) zone,
  ].join(' · ');
  final blocked = row['is_blocked'] == true ||
      row['isBloqueado'] == true ||
      row['isDeletado'] == true;
  final suspended = row['is_suspended'] == true || row['isSuspenso'] == true;
  final docs = '${row['document_status'] ?? row['statusDocumentos'] ?? ''}'
      .toUpperCase();
  final id = '${row['professional_id'] ?? row['professional_id'] ?? row['UUID'] ?? row['id'] ?? ''}';
  if (coords.lat == null || coords.lng == null) {
    final hint = [
      zone,
      city,
      serviceArea,
    ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    final pin = resolveZonePin(hint, id: id);
    coords = (lat: pin.latitude, lng: pin.longitude);
    pinApproximate = true;
  }
  double? distance;
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
  final reviewAvg = (row['reviews_average'] as num?)?.toDouble();
  final stored = (row['stored_rating'] as num?)?.toDouble() ??
      (row['rateAvaliacao'] as num?)?.toDouble() ??
      0;
  final ratingCount = (row['rating_count'] as num?)?.toInt() ?? 0;
  final rating = reviewAvg ?? (stored > 0 ? stored : 0);
  final jobs = (row['completed_jobs_count'] as num?)?.toInt() ??
      (row['jobs'] as num?)?.toInt() ??
      0;
  final bio = (row['bio'] as String?)?.trim() ??
      (row['descricaoSobre'] as String?)?.trim();
  final avatar = (row['avatar_url'] as String?)?.trim() ??
      (row['imagemPerfil'] as String?)?.trim();
  final phoneMasked = _phoneMaskedFrom(row);
  if (id.isEmpty) {
    assert(() {
      // ignore: avoid_print
      print('Ñee: missing professional id in user row');
      return true;
    }());
  }
  return Professional(
    id: id,
    name: name,
    specialty: specialty,
    categoryId: categoryId,
    categoryName: categoryName,
    city: cityLine,
    initials: initialsFrom(name),
    rating: rating,
    ratingCount: ratingCount,
    jobs: jobs,
    distanceKm: distance,
    available: !blocked && !suspended,
    isActive: !blocked && !suspended,
    isProvider: isProviderType(
          '${row['user_type'] ?? row['user_type'] ?? ''}',
        ) ||
        row['professional_id'] != null ||
        row['professional_id'] != null,
    documentsVerified: docs == 'VERIFIED' || docs == 'PRO',
    verified: row['verified'] == true,
    latitude: coords.lat,
    longitude: coords.lng,
    hasMapPin: coords.lat != null && coords.lng != null,
    pinApproximate: pinApproximate,
    isDestaque: row['is_featured'] == true || row['isDestacado'] == true,
    avatarUrl: (avatar ?? '').isEmpty ? null : avatar,
    bio: (bio ?? '').isEmpty ? null : bio,
    serviceArea: serviceArea.isEmpty ? null : serviceArea,
    phoneMasked: phoneMasked,
    acceptingRequests: !blocked && !suspended,
    opsStatus: blocked || suspended ? ProOpsStatus.paused : ProOpsStatus.offline,
    tags: [
      if (serviceArea.isNotEmpty) serviceArea,
    ],
    criteria: CriteriaAverages.fromRow(row),
  );
}

String? _asTradeLabel(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty || looksLikeAreaLabel(value)) return null;
  return value;
}

String? _phoneMaskedFrom(Map<String, dynamic> row) {
  final masked = (row['phone_masked'] as String?)?.trim();
  if (masked != null && masked.isNotEmpty) return masked;
  final raw = (row['phone'] as String?)?.trim() ?? '';
  if (raw.isEmpty) return null;
  return PhoneMask.display(raw);
}
