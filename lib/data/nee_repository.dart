import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_state.dart';
import '../domain/availability.dart';
import '../domain/cancellation.dart';
import '../mock_data.dart';
import '../models.dart';
import '../places/place_models.dart';
import 'nee_supabase.dart';
import 'professional_mapper.dart';
import 'users_row.dart';

class NeeRepository {
  static Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    if (!NeeSupabase.ready) return null;
    try {
      final result = await NeeSupabase.client.auth.signUp(
        email: email,
        password: password,
      );
      if (result.session == null) {
        await NeeSupabase.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return '$error';
    }
  }

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!NeeSupabase.ready) return null;
    try {
      await NeeSupabase.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return '$error';
    }
  }

  static Future<void> signOut() async {
    if (!NeeSupabase.ready) return;
    try {
      await NeeSupabase.client.auth.signOut();
    } catch (error) {
      debugPrint('Ñee: signOut: $error');
    }
  }

  static String? get sessionUserId =>
      NeeSupabase.ready ? NeeSupabase.client.auth.currentUser?.id : null;

  static Future<void> syncUser(NeeAppState state) async {
    if (!NeeSupabase.ready) return;
    final uuid = sessionUserId;
    if (uuid == null) return;
    try {
      state.user.supabaseUuid = uuid;
      final payload = UsersRow.toMap(
        user: state.user,
        step: state.step,
        activeRole: state.activeRole,
      );
      payload['UUID'] = uuid;
      final existing = await NeeSupabase.client
          .from('users')
          .select('id')
          .eq('UUID', uuid)
          .maybeSingle();
      Map<String, dynamic>? row;
      if (existing != null) {
        row = await NeeSupabase.client
            .from('users')
            .update(payload)
            .eq('UUID', uuid)
            .select('id')
            .maybeSingle();
      } else {
        row = await NeeSupabase.client
            .from('users')
            .insert(payload)
            .select('id')
            .maybeSingle();
      }
      final id = row?['id'];
      if (id is int) state.user.supabaseRowId = id;
      if (id is num) state.user.supabaseRowId = id.toInt();
    } catch (error) {
      debugPrint('Ñee: falha ao gravar users: $error');
    }
  }

  static Future<Map<String, dynamic>?> fetchOwnUser() async {
    if (!NeeSupabase.ready) return null;
    final uuid = sessionUserId;
    if (uuid == null) return null;
    try {
      return await NeeSupabase.client
          .from('users')
          .select()
          .eq('UUID', uuid)
          .maybeSingle();
    } catch (error) {
      debugPrint('Ñee: falha ao ler users: $error');
      return null;
    }
  }

  static Future<void> insertRequest(
    NeeAppState state,
    ServiceRequest request,
  ) async {
    if (!NeeSupabase.ready) return;
    final uuid = sessionUserId;
    if (uuid == null) return;
    final snap = request.serviceLocation;
    final base = <String, dynamic>{
      'client_id': uuid,
      'title': request.specialty.isEmpty
          ? request.category.name
          : request.specialty,
      'description': request.description,
      'status': request.isDirect ? request.stageLabel : request.status.label,
      'categoria': request.category.name,
      'qtdPropostas': request.interestedCount,
      'disponivel': !request.isDirect,
      'address': snap?.locationLabel ?? request.location,
      'city': (snap != null && snap.city.isNotEmpty)
          ? snap.city
          : state.user.cityLabel,
      'state': snap?.state,
      'country': (snap != null && snap.country.isNotEmpty)
          ? snap.country
          : 'Bolivia',
      'coordenadas': snap != null && snap.hasCoords
          ? '${snap.latitude},${snap.longitude}'
          : null,
      'location_id': snap?.placeId,
    };
    final extra = <String, dynamic>{
      'service_address_id': snap?.placeId,
      'service_address_label': snap?.label,
      'service_formatted_address': snap?.formattedAddress,
      'service_street': snap?.street,
      'service_number': snap?.number,
      'service_neighborhood': snap?.neighborhood,
      'service_city': snap?.city,
      'service_state': snap?.state,
      'service_country': snap?.country,
      'service_postal_code': snap?.postalCode,
      'service_latitude': snap?.latitude,
      'service_longitude': snap?.longitude,
      'service_apartment': snap?.apartment,
      'service_floor': snap?.floor,
      'service_reference': snap?.reference,
      'request_kind': request.isDirect ? 'DIRECT' : 'MARKETPLACE',
      'target_professional_id': request.targetProfessionalId,
      'direct_status': request.directStatus == null
          ? null
          : apiDirectStatus(request.directStatus!),
      'requested_start': request.requestedStart?.toUtc().toIso8601String(),
      'requested_end': request.requestedEnd?.toUtc().toIso8601String(),
      'profissional_id': request.targetProfessionalId,
    };
    try {
      final row = await NeeSupabase.client
          .from('service_requests')
          .insert({...base, ...extra})
          .select('id')
          .maybeSingle();
      final id = row?['id'];
      if (id is num) request.remoteId = id.toInt();
    } catch (error) {
      debugPrint('Ñee: snapshot extra falhou, tentando colunas base: $error');
      try {
        final row = await NeeSupabase.client
            .from('service_requests')
            .insert(base)
            .select('id')
            .maybeSingle();
        final id = row?['id'];
        if (id is num) request.remoteId = id.toInt();
      } catch (fallback) {
        debugPrint('Ñee: falha ao gravar service_requests: $fallback');
      }
    }
  }

  static Future<void> recordCancellation(
    NeeAppState state, {
    required ServiceRequest request,
    required CancelReason reason,
    required bool countsTowardRapidCancel,
    String reasonText = '',
    RequestStatus? statusAtCancel,
  }) async {
    if (!NeeSupabase.ready) return;
    final uuid = sessionUserId;
    if (uuid == null) return;
    try {
      await NeeSupabase.client.from('service_cancellations').insert({
        'request_id': request.id,
        'customer_id': uuid,
        'professional_id': request.professional?.id,
        'cancelled_by': 'CUSTOMER',
        'request_status_at_cancel': (statusAtCancel ?? request.status).name,
        'reason_code': apiReasonCode(reason),
        'reason_text': reasonText.isEmpty ? null : reasonText,
        'counts_toward_rapid_cancel': countsTowardRapidCancel,
      });
    } catch (error) {
      debugPrint('Ñee: falha ao gravar cancelamento: $error');
    }
  }

  static Future<void> refreshCancellationContext(NeeAppState state) async {
    if (!NeeSupabase.ready) return;
    final uuid = sessionUserId;
    try {
      final policy = await NeeSupabase.client
          .from('cancellation_policy')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (policy != null) {
        state.cancellationPolicy = CancellationPolicy.fromJson(policy);
      }
    } catch (error) {
      debugPrint('Ñee: falha ao ler cancellation_policy: $error');
    }
    if (uuid == null) return;
    try {
      final row = await NeeSupabase.client
          .from('user_restrictions')
          .select()
          .eq('user_id', uuid)
          .eq('active', true)
          .eq('restriction_type', 'CREATE_SERVICE_TEMPORARILY_BLOCKED')
          .order('expires_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        final expires = DateTime.tryParse('${row['expires_at']}');
        if (expires != null && expires.isAfter(DateTime.now())) {
          state.createBlock = UserRestriction(expiresAt: expires);
        } else {
          state.createBlock = null;
        }
      }
    } catch (error) {
      debugPrint('Ñee: falha ao ler user_restrictions: $error');
    }
  }

  static Future<void> loadFeaturedProfessionals(NeeAppState state) async {
    if (!NeeSupabase.ready) {
      state.directory = const [];
      return;
    }
    try {
      final rows = await NeeSupabase.client
          .from('users')
          .select(
            'id, name, UUID, Categoria, categoriaId, Subcategoria, Zona, cidade, city, latlng, rateAvaliacao, statusDocumentos, isDestacado, isSuspenso, isBloqueado, isDeletado, zona_atendimento',
          )
          .eq('isDestacado', true);
      final origin = state.user.currentLocation.hasCoords
          ? state.user.currentLocation
          : state.user.registeredAddress;
      state.directory =
          [
              for (final row in rows)
                professionalFromUserRow(
                  Map<String, dynamic>.from(row),
                  originLat: origin.latitude,
                  originLng: origin.longitude,
                ),
            ].where((p) => p.isDestaque).toList()
            ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } catch (error) {
      debugPrint('Ñee: falha ao ler profissionais destacados: $error');
      state.directory = const [];
    }
  }

  static bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  static Map<String, dynamic> _addressPayload(UserPlace place, String userId) {
    return {
      if (_isUuid(place.id)) 'id': place.id,
      'user_id': userId,
      'type': place.type.name,
      'custom_label': place.customLabel.isEmpty ? null : place.customLabel,
      'formatted_address': place.formattedAddress,
      'street': place.street,
      'street_number': place.streetNumber,
      'neighborhood': place.neighborhood,
      'city': place.city,
      'state': place.state,
      'country': place.country,
      'country_code': place.countryCode,
      'postal_code': place.postalCode.isEmpty ? null : place.postalCode,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'apartment': place.apartment.isEmpty ? null : place.apartment,
      'floor': place.floor.isEmpty ? null : place.floor,
      'reference': place.reference.isEmpty ? null : place.reference,
      'place_id': place.placeId.isEmpty ? null : place.placeId,
      'geocoding_provider': place.geocodingProvider,
      'location_accuracy': place.locationAccuracy,
      'is_default': place.isDefault,
      'is_location_confirmed': place.isLocationConfirmed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static UserPlace _placeFromRow(Map<String, dynamic> row) {
    return UserPlace(
      id: '${row['id']}',
      type: PlaceType.values.firstWhere(
        (e) => e.name == row['type'],
        orElse: () => PlaceType.other,
      ),
      customLabel: row['custom_label'] as String? ?? '',
      formattedAddress: row['formatted_address'] as String? ?? '',
      street: row['street'] as String? ?? '',
      streetNumber: row['street_number'] as String? ?? '',
      neighborhood: row['neighborhood'] as String? ?? '',
      city: row['city'] as String? ?? '',
      state: row['state'] as String? ?? '',
      country: row['country'] as String? ?? 'Bolivia',
      countryCode: row['country_code'] as String? ?? 'BO',
      postalCode: row['postal_code'] as String? ?? '',
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      apartment: row['apartment'] as String? ?? '',
      floor: row['floor'] as String? ?? '',
      reference: row['reference'] as String? ?? '',
      placeId: row['place_id'] as String? ?? '',
      geocodingProvider: row['geocoding_provider'] as String? ?? 'nominatim',
      locationAccuracy: (row['location_accuracy'] as num?)?.toDouble(),
      isDefault: row['is_default'] as bool? ?? false,
      isLocationConfirmed: row['is_location_confirmed'] as bool? ?? false,
    );
  }

  static Future<void> loadAddresses(NeeAppState state) async {
    if (!NeeSupabase.ready) return;
    final uuid = sessionUserId;
    if (uuid == null) return;
    try {
      final rows = await NeeSupabase.client
          .from('user_addresses')
          .select()
          .eq('user_id', uuid)
          .order('is_default', ascending: false);
      final loaded = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(_placeFromRow)
          .toList();
      if (loaded.isNotEmpty) {
        state.places
          ..clear()
          ..addAll(loaded);
        return;
      }
      for (final place in List<UserPlace>.from(state.places)) {
        await upsertAddress(state, place);
      }
    } catch (error) {
      debugPrint('Ñee: falha ao ler user_addresses: $error');
    }
  }

  static Future<void> upsertAddress(NeeAppState state, UserPlace place) async {
    if (!NeeSupabase.ready) return;
    final uuid = sessionUserId;
    if (uuid == null) return;
    try {
      if (place.isDefault) {
        await NeeSupabase.client
            .from('user_addresses')
            .update({'is_default': false})
            .eq('user_id', uuid);
      }
      final payload = _addressPayload(place, uuid);
      Map<String, dynamic>? row;
      if (_isUuid(place.id)) {
        row = await NeeSupabase.client
            .from('user_addresses')
            .upsert(payload)
            .select()
            .maybeSingle();
      } else {
        payload.remove('id');
        row = await NeeSupabase.client
            .from('user_addresses')
            .insert(payload)
            .select()
            .maybeSingle();
      }
      final id = row?['id'];
      if (id != null) place.id = '$id';
    } catch (error) {
      debugPrint('Ñee: falha ao gravar user_addresses: $error');
    }
  }

  static Future<void> deleteAddress(NeeAppState state, UserPlace place) async {
    if (!NeeSupabase.ready) return;
    final uuid = sessionUserId;
    if (uuid == null) return;
    try {
      await NeeSupabase.client
          .from('user_addresses')
          .delete()
          .eq('id', place.id)
          .eq('user_id', uuid);
    } catch (error) {
      debugPrint('Ñee: falha ao excluir endereço: $error');
    }
  }

  static Future<void> upsertRegisteredAddress(NeeAppState state) async {
    final source = state.user.registeredAddress;
    if (!source.isFilled && !source.hasCoords) return;
    UserPlace? home;
    for (final place in state.places) {
      if (place.type == PlaceType.home || place.isDefault) {
        home = place;
        break;
      }
    }
    home ??= UserPlace(id: 'home', type: PlaceType.home, isDefault: true);
    home
      ..type = PlaceType.home
      ..street = source.street
      ..streetNumber = source.number
      ..neighborhood = source.zone
      ..city = source.city
      ..state = source.department
      ..country = source.country.isEmpty ? 'Bolivia' : source.country
      ..latitude = source.latitude
      ..longitude = source.longitude
      ..reference = source.reference
      ..formattedAddress = source.summary
      ..isDefault = true
      ..isLocationConfirmed = source.hasCoords;
    if (!state.places.contains(home)) {
      for (final item in state.places) {
        item.isDefault = false;
      }
      state.places.add(home);
    }
    await upsertAddress(state, home);
  }

  static Future<void> loadClientRequests(NeeAppState state) async {
    if (!NeeSupabase.ready) return;
    final uuid = sessionUserId;
    if (uuid == null) return;
    try {
      final requestRows = await NeeSupabase.client
          .from('service_requests')
          .select()
          .eq('client_id', uuid)
          .order('created_at', ascending: false);
      final proposalRows = await NeeSupabase.client
          .from('proposals')
          .select()
          .eq('idCliente', uuid)
          .order('created_at');
      final offersByRequest = <String, List<Map<String, dynamic>>>{};
      for (final row in proposalRows) {
        final map = Map<String, dynamic>.from(row);
        final key = '${map['service_request_id'] ?? ''}';
        offersByRequest.putIfAbsent(key, () => []).add(map);
      }
      final professionalIds = {
        for (final row in proposalRows)
          '${Map<String, dynamic>.from(row)['professional_id'] ?? ''}',
      }..removeWhere((id) => id.isEmpty);
      await _ensureProfessionals(state, professionalIds);
      final origin = state.user.currentLocation.hasCoords
          ? state.user.currentLocation
          : state.user.registeredAddress;
      final loaded = <ServiceRequest>[];
      for (final raw in requestRows) {
        final row = Map<String, dynamic>.from(raw);
        final remoteId = (row['id'] as num?)?.toInt();
        if (remoteId == null) continue;
        final key = '$remoteId';
        final offerRows = offersByRequest[key] ?? const [];
        final request = requestFromRow(row, hasOffers: offerRows.isNotEmpty);
        request.interestedCount = offerRows.length;
        for (final offer in offerRows) {
          final proId = '${offer['professional_id'] ?? ''}';
          var professional = _findProfessional(state, proId);
          professional ??= professionalFromUserRow(
            {
              'UUID': proId,
              'name': 'Profesional',
              'isDestacado': true,
            },
            originLat: origin.latitude,
            originLng: origin.longitude,
          );
          final time = '${offer['time_estimate'] ?? ''}'.trim();
          request.offers.add(
            ServiceOffer(
              id: '${offer['id']}',
              professional: professional,
              message: '${offer['proposal_message'] ?? ''}'.trim(),
              priceBs: (offer['price_estimate'] as num?)?.toDouble(),
              availability: time.isEmpty ? 'Propuesta enviada' : time,
              timeEstimate: time,
            ),
          );
        }
        loaded.add(request);
      }
      if (loaded.isEmpty) return;
      state.requests.removeWhere(
        (r) => r.id.startsWith('demo') || r.remoteId != null,
      );
      state.requests.insertAll(0, loaded);
    } catch (error) {
      debugPrint('Ñee: falha ao ler solicitudes/propostas: $error');
    }
  }

  static Future<void> _ensureProfessionals(
    NeeAppState state,
    Set<String> ids,
  ) async {
    final missing = ids.where((id) => _findProfessional(state, id) == null).toList();
    if (missing.isEmpty) return;
    try {
      final rows = await NeeSupabase.client
          .from('users')
          .select(
            'id, name, UUID, Categoria, categoriaId, Subcategoria, Zona, cidade, city, latlng, rateAvaliacao, statusDocumentos, isDestacado, isSuspenso, isBloqueado, isDeletado, zona_atendimento',
          )
          .inFilter('UUID', missing);
      final origin = state.user.currentLocation.hasCoords
          ? state.user.currentLocation
          : state.user.registeredAddress;
      final extra = [
        for (final row in rows)
          professionalFromUserRow(
            Map<String, dynamic>.from(row),
            originLat: origin.latitude,
            originLng: origin.longitude,
          ),
      ];
      state.directory = [...state.directory, ...extra];
    } catch (error) {
      debugPrint('Ñee: falha ao ler profissionais das propostas: $error');
    }
  }

  static Professional? _findProfessional(NeeAppState state, String id) {
    for (final professional in state.directory) {
      if (professional.id == id) return professional;
    }
    return null;
  }

  static ServiceRequest requestFromRow(
    Map<String, dynamic> row, {
    bool hasOffers = false,
  }) {
    final remoteId = (row['id'] as num?)?.toInt();
    final category = _categoryFrom(
      row['categoria'] as String? ?? row['title'] as String?,
    );
    final created =
        DateTime.tryParse('${row['created_at'] ?? ''}') ?? DateTime.now();
    final kind = '${row['request_kind'] ?? ''}'.toUpperCase() == 'DIRECT'
        ? RequestKind.direct
        : RequestKind.marketplace;
    return ServiceRequest(
      id: remoteId == null ? '${row['id']}' : 'sr$remoteId',
      category: category,
      description: (row['description'] as String?)?.trim().isNotEmpty == true
          ? row['description'] as String
          : (row['title'] as String? ?? category.name),
      location: row['address'] as String? ??
          row['service_formatted_address'] as String? ??
          row['city'] as String? ??
          '',
      createdAt: created,
      status: _statusFrom(row['status'] as String?, hasOffers: hasOffers),
      specialty: row['title'] as String? ?? '',
      remoteId: remoteId,
      kind: kind,
      directStatus: directStatusFromApi(row['direct_status'] as String?),
      targetProfessionalId: row['target_professional_id'] as String?,
      requestedStart: DateTime.tryParse('${row['requested_start'] ?? ''}'),
      requestedEnd: DateTime.tryParse('${row['requested_end'] ?? ''}'),
      agreedPrice: (row['agreed_price'] as num?)?.toDouble(),
      agreedDurationMinutes: (row['agreed_duration_minutes'] as num?)?.toInt(),
      declineReason: row['decline_reason'] as String?,
    );
  }

  static ServiceCategory _categoryFrom(String? raw) {
    final id = mapCategoryId(categoria: raw);
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return categories.first;
  }

  static RequestStatus _statusFrom(String? raw, {required bool hasOffers}) {
    final text = (raw ?? '').toLowerCase();
    if (text.contains('final') || text.contains('complet')) {
      return RequestStatus.completed;
    }
    if (text.contains('expir')) return RequestStatus.cancelledByProfessional;
    if (text.contains('cancelado por el profesional')) {
      return RequestStatus.cancelledByProfessional;
    }
    if (text.contains('cancel')) return RequestStatus.cancelledByCustomer;
    if (text.contains('camino')) return RequestStatus.onTheWay;
    if (text.contains('curso') || text.contains('progreso')) {
      return RequestStatus.inProgress;
    }
    if (text.contains('seleccion')) return RequestStatus.accepted;
    if (text.contains('convers') || text.contains('pendiente de confirm')) {
      return RequestStatus.professionalFound;
    }
    if (hasOffers) return RequestStatus.professionalFound;
    return RequestStatus.sent;
  }
}
