import 'mock_data.dart';
import 'models.dart';

enum ResolveHint { browse, publish, either }

class NeedIntel {
  static ResolveHint hintFor({
    required String text,
    ServiceCategory? category,
    String specialty = '',
  }) {
    final t = '${text.toLowerCase()} ${specialty.toLowerCase()}';
    const messy = [
      'humedad',
      'filtración',
      'filtracion',
      'infiltración',
      'infiltracion',
      'no sé',
      'no se',
      'no se de donde',
      'dentro de la pared',
      'está empeorando',
      'esta empeorando',
      'perdió',
      'perdida',
      'pérdida',
      'dejó de funcionar',
      'dejo de funcionar',
      'raro',
      'no encuentro',
    ];
    const browse = [
      'manicure',
      'uñas',
      'unas',
      'corte',
      'barber',
      'césped',
      'cesped',
      'jardín',
      'jardin',
      'clases',
      'curso',
      'maquillaje',
    ];
    if (messy.any(t.contains)) return ResolveHint.publish;
    if (category?.id == 'belleza' ||
        category?.id == '5' ||
        category?.id == 'cursos') {
      return ResolveHint.browse;
    }
    if (browse.any(t.contains)) return ResolveHint.browse;
    if (text.trim().length > 48) return ResolveHint.publish;
    if (category != null && text.trim().isEmpty) return ResolveHint.browse;
    return ResolveHint.either;
  }

  static ServiceCategory? guessCategory(
    String text, {
    List<ServiceCategory>? catalog,
  }) {
    final pool = catalog ?? categories;
    final t = text.toLowerCase();
    for (final category in pool) {
      if (t.contains(category.name.toLowerCase())) return category;
    }
    for (final category in pool) {
      final label = category.name.toLowerCase();
      if ((label.contains('electric') || category.id == 'electricidad') &&
          (t.contains('ducha') || t.contains('luz') || t.contains('enchufe'))) {
        return category;
      }
      if ((label.contains('plom') ||
              label.contains('reparac') ||
              category.id == 'plomeria') &&
          (t.contains('agua') || t.contains('caño') || t.contains('grifo'))) {
        return category;
      }
      if ((label.contains('jard') || category.id == 'jardineria') &&
          (t.contains('césped') || t.contains('cesped') || t.contains('pasto'))) {
        return category;
      }
      if ((label.contains('refrig') ||
              label.contains('tecnolog') ||
              category.id == 'refrigeracion') &&
          (t.contains('aire') || t.contains('heladera'))) {
        return category;
      }
    }
    return null;
  }

  static List<String> specialtiesOf(ServiceCategory? category) {
    if (category == null) return const [];
    final trade = tradeById(category.id);
    if (trade != null) return trade.specialties;
    final name = category.name.toLowerCase();
    for (final item in trades) {
      if (item.name.toLowerCase() == name || item.group.toLowerCase() == name) {
        return item.specialties;
      }
    }
    for (final item in trades) {
      final tradeName = item.name.toLowerCase();
      if (name.contains(tradeName) || tradeName.contains(name)) {
        return item.specialties;
      }
    }
    return const [];
  }
}
