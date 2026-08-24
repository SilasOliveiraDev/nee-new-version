import '../models.dart';

class TimelineStep {
  const TimelineStep({
    required this.label,
    required this.done,
    required this.current,
  });

  final String label;
  final bool done;
  final bool current;
}

class RequestLifecycle {
  static String headline(RequestStatus status) {
    switch (status) {
      case RequestStatus.sent:
        return 'Esperando ofertas';
      case RequestStatus.professionalFound:
        return 'Ofertas recibidas';
      case RequestStatus.accepted:
        return 'Profesional seleccionado';
      case RequestStatus.onTheWay:
        return 'Profesional en camino';
      case RequestStatus.inProgress:
        return 'Servicio en curso';
      case RequestStatus.awaitingRating:
        return 'Pendiente de calificación';
      case RequestStatus.completed:
        return 'Completado';
      case RequestStatus.cancelledByCustomer:
        return 'Cancelado por ti';
      case RequestStatus.cancelledByProfessional:
        return 'Cancelado por el profesional';
      case RequestStatus.notCompleted:
        return 'No se pudo realizar';
    }
  }

  static String primaryCta(RequestStatus status) {
    switch (status) {
      case RequestStatus.sent:
        return 'Ver solicitud';
      case RequestStatus.professionalFound:
        return 'Ver ofertas';
      case RequestStatus.accepted:
        return 'Contactar profesional';
      case RequestStatus.onTheWay:
        return 'Ver llegada';
      case RequestStatus.inProgress:
        return 'Ver detalles del servicio';
      case RequestStatus.awaitingRating:
      case RequestStatus.completed:
        return 'Calificar servicio';
      case RequestStatus.cancelledByCustomer:
      case RequestStatus.cancelledByProfessional:
      case RequestStatus.notCompleted:
        return 'Entendido';
    }
  }

  static bool canCancelStatus(RequestStatus status) {
    switch (status) {
      case RequestStatus.completed:
      case RequestStatus.awaitingRating:
      case RequestStatus.cancelledByCustomer:
      case RequestStatus.cancelledByProfessional:
      case RequestStatus.notCompleted:
        return false;
      default:
        return true;
    }
  }

  static bool isClosed(RequestStatus status) {
    switch (status) {
      case RequestStatus.completed:
      case RequestStatus.cancelledByCustomer:
      case RequestStatus.cancelledByProfessional:
      case RequestStatus.notCompleted:
        return true;
      default:
        return false;
    }
  }

  static bool hasProfessional(RequestStatus status) {
    switch (status) {
      case RequestStatus.accepted:
      case RequestStatus.onTheWay:
      case RequestStatus.inProgress:
      case RequestStatus.awaitingRating:
      case RequestStatus.completed:
        return true;
      default:
        return false;
    }
  }

  static List<TimelineStep> steps(RequestStatus status) {
    if (status == RequestStatus.cancelledByCustomer ||
        status == RequestStatus.cancelledByProfessional ||
        status == RequestStatus.notCompleted) {
      return [
        const TimelineStep(label: 'Solicitud publicada', done: true, current: false),
        TimelineStep(label: headline(status), done: true, current: true),
      ];
    }

    final published = true;
    final selected = status.index >= RequestStatus.accepted.index &&
        status.index < RequestStatus.cancelledByCustomer.index;
    final onWay = status.index >= RequestStatus.onTheWay.index;
    final inCourse = status.index >= RequestStatus.inProgress.index;
    final done = status == RequestStatus.completed ||
        status == RequestStatus.awaitingRating;

    if (status == RequestStatus.sent ||
        status == RequestStatus.professionalFound) {
      return [
        TimelineStep(
          label: 'Solicitud publicada',
          done: published,
          current: false,
        ),
        TimelineStep(
          label: 'Ofertas recibidas',
          done: status == RequestStatus.professionalFound,
          current: status == RequestStatus.professionalFound,
        ),
        TimelineStep(
          label: 'Profesional seleccionado',
          done: false,
          current: false,
        ),
        const TimelineStep(label: 'Servicio', done: false, current: false),
      ];
    }

    return [
      TimelineStep(label: 'Solicitud publicada', done: published, current: false),
      TimelineStep(
        label: 'Profesional seleccionado',
        done: selected,
        current: status == RequestStatus.accepted,
      ),
      TimelineStep(
        label: 'Profesional en camino',
        done: onWay && status != RequestStatus.accepted,
        current: status == RequestStatus.onTheWay,
      ),
      TimelineStep(
        label: 'Servicio en curso',
        done: inCourse && status != RequestStatus.onTheWay,
        current: status == RequestStatus.inProgress,
      ),
      TimelineStep(
        label: 'Finalizado',
        done: done,
        current: status == RequestStatus.awaitingRating ||
            status == RequestStatus.completed,
      ),
    ];
  }
}
