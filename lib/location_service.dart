import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'models.dart';

class DetectedLocation {
  const DetectedLocation({this.address, this.error});

  final GeoAddress? address;
  final String? error;
}

Future<DetectedLocation> detectLocation() async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) {
    return const DetectedLocation(
      error: 'Activa la ubicación de tu dispositivo para continuar.',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return const DetectedLocation(
      error:
          'Necesitamos tu ubicación para conectarte con servicios y oportunidades cerca.',
    );
  }

  final position = await Geolocator.getCurrentPosition();
  final address = GeoAddress(
    latitude: position.latitude,
    longitude: position.longitude,
    country: 'Bolivia',
    street:
        '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
  );

  if (!kIsWeb) {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (marks.isNotEmpty) {
        final mark = marks.first;
        address
          ..street = (mark.street ?? '').trim()
          ..number = (mark.subThoroughfare ?? '').trim()
          ..zone = (mark.subLocality ?? mark.thoroughfare ?? '').trim()
          ..city = (mark.locality ?? '').trim()
          ..department = (mark.administrativeArea ?? '').trim()
          ..country = (mark.country ?? 'Bolivia').trim();
      }
    } catch (_) {}
  }

  return DetectedLocation(address: address);
}
