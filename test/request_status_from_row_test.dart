import 'package:flutter_test/flutter_test.dart';
import 'package:nee/data/nee_repository.dart';
import 'package:nee/domain/availability.dart';
import 'package:nee/models.dart';

void main() {
  test('confirmado is not treated as completed', () {
    final request = NeeRepository.requestFromRow({
      'id': 1,
      'status': 'Confirmado',
      'direct_status': 'CONFIRMED',
      'request_kind': 'DIRECT',
      'categoria': 'Albañilería',
    });
    expect(request.status, RequestStatus.accepted);
  });

  test('service travel statuses map onto the client timeline', () {
    expect(
      NeeRepository.requestFromRow({
        'id': 2,
        'status': 'Profesional seleccionado',
      }).status,
      RequestStatus.accepted,
    );
    expect(
      NeeRepository.requestFromRow({
        'id': 3,
        'status': 'Profesional en camino',
      }).status,
      RequestStatus.onTheWay,
    );
    expect(
      NeeRepository.requestFromRow({
        'id': 4,
        'status': 'Servicio en curso',
      }).status,
      RequestStatus.inProgress,
    );
    expect(
      NeeRepository.requestFromRow({
        'id': 5,
        'status': 'Finalizado',
      }).status,
      RequestStatus.completed,
    );
  });

  test('coordenadas hydrate the service map destination', () {
    final request = NeeRepository.requestFromRow({
      'id': 6,
      'status': 'Profesional en camino',
      'coordenadas': '-17.78,-63.18',
      'address': 'Calle Gregorio Reynolds',
    });
    expect(request.serviceLocation?.hasCoords, isTrue);
    expect(request.serviceLocation?.latitude, closeTo(-17.78, 0.01));
  });

  test('professional decline maps to declined, not waiting', () {
    final request = NeeRepository.requestFromRow({
      'id': 9,
      'status': 'Cancelado por el profesional',
      'direct_status': 'DECLINED',
      'request_kind': 'DIRECT',
      'categoria': 'Albañilería',
    });
    expect(request.directStatus, DirectStatus.declined);
    expect(request.status, RequestStatus.cancelledByProfessional);
    expect(request.stageLabel, 'No puede atender');
  });
}
