import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'nee_status_pill.dart';

class NeeOnAirTile extends StatelessWidget {
  const NeeOnAirTile({
    super.key,
    required this.professional,
    required this.onOpen,
    this.onQuote,
  });

  final Professional professional;
  final VoidCallback onOpen;
  final VoidCallback? onQuote;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final face = Theme.of(context).colorScheme.surface;
    return Material(
      color: face,
      elevation: 0,
      shadowColor: NeeColors.soot.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeeRadii.tile),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(NeeRadii.tile),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              _SignalAvatar(professional: professional),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      professional.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: ink,
                      ),
                    ),
                    Text(
                      professional.specialty,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.62),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        NeeOnAirMark(
                          professional: professional,
                          compact: true,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${professional.distanceKm.toStringAsFixed(1)} km',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onQuote != null)
                FilledButton(
                  onPressed: professional.acceptingRequests ? onQuote : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Sintonizar'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NeeFeaturedAirCard extends StatelessWidget {
  const NeeFeaturedAirCard({
    super.key,
    required this.professional,
    required this.onOpen,
  });

  final Professional professional;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 148,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(NeeRadii.tile),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(NeeRadii.tile),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SignalAvatar(professional: professional, radius: 22),
                const Spacer(),
                Text(
                  professional.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, color: ink),
                ),
                Text(
                  '${professional.rating}  ${professional.distanceKm.toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignalAvatar extends StatelessWidget {
  const _SignalAvatar({required this.professional, this.radius = 26});

  final Professional professional;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final lit = professional.available;
    return CircleAvatar(
      radius: radius,
      backgroundColor: lit ? NeeColors.vest : Theme.of(context).colorScheme.surface,
      foregroundColor: NeeColors.soot,
      child: Text(
        professional.initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: lit
              ? NeeColors.soot
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Alias used by the old home list.
typedef NearbyProCard = NeeOnAirTile;
