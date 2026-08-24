import 'package:flutter_test/flutter_test.dart';
import 'package:nee/places/geo_match.dart';
import 'package:nee/places/place_models.dart';

void main() {
  test('snapshot copies place fields for an immutable request', () {
    final place = UserPlace(
      id: 'home-1',
      type: PlaceType.home,
      street: 'Av. San Martín',
      streetNumber: '1234',
      neighborhood: 'Equipetrol',
      city: 'Santa Cruz de la Sierra',
      latitude: -17.7833,
      longitude: -63.1821,
      isLocationConfirmed: true,
    );
    final snap = ServiceLocationSnapshot.fromPlace(place);
    expect(snap.canConfirm, isTrue);
    expect(snap.label, 'Casa');
    expect(snap.street, 'Av. San Martín');
    expect(snap.number, '1234');
    place.street = 'Otra calle';
    expect(snap.street, 'Av. San Martín');
  });

  test('city-only without coords cannot confirm a service location', () {
    final place = UserPlace(
      id: 'x',
      city: 'Santa Cruz de la Sierra',
    );
    expect(place.canConfirm, isFalse);
    expect(ServiceLocationSnapshot.fromPlace(place).canConfirm, isFalse);
  });

  test('matching uses coordinates, not only city', () {
    final km = distanceKm(
      fromLat: -17.7833,
      fromLng: -63.1821,
      toLat: -17.7690,
      toLng: -63.1800,
    );
    expect(km, closeTo(1.6, 0.3));
    expect(
      isWithinRadiusKm(
        fromLat: -17.7833,
        fromLng: -63.1821,
        toLat: -17.7690,
        toLng: -63.1800,
        radiusKm: 5,
      ),
      isTrue,
    );
  });
}
