import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/request_lifecycle.dart';
import 'package:nee/models.dart';

void main() {
  test('timeline during offers stays compact', () {
    final steps = RequestLifecycle.steps(RequestStatus.professionalFound);
    expect(steps.map((s) => s.label).toList(), [
      'Solicitud publicada',
      'Ofertas recibidas',
      'Profesional seleccionado',
      'Servicio',
    ]);
    expect(steps[1].current, isTrue);
  });

  test('client copy never says Profesional asignado', () {
    for (final status in RequestStatus.values) {
      expect(RequestLifecycle.headline(status), isNot(contains('asignado')));
    }
  });
}
