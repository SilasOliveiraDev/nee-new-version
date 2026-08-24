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
    if (category?.id == 'belleza' || category?.id == 'cursos') {
      return ResolveHint.browse;
    }
    if (browse.any(t.contains)) return ResolveHint.browse;
    if (text.trim().length > 48) return ResolveHint.publish;
    if (category != null && text.trim().isEmpty) return ResolveHint.browse;
    return ResolveHint.either;
  }

  static ServiceCategory? guessCategory(String text) {
    final t = text.toLowerCase();
    for (final category in categories) {
      if (t.contains(category.name.toLowerCase())) return category;
    }
    for (final category in categories) {
      if (category.id == 'electricidad' &&
          (t.contains('ducha') || t.contains('luz') || t.contains('enchufe'))) {
        return category;
      }
      if (category.id == 'plomeria' &&
          (t.contains('agua') || t.contains('caño') || t.contains('grifo'))) {
        return category;
      }
      if (category.id == 'jardineria' &&
          (t.contains('césped') || t.contains('cesped') || t.contains('pasto'))) {
        return category;
      }
      if (category.id == 'refrigeracion' &&
          (t.contains('aire') || t.contains('heladera'))) {
        return category;
      }
    }
    return null;
  }

  static List<String> specialtiesOf(ServiceCategory? category) {
    if (category == null) return const [];
    final trade = tradeById(category.id);
    return trade?.specialties ?? const [];
  }
}
