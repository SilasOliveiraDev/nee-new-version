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
                        if (professional.distanceLabel != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          professional.distanceLabel!,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        ],
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
      width: 168,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 0,
        shadowColor: NeeColors.soot.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeeRadii.tile),
          side: const BorderSide(color: NeeColors.vest, width: 1.6),
        ),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(NeeRadii.tile),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SignalAvatar(professional: professional, radius: 24),
                    const Spacer(),
                    const Icon(Icons.verified, color: NeeColors.vest, size: 20),
                  ],
                ),
                const Spacer(),
                Text(
                  professional.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: ink,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                const NeeVerifiedBadge(),
                const SizedBox(height: 6),
                Text(
                  [
                    professional.ratingLabel,
                    if (professional.distanceLabel != null)
                      professional.distanceLabel!,
                  ].join('  '),
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

class NeeVerifiedBadge extends StatelessWidget {
  const NeeVerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: NeeColors.vest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(NeeRadii.pill),
      ),
      child: const Text(
        '✓ Verificado',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: NeeColors.soot,
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
    final url = professional.avatarUrl;
    final network = url != null && url.startsWith('http') ? url : null;
    return CircleAvatar(
      radius: radius,
      backgroundColor: lit ? NeeColors.vest : Theme.of(context).colorScheme.surface,
      foregroundColor: NeeColors.soot,
      backgroundImage: network == null ? null : NetworkImage(network),
      child: network == null
          ? Text(
              professional.initials,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: lit
                    ? NeeColors.soot
                    : Theme.of(context).colorScheme.onSurface,
              ),
            )
          : null,
    );
  }
}

/// Alias used by the old home list.
typedef NearbyProCard = NeeOnAirTile;
