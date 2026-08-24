import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class NeeStatusPill extends StatelessWidget {
  const NeeStatusPill({super.key, required this.status, this.label});

  final RequestStatus status;
  final String? label;

  Color get _tone {
    switch (status) {
      case RequestStatus.sent:
      case RequestStatus.professionalFound:
        return NeeColors.waiting;
      case RequestStatus.accepted:
      case RequestStatus.onTheWay:
      case RequestStatus.inProgress:
      case RequestStatus.awaitingRating:
        return NeeColors.assigned;
      case RequestStatus.completed:
        return NeeColors.open;
      case RequestStatus.cancelledByCustomer:
      case RequestStatus.cancelledByProfessional:
      case RequestStatus.notCompleted:
        return NeeColors.muted;
    }
  }

  String get _air => label ?? status.label;

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    return Semantics(
      label: status.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(NeeRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              _air,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NeeOnAirMark extends StatelessWidget {
  const NeeOnAirMark({
    super.key,
    this.onAir,
    this.professional,
    this.compact = false,
  });

  final bool? onAir;
  final Professional? professional;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final view = professional?.availability;
    final label = view?.primaryLabel ??
        ((onAir ?? true) ? 'Disponible ahora' : 'Ocupado ahora');
    final lit = view?.availableNow ?? onAir ?? true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 7 : 8,
          height: compact ? 7 : 8,
          decoration: BoxDecoration(
            color: lit ? NeeColors.vest : NeeColors.muted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
      ],
    );
  }
}
