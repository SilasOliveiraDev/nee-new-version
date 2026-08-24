import 'package:flutter_test/flutter_test.dart';
import 'package:nee/data/professional_mapper.dart';
import 'package:nee/mock_data.dart';
import 'package:nee/models.dart';

void main() {
  test('only destacados from a catalog are offered to the client', () {
    final featured = professionals[0];
    final ready = professionalsReadyToHelp(
      '',
      catalog: [
        featured,
        professionals[4],
      ],
    );
    expect(ready, isEmpty);

    final highlighted = professionalsReadyToHelp(
      'plomeria',
      catalog: [
        Professional(
          id: featured.id,
          name: featured.name,
          specialty: featured.specialty,
          categoryId: featured.categoryId,
          city: featured.city,
          initials: featured.initials,
          rating: featured.rating,
          jobs: featured.jobs,
          isDestaque: true,
        ),
      ],
    );
    expect(highlighted, hasLength(1));
  });

  test('maps plataforma users marked isDestacado', () {
    final pro = professionalFromUserRow({
      'id': 25,
      'name': 'Romero Gol',
      'Categoria': 'Reparaciones',
      'categoriaId': 2,
      'isDestacado': true,
      'isBloqueado': false,
      'isDeletado': false,
      'latlng': '-17.78,-63.18',
    });
    expect(pro.isDestaque, isTrue);
    expect(pro.categoryId, 'reparaciones');
    expect(pro.hasMapPin, isTrue);
    expect(pro.initials, 'RG');
  });
}
