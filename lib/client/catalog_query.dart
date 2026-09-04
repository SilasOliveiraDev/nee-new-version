import '../models.dart';

/// Ofícios que o cliente vê primeiro (IDs reais de `public.categories`).
const popularCategoryIds = [
  '1',
  '2',
  '3',
  '5',
  '7',
  '8',
  '10',
  '14',
];

List<ServiceCategory> spotlightCategories(
  List<ServiceCategory> all, {
  int max = 8,
}) {
  if (all.isEmpty) return const [];
  final byId = {for (final category in all) category.id: category};
  final out = <ServiceCategory>[];
  for (final id in popularCategoryIds) {
    final category = byId[id];
    if (category == null) continue;
    out.add(category);
    if (out.length >= max) return out;
  }
  for (final category in all) {
    if (out.any((item) => item.id == category.id)) continue;
    out.add(category);
    if (out.length >= max) break;
  }
  return out;
}

List<ServiceCategory> filterCategories(List<ServiceCategory> all, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return all;
  return [
    for (final category in all)
      if (category.name.toLowerCase().contains(needle) ||
          category.hint.toLowerCase().contains(needle))
        category,
  ];
}
