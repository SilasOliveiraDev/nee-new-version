import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/availability.dart';
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

  test('direct pending timeline is not the marketplace offer path', () {
    final steps = RequestLifecycle.directSteps(
      DirectStatus.pending,
      RequestStatus.sent,
    );
    expect(steps.map((s) => s.label).toList(), [
      'Solicitud enviada',
      'Esperando respuesta',
      'Conversando',
      'Servicio',
    ]);
    expect(steps[1].current, isTrue);
    expect(steps.any((s) => s.label == 'Ofertas recibidas'), isFalse);
  });

  test('confirmed direct service shows travel steps', () {
    final steps = RequestLifecycle.directSteps(
      DirectStatus.confirmed,
      RequestStatus.accepted,
    );
    expect(steps.map((s) => s.label).toList(), [
      'Solicitud enviada',
      'Profesional seleccionado',
      'Profesional en camino',
      'Servicio en curso',
      'Finalizado',
    ]);
    expect(steps[1].current, isTrue);
    expect(
      RequestLifecycle.directSteps(
        DirectStatus.confirmed,
        RequestStatus.onTheWay,
      )[2].current,
      isTrue,
    );
  });

  test('declined direct request is not waiting for a reply', () {
    final steps = RequestLifecycle.directSteps(
      DirectStatus.declined,
      RequestStatus.cancelledByProfessional,
    );
    expect(steps.last.label, 'No puede atender');
    expect(steps.last.current, isTrue);
  });
}
