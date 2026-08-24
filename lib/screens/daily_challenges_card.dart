import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/engagement.dart';
import '../theme.dart';

class DailyChallengesScreen extends StatelessWidget {
  const DailyChallengesScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Desafíos')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final open = state.todayChallenges.where((c) => !c.done).toList();
          final done = state.todayChallenges.where((c) => c.done).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Desafíos del día',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Cada día Ñee puede sumar retos nuevos. Completarlos deja tu cuenta más lista para pedir un servicio.',
                style: TextStyle(color: NeeColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              if (open.isNotEmpty)
                _TodayCard(
                  items: open,
                  onComplete: state.completeChallenge,
                )
              else
                const _AllDoneBanner(),
              if (done.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  'HECHOS HOY',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                for (final challenge in done)
                  _ChallengeRow(challenge: challenge),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NeeColors.chalk,
      borderRadius: BorderRadius.circular(20),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hoy ya cumpliste la ronda',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            SizedBox(height: 6),
            Text(
              'El card del día se oculta cuando no queda nada pendiente. Mañana pueden aparecer desafíos nuevos acá.',
              style: TextStyle(color: NeeColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.items, required this.onComplete});

  final List<DailyChallenge> items;
  final Future<void> Function(String slug) onComplete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NeeColors.vest,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PENDIENTES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: NeeColors.soot.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${items.length} ${items.length == 1 ? 'desafío' : 'desafíos'} por hacer',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: NeeColors.soot,
              ),
            ),
            const SizedBox(height: 10),
            for (final challenge in items)
              _ChallengeRow(
                challenge: challenge,
                onToggle: () => onComplete(challenge.slug),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.challenge, this.onToggle});

  final DailyChallenge challenge;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: challenge.done
            ? NeeColors.chalk
            : NeeColors.chalk.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  challenge.done ? Icons.check_circle : Icons.circle_outlined,
                  color: NeeColors.soot,
                  weight: 200,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          decoration:
                              challenge.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        challenge.description,
                        style: const TextStyle(
                          color: NeeColors.muted,
                          height: 1.3,
                          fontSize: 13,
                        ),
                      ),
                      if (challenge.hint.isNotEmpty)
                        Text(
                          challenge.hint,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
