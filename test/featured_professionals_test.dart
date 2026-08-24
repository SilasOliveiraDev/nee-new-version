import 'package:flutter_test/flutter_test.dart';
import 'package:nee/client/air_query.dart';
import 'package:nee/data/professional_mapper.dart';
import 'package:nee/mock_data.dart';

void main() {
  test('only active providers from a catalog are offered to the client', () {
    final ready = professionalsReadyToHelp(
      '',
      catalog: [
        professionals[0],
        professionals[4],
      ],
    );
    expect(ready, hasLength(1));
    expect(ready.first.id, professionals[0].id);
  });

  test('maps plataforma users marked isDestacado without fake distance', () {
    final pro = professionalFromUserRow({
      'professional_id': 'abc',
      'display_name': 'Romero Gol',
      'user_type': 'Servicio',
      'category_name': 'Reparaciones',
      'category_id': 2,
      'is_featured': true,
      'is_blocked': false,
      'latlng': '-17.78,-63.18',
    });
    expect(pro.isDestaque, isTrue);
    expect(pro.categoryId, '2');
    expect(pro.hasMapPin, isTrue);
    expect(pro.initials, 'RG');
    expect(pro.distanceKm, isNull);
    expect(pro.distanceLabel, isNull);
    expect(pro.ratingLabel, 'Nuevo profesional');
    expect(pro.jobsLabel, 'Nuevo en Ñee');
    expect(pro.verified, isFalse);
  });

  test('verified users from users.verified go to destacados only', () {
    final verified = professionalFromUserRow({
      'professional_id': 'v1',
      'display_name': 'Ana Verificada',
      'user_type': 'Servicio',
      'verified': true,
      'latlng': '-17.78,-63.18',
    });
    final nearby = professionalFromUserRow({
      'professional_id': 'n1',
      'display_name': 'Luis Cerca',
      'user_type': 'Servicio',
      'verified': false,
      'latlng': '-17.781,-63.18',
    });
    expect(verified.verified, isTrue);
    expect(nearby.verified, isFalse);

    final catalog = [verified, nearby];
    expect(featuredOnAir(catalog).map((p) => p.id), ['v1']);
    expect(onAirNearby(catalog).map((p) => p.id), ['n1']);
  });

  test('computes distance only with both coordinates', () {
    final pro = professionalFromUserRow(
      {
        'professional_id': 'abc',
        'display_name': 'Romero Gol',
        'user_type': 'Servicio',
        'latlng': '-17.78,-63.18',
      },
      originLat: -17.79,
      originLng: -63.18,
    );
    expect(pro.distanceKm, isNotNull);
    expect(pro.distanceLabel, isNot(contains('99')));
  });

  test('cliente user type is not a provider', () {
    expect(isProviderType('Cliente'), isFalse);
    expect(isProviderType('Servicio'), isTrue);
  });
}
