enum PlaceType { home, work, other }

class UserPlace {
  UserPlace({
    required this.id,
    this.type = PlaceType.home,
    this.customLabel = '',
    this.formattedAddress = '',
    this.street = '',
    this.streetNumber = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.country = 'Bolivia',
    this.countryCode = 'BO',
    this.postalCode = '',
    this.latitude,
    this.longitude,
    this.apartment = '',
    this.floor = '',
    this.reference = '',
    this.placeId = '',
    this.geocodingProvider = 'nominatim',
    this.locationAccuracy,
    this.isDefault = false,
    this.isLocationConfirmed = false,
  });

  String id;
  PlaceType type;
  String customLabel;
  String formattedAddress;
  String street;
  String streetNumber;
  String neighborhood;
  String city;
  String state;
  String country;
  String countryCode;
  String postalCode;
  double? latitude;
  double? longitude;
  String apartment;
  String floor;
  String reference;
  String placeId;
  String geocodingProvider;
  double? locationAccuracy;
  bool isDefault;
  bool isLocationConfirmed;

  bool get hasCoords => latitude != null && longitude != null;

  String get label {
    if (type == PlaceType.home) return 'Casa';
    if (type == PlaceType.work) return 'Trabajo';
    return customLabel.isEmpty ? 'Otro' : customLabel;
  }

  String get icon {
    if (type == PlaceType.home) return '🏠';
    if (type == PlaceType.work) return '💼';
    return '📍';
  }

  String get line1 {
    final streetLine = [
      street,
      if (streetNumber.isNotEmpty) streetNumber,
    ].where((e) => e.trim().isNotEmpty).join(' ');
    if (streetLine.isNotEmpty) return streetLine;
    if (formattedAddress.isNotEmpty) return formattedAddress;
    return neighborhood.isNotEmpty ? neighborhood : city;
  }

  String get line2 {
    return [
      if (neighborhood.isNotEmpty) neighborhood,
      if (city.isNotEmpty) city,
    ].join(', ');
  }

  String get listSubtitle {
    final first = [
      line1,
      if (neighborhood.isNotEmpty && !line1.contains(neighborhood)) neighborhood,
    ].where((e) => e.trim().isNotEmpty).join(', ');
    return first;
  }

  String get discoveryLabel {
    if (neighborhood.isNotEmpty && city.isNotEmpty) {
      return '$neighborhood, $city';
    }
    return city.isNotEmpty ? city : formattedAddress;
  }

  bool get isIdentifiable =>
      city.trim().isNotEmpty &&
      (street.trim().isNotEmpty ||
          formattedAddress.trim().length >= 8 ||
          neighborhood.trim().isNotEmpty);

  bool get canConfirm => hasCoords && city.trim().isNotEmpty && isIdentifiable;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'customLabel': customLabel,
        'formattedAddress': formattedAddress,
        'street': street,
        'streetNumber': streetNumber,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
        'country': country,
        'countryCode': countryCode,
        'postalCode': postalCode,
        'latitude': latitude,
        'longitude': longitude,
        'apartment': apartment,
        'floor': floor,
        'reference': reference,
        'placeId': placeId,
        'geocodingProvider': geocodingProvider,
        'locationAccuracy': locationAccuracy,
        'isDefault': isDefault,
        'isLocationConfirmed': isLocationConfirmed,
      };

  factory UserPlace.fromJson(Map<String, dynamic> json) {
    return UserPlace(
      id: json['id'] as String? ?? '',
      type: PlaceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PlaceType.other,
      ),
      customLabel: json['customLabel'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      street: json['street'] as String? ?? '',
      streetNumber: json['streetNumber'] as String? ?? '',
      neighborhood: json['neighborhood'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      country: json['country'] as String? ?? 'Bolivia',
      countryCode: json['countryCode'] as String? ?? 'BO',
      postalCode: json['postalCode'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      apartment: json['apartment'] as String? ?? '',
      floor: json['floor'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      placeId: json['placeId'] as String? ?? '',
      geocodingProvider: json['geocodingProvider'] as String? ?? 'nominatim',
      locationAccuracy: (json['locationAccuracy'] as num?)?.toDouble(),
      isDefault: json['isDefault'] as bool? ?? false,
      isLocationConfirmed: json['isLocationConfirmed'] as bool? ?? false,
    );
  }

  UserPlace copy() => UserPlace.fromJson(toJson());
}

class ServiceLocationSnapshot {
  ServiceLocationSnapshot({
    this.placeId,
    this.label = '',
    this.formattedAddress = '',
    this.street = '',
    this.number = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.country = 'Bolivia',
    this.postalCode = '',
    this.latitude,
    this.longitude,
    this.apartment = '',
    this.floor = '',
    this.reference = '',
  });

  String? placeId;
  String label;
  String formattedAddress;
  String street;
  String number;
  String neighborhood;
  String city;
  String state;
  String country;
  String postalCode;
  double? latitude;
  double? longitude;
  String apartment;
  String floor;
  String reference;

  bool get hasCoords => latitude != null && longitude != null;

  bool get canConfirm =>
      hasCoords &&
      city.trim().isNotEmpty &&
      (street.trim().isNotEmpty ||
          neighborhood.trim().isNotEmpty ||
          formattedAddress.trim().length >= 8);

  String get locationLabel {
    if (formattedAddress.trim().isNotEmpty) return formattedAddress;
    return displayBody.replaceAll('\n', ', ');
  }

  String get displayTitle => label.isEmpty ? 'Lugar del servicio' : label;

  String get displayBody {
    final line = [
      if (street.isNotEmpty) '$street${number.isEmpty ? '' : ' $number'}',
      if (neighborhood.isNotEmpty) neighborhood,
      city,
    ].where((e) => e.trim().isNotEmpty).join('\n');
    return line.isEmpty ? formattedAddress : line;
  }

  String get publicHint {
    if (neighborhood.isNotEmpty) return neighborhood;
    return city;
  }

  factory ServiceLocationSnapshot.fromPlace(UserPlace place) {
    return ServiceLocationSnapshot(
      placeId: place.id,
      label: place.label,
      formattedAddress: place.formattedAddress.isEmpty
          ? place.line1
          : place.formattedAddress,
      street: place.street,
      number: place.streetNumber,
      neighborhood: place.neighborhood,
      city: place.city,
      state: place.state,
      country: place.country,
      postalCode: place.postalCode,
      latitude: place.latitude,
      longitude: place.longitude,
      apartment: place.apartment,
      floor: place.floor,
      reference: place.reference,
    );
  }

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'label': label,
        'formattedAddress': formattedAddress,
        'street': street,
        'number': number,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
        'country': country,
        'postalCode': postalCode,
        'latitude': latitude,
        'longitude': longitude,
        'apartment': apartment,
        'floor': floor,
        'reference': reference,
      };
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.placeId = '',
    this.street = '',
    this.number = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.country = 'Bolivia',
    this.postalCode = '',
  });

  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final String placeId;
  final String street;
  final String number;
  final String neighborhood;
  final String city;
  final String state;
  final String country;
  final String postalCode;
}
