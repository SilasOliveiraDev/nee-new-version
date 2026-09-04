import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nee/client/catalog_query.dart';
import 'package:nee/mock_data.dart';
import 'package:nee/models.dart';
import 'package:nee/need_intel.dart';

ServiceCategory cat(String id, String name) => ServiceCategory(
  id: id,
  name: name,
  icon: Icons.handyman_outlined,
  hint: '',
);

void main() {
  test('spotlight prefers real popular ids then fills the rest', () {
    final all = [
      cat('99', 'Otros'),
      cat('2', 'Reparaciones'),
      cat('1', 'Hogar'),
      cat('3', 'Limpieza'),
    ];
    final spotlight = spotlightCategories(all, max: 3);
    expect(spotlight.map((c) => c.id).toList(), ['1', '2', '3']);
  });

  test('filterCategories matches name without dumping the whole catalog', () {
    final all = [
      cat('2', 'Reparaciones'),
      cat('5', 'Belleza'),
      cat('7', 'Tecnología'),
    ];
    expect(filterCategories(all, 'bell').map((c) => c.id), ['5']);
    expect(filterCategories(all, '  ').length, 3);
  });

  test('matching by numeric category id also uses the category name', () {
    final pro = Professional(
      id: 'px',
      name: 'Romero',
      specialty: 'General',
      categoryId: '2',
      categoryName: 'Reparaciones',
      city: 'Santa Cruz',
      initials: 'RG',
      isActive: true,
    );
    final byId = professionalsReadyToHelp('2', catalog: [pro]);
    final byName = professionalsReadyToHelp(
      '2',
      catalog: [pro],
      categoryName: 'Reparaciones',
    );
    expect(byId, hasLength(1));
    expect(byName, hasLength(1));
  });

  test('guessCategory uses the live catalog names', () {
    final catalog = [cat('2', 'Reparaciones'), cat('5', 'Belleza')];
    expect(NeedIntel.guessCategory('necesito reparaciones', catalog: catalog)?.id, '2');
  });
}
