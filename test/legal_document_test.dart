import 'package:flutter_test/flutter_test.dart';
import 'package:nee/legal/legal_document.dart';

void main() {
  test('parses privacy headings and the update badge', () {
    const raw = '''
# POLÍTICA DE PRIVACIDAD DE ÑEE!

**Última actualización:** 3 de septiembre de 2026
**Versión:** 1.0

Introducción.

## 1. ¿QUIÉN ES RESPONSABLE DEL TRATAMIENTO DE TUS DATOS?

La plataforma **Ñee!** es operada por Ñee Servicios Tecnologia.

* Nombre y apellidos.
''';
    final doc = parseLegalMarkdown(raw);
    expect(doc.meta.updatedLabel, '3 de septiembre de 2026');
    expect(doc.meta.version, '1.0');
    expect(doc.blocks.any((b) => b.kind == LegalBlockKind.heading), isTrue);
    expect(doc.blocks.any((b) => b.kind == LegalBlockKind.bullet), isTrue);
    expect(stripLegalMarks('**Ñee!**'), 'Ñee!');
  });
}
