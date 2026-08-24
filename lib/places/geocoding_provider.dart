import 'dart:convert';

import 'package:http/http.dart' as http;

import 'place_models.dart';

abstract class GeocodingProvider {
  String get id;
  Future<List<PlaceSuggestion>> search(String query);
  Future<UserPlace> reverse(double latitude, double longitude);
}

class NominatimGeocoding implements GeocodingProvider {
  NominatimGeocoding({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'nominatim';

  static const _headers = {
    'User-Agent': 'NeeApp/1.0 (servicios locales)',
    'Accept-Language': 'es',
  };

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '6',
    });
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('No se pudo buscar la dirección.');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return [
      for (final item in list)
        if (item is Map<String, dynamic>) _fromNominatim(item),
    ];
  }

  @override
  Future<UserPlace> reverse(double latitude, double longitude) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '$latitude',
      'lon': '$longitude',
      'format': 'jsonv2',
      'addressdetails': '1',
    });
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      return UserPlace(
        id: 'tmp',
        latitude: latitude,
        longitude: longitude,
        formattedAddress: '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
        geocodingProvider: id,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestion = _fromNominatim(json, latitude: latitude, longitude: longitude);
    return UserPlace(
      id: 'tmp',
      formattedAddress: suggestion.title,
      street: suggestion.street,
      streetNumber: suggestion.number,
      neighborhood: suggestion.neighborhood,
      city: suggestion.city,
      state: suggestion.state,
      country: suggestion.country,
      postalCode: suggestion.postalCode,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      placeId: suggestion.placeId,
      geocodingProvider: id,
    );
  }

  PlaceSuggestion _fromNominatim(
    Map<String, dynamic> json, {
    double? latitude,
    double? longitude,
  }) {
    final address = (json['address'] as Map?)?.cast<String, dynamic>() ?? {};
    final lat = latitude ?? double.tryParse('${json['lat']}') ?? 0;
    final lng = longitude ?? double.tryParse('${json['lon']}') ?? 0;
    final street = '${address['road'] ?? address['pedestrian'] ?? ''}'.trim();
    final number = '${address['house_number'] ?? ''}'.trim();
    final neighborhood =
        '${address['suburb'] ?? address['neighbourhood'] ?? address['quarter'] ?? ''}'
            .trim();
    final city =
        '${address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'] ?? ''}'
            .trim();
    final state = '${address['state'] ?? address['region'] ?? ''}'.trim();
    final country = '${address['country'] ?? 'Bolivia'}'.trim();
    final display = '${json['display_name'] ?? ''}'.trim();
    return PlaceSuggestion(
      title: display.split(',').first,
      subtitle: display,
      latitude: lat,
      longitude: lng,
      placeId: '${json['place_id'] ?? ''}',
      street: street,
      number: number,
      neighborhood: neighborhood,
      city: city,
      state: state,
      country: country,
      postalCode: '${address['postcode'] ?? ''}'.trim(),
    );
  }
}
