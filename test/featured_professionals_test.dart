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

  test('verified users stay in Cerca de ti and also fill destacados', () {
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

    final catalog = [nearby, verified];
    expect(featuredOnAir(catalog).map((p) => p.id), ['v1']);
    expect(onAirNearby(catalog).map((p) => p.id), ['v1', 'n1']);
  });

  test('verified professionals without coordinates still appear nearby', () {
    final verified = professionalFromUserRow({
      'professional_id': 'v2',
      'display_name': 'Karla Verificada',
      'user_type': 'Servicio',
      'verified': true,
    });
    final nearby = professionalFromUserRow(
      {
        'professional_id': 'n2',
        'display_name': 'Luis Cerca',
        'user_type': 'Servicio',
        'verified': false,
        'latlng': '-17.78,-63.18',
      },
      originLat: -17.781,
      originLng: -63.18,
    );
    final catalog = [nearby, verified];
    expect(onAirNearby(catalog).map((p) => p.id), ['v2', 'n2']);
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

  test('cerca de ti pages 15 professionals at a time', () {
    final catalog = [
      for (var i = 0; i < 37; i++)
        professionalFromUserRow({
          'professional_id': 'p$i',
          'display_name': 'Pro $i',
          'user_type': 'Servicio',
          'verified': false,
        }),
    ];
    expect(nearbyPageCount(catalog.length), 3);
    expect(nearbyPageOf(catalog, 0), hasLength(15));
    expect(nearbyPageOf(catalog, 1), hasLength(15));
    expect(nearbyPageOf(catalog, 2).map((p) => p.id), ['p30', 'p31', 'p32', 'p33', 'p34', 'p35', 'p36']);
  });

  test('maps category_name onto the professional card label', () {
    final pro = professionalFromUserRow({
      'professional_id': 'c1',
      'display_name': 'Ana Plomería',
      'user_type': 'Servicio',
      'category_name': 'Plomería',
      'category_id': 1,
      'specialty': 'Destapes',
    });
    expect(pro.categoryLabel, 'Plomería');
    expect(pro.specialtyIfDifferent, 'Destapes');
  });

  test('uses Categoria text when category_id is missing', () {
    final pro = professionalFromUserRow({
      'professional_id': 'c2',
      'display_name': 'Jhonni',
      'user_type': 'Servicio',
      'Categoria': 'Jardinería',
      'specialty': '',
    });
    expect(pro.categoryLabel, 'Jardinería');
    expect(pro.specialtyIfDifferent, isNull);
  });
}
