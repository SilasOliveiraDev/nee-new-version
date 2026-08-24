enum ProOpsStatus { available, busy, offline, paused }

enum RequestKind { marketplace, direct }

enum DirectStatus {
  pending,
  negotiation,
  pendingConfirmation,
  confirmed,
  declined,
  expired,
  cancelled,
}

class AvailabilityView {
  const AvailabilityView({
    required this.status,
    required this.acceptingRequests,
    this.nextAvailableAt,
    this.labelCode = 'AVAILABLE_NOW',
  });

  final ProOpsStatus status;
  final bool acceptingRequests;
  final DateTime? nextAvailableAt;
  final String labelCode;

  bool get availableNow =>
      acceptingRequests && status == ProOpsStatus.available;

  String get primaryLabel {
    if (!acceptingRequests || status == ProOpsStatus.paused) {
      return 'No está recibiendo solicitudes';
    }
    if (status == ProOpsStatus.offline) {
      return 'No disponible ahora';
    }
    if (status == ProOpsStatus.busy && nextAvailableAt != null) {
      return 'Disponible a partir de las ${clock(nextAvailableAt!)}';
    }
    if (status == ProOpsStatus.busy) {
      return 'Ocupado ahora';
    }
    return 'Disponible ahora';
  }

  String get secondaryLabel {
    if (status == ProOpsStatus.busy && nextAvailableAt != null) {
      return 'Ocupado ahora';
    }
    return '';
  }

  String get emoji {
    if (!acceptingRequests ||
        status == ProOpsStatus.paused ||
        status == ProOpsStatus.offline) {
      return '⚪';
    }
    if (status == ProOpsStatus.busy) return '🟡';
    return '🟢';
  }

  static String clock(DateTime at) {
    final local = at.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory AvailabilityView.fromJson(Map<String, dynamic> json) {
    final code = '${json['status'] ?? 'AVAILABLE'}'.toUpperCase();
    final status = switch (code) {
      'BUSY' => ProOpsStatus.busy,
      'OFFLINE' => ProOpsStatus.offline,
      'PAUSED' => ProOpsStatus.paused,
      _ => ProOpsStatus.available,
    };
    return AvailabilityView(
      status: status,
      acceptingRequests: json['accepting_requests'] != false,
      nextAvailableAt: DateTime.tryParse('${json['next_available_at'] ?? ''}'),
      labelCode: '${json['label_code'] ?? ''}',
    );
  }
}

class ScheduleConflict {
  const ScheduleConflict({required this.aStart, required this.aEnd});

  final DateTime aStart;
  final DateTime aEnd;
}

/// Sobreposição de janelas com buffer depois do fim. Intervalos [start, end+buffer).
bool scheduleOverlaps({
  required DateTime aStart,
  required DateTime aEnd,
  required DateTime bStart,
  required DateTime bEnd,
  int bufferMinutes = 15,
}) {
  final aUntil = aEnd.add(Duration(minutes: bufferMinutes));
  final bUntil = bEnd.add(Duration(minutes: bufferMinutes));
  return aStart.isBefore(bUntil) && bStart.isBefore(aUntil);
}

DateTime nextSlotAfter({
  required DateTime occupiedEnd,
  int bufferMinutes = 15,
}) {
  return occupiedEnd.add(Duration(minutes: bufferMinutes));
}

DirectStatus? directStatusFromApi(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'PENDING_PROFESSIONAL_RESPONSE':
      return DirectStatus.pending;
    case 'NEGOTIATION':
      return DirectStatus.negotiation;
    case 'PENDING_CONFIRMATION':
      return DirectStatus.pendingConfirmation;
    case 'CONFIRMED':
      return DirectStatus.confirmed;
    case 'DECLINED':
      return DirectStatus.declined;
    case 'EXPIRED':
      return DirectStatus.expired;
    case 'CANCELLED':
      return DirectStatus.cancelled;
    default:
      return null;
  }
}

String apiDirectStatus(DirectStatus status) {
  switch (status) {
    case DirectStatus.pending:
      return 'PENDING_PROFESSIONAL_RESPONSE';
    case DirectStatus.negotiation:
      return 'NEGOTIATION';
    case DirectStatus.pendingConfirmation:
      return 'PENDING_CONFIRMATION';
    case DirectStatus.confirmed:
      return 'CONFIRMED';
    case DirectStatus.declined:
      return 'DECLINED';
    case DirectStatus.expired:
      return 'EXPIRED';
    case DirectStatus.cancelled:
      return 'CANCELLED';
  }
}
