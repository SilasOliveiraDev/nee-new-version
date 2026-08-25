import 'package:flutter_test/flutter_test.dart';
import 'package:nee/places/geo_match.dart';
import 'package:nee/places/scz_zone_coords.dart';

void main() {
  test('3 anillo sits on a ring around the plaza', () {
    final pin = resolveZonePin('3 anillo', id: 'a');
    final km = distanceKm(
      fromLat: sczPlazaLat,
      fromLng: sczPlazaLng,
      toLat: pin.latitude,
      toLng: pin.longitude,
    );
    expect(km, greaterThan(1.2));
    expect(km, lessThan(3.2));
    expect(pin.approximate, isTrue);
  });

  test('Urubó is west of the plaza', () {
    final pin = resolveZonePin('Urubó', id: 'u1');
    expect(pin.longitude, lessThan(sczPlazaLng));
    expect(pin.latitude, isNot(sczPlazaLat));
  });

  test('two ids in the same zone do not stack', () {
    final a = resolveZonePin('3 anillo', id: 'pro-one');
    final b = resolveZonePin('3 anillo', id: 'pro-two');
    expect(a.latitude, isNot(b.latitude));
    expect(a.longitude, isNot(b.longitude));
  });

  test('missing zone falls back to Santa Cruz center', () {
    final pin = resolveZonePin('', id: 'solo');
    final km = distanceKm(
      fromLat: sczPlazaLat,
      fromLng: sczPlazaLng,
      toLat: pin.latitude,
      toLng: pin.longitude,
    );
    expect(km, lessThan(0.8));
    expect(km, greaterThan(0.25));
  });
}
