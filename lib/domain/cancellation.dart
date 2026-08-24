enum CancelReason {
  noLongerNeeded,
  scheduleChanged,
  createdByMistake,
  foundAnotherSolution,
  noAgreement,
  professionalCouldNotPerform,
  professionalNoShow,
  professionalRequestedCancel,
  serviceNotAsAgreed,
  priceChanged,
  safetyConcern,
  technicalError,
  other,
}

enum CancelPhase { beforeSelect, afterSelect, onTheWay, inProgress }

class CancelReasonSpec {
  const CancelReasonSpec(this.code, this.label, {this.countsTowardRapidCancel = true});

  final CancelReason code;
  final String label;
  final bool countsTowardRapidCancel;
}

class CancellationPolicy {
  const CancellationPolicy({
    required this.rapidCancelEnabled,
    required this.windowMinutes,
    required this.limit,
    required this.restrictionMinutes,
  });

  final bool rapidCancelEnabled;
  final int windowMinutes;
  final int limit;
  final int restrictionMinutes;

  static const fallback = CancellationPolicy(
    rapidCancelEnabled: true,
    windowMinutes: 5,
    limit: 2,
    restrictionMinutes: 15,
  );

  factory CancellationPolicy.fromJson(Map<String, dynamic> json) {
    return CancellationPolicy(
      rapidCancelEnabled: json['rapid_cancel_enabled'] as bool? ?? true,
      windowMinutes: (json['rapid_cancel_window_minutes'] as num?)?.toInt() ?? 5,
      limit: (json['rapid_cancel_limit'] as num?)?.toInt() ?? 2,
      restrictionMinutes:
          (json['temporary_restriction_minutes'] as num?)?.toInt() ?? 15,
    );
  }
}

class CancelOutcome {
  CancelOutcome({this.restriction});

  final UserRestriction? restriction;
}

class CancelEvent {
  CancelEvent({
    required this.requestId,
    required this.reason,
    required this.countsTowardRapidCancel,
    required this.createdAt,
    this.reasonText = '',
  });

  final String requestId;
  final CancelReason reason;
  final bool countsTowardRapidCancel;
  final DateTime createdAt;
  final String reasonText;
}

class UserRestriction {
  UserRestriction({
    required this.expiresAt,
    this.reason = 'CREATE_SERVICE_TEMPORARILY_BLOCKED',
  });

  final DateTime expiresAt;
  final String reason;

  bool get isActive => DateTime.now().isBefore(expiresAt);

  Duration get remaining {
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  String get countdown {
    final d = remaining;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

bool countsTowardRapidCancel(CancelReason reason) {
  switch (reason) {
    case CancelReason.professionalCouldNotPerform:
    case CancelReason.professionalNoShow:
    case CancelReason.professionalRequestedCancel:
    case CancelReason.safetyConcern:
    case CancelReason.technicalError:
      return false;
    default:
      return true;
  }
}

List<CancelReasonSpec> reasonsFor(CancelPhase phase) {
  switch (phase) {
    case CancelPhase.beforeSelect:
      return const [
        CancelReasonSpec(CancelReason.noLongerNeeded, 'Ya no necesito el servicio'),
        CancelReasonSpec(CancelReason.scheduleChanged, 'Cambié de horario'),
        CancelReasonSpec(CancelReason.createdByMistake, 'Publiqué por error'),
        CancelReasonSpec(CancelReason.foundAnotherSolution, 'Encontré otra solución'),
        CancelReasonSpec(CancelReason.other, 'Otro motivo'),
      ];
    case CancelPhase.afterSelect:
      return const [
        CancelReasonSpec(CancelReason.noLongerNeeded, 'Ya no necesito el servicio'),
        CancelReasonSpec(CancelReason.scheduleChanged, 'Cambié de horario'),
        CancelReasonSpec(CancelReason.foundAnotherSolution, 'Encontré otra solución'),
        CancelReasonSpec(CancelReason.noAgreement, 'No llegamos a un acuerdo'),
        CancelReasonSpec(CancelReason.professionalRequestedCancel, 'El profesional solicitó cancelar'),
        CancelReasonSpec(CancelReason.other, 'Otro motivo'),
      ];
    case CancelPhase.onTheWay:
      return reasonsFor(CancelPhase.afterSelect);
    case CancelPhase.inProgress:
      return const [
        CancelReasonSpec(CancelReason.professionalCouldNotPerform, 'El profesional no pudo realizar el trabajo'),
        CancelReasonSpec(CancelReason.serviceNotAsAgreed, 'El servicio no era lo acordado'),
        CancelReasonSpec(CancelReason.priceChanged, 'El precio cambió'),
        CancelReasonSpec(CancelReason.noAgreement, 'No llegamos a un acuerdo'),
        CancelReasonSpec(CancelReason.professionalRequestedCancel, 'El profesional solicitó cancelar'),
        CancelReasonSpec(CancelReason.safetyConcern, 'Me siento inseguro'),
        CancelReasonSpec(CancelReason.other, 'Otro motivo'),
      ];
  }
}

String labelForReason(CancelReason reason) {
  for (final phase in CancelPhase.values) {
    for (final spec in reasonsFor(phase)) {
      if (spec.code == reason) return spec.label;
    }
  }
  return 'Cancelado';
}

String apiReasonCode(CancelReason reason) {
  switch (reason) {
    case CancelReason.noLongerNeeded:
      return 'NO_LONGER_NEEDED';
    case CancelReason.scheduleChanged:
      return 'SCHEDULE_CHANGED';
    case CancelReason.createdByMistake:
      return 'CREATED_BY_MISTAKE';
    case CancelReason.foundAnotherSolution:
      return 'FOUND_ANOTHER_SOLUTION';
    case CancelReason.noAgreement:
      return 'NO_AGREEMENT';
    case CancelReason.professionalCouldNotPerform:
      return 'PROFESSIONAL_COULD_NOT_PERFORM';
    case CancelReason.professionalNoShow:
      return 'PROFESSIONAL_NO_SHOW';
    case CancelReason.professionalRequestedCancel:
      return 'PROFESSIONAL_REQUESTED_CANCEL';
    case CancelReason.serviceNotAsAgreed:
      return 'SERVICE_NOT_AS_AGREED';
    case CancelReason.priceChanged:
      return 'PRICE_CHANGED';
    case CancelReason.safetyConcern:
      return 'SAFETY_CONCERN';
    case CancelReason.technicalError:
      return 'TECHNICAL_ERROR';
    case CancelReason.other:
      return 'OTHER';
  }
}
