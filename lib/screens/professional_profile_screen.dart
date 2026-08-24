import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/hire_repository.dart';
import '../domain/availability.dart';
import '../models.dart';
import '../theme.dart';
import 'direct_hire_flow.dart';

class ProfessionalProfileScreen extends StatelessWidget {
  const ProfessionalProfileScreen({
    super.key,
    required this.state,
    required this.professional,
  });

  final NeeAppState state;
  final Professional professional;

  @override
  Widget build(BuildContext context) {
    final past = state.requests
        .where(
          (r) =>
              r.professional?.id == professional.id &&
              r.status == RequestStatus.completed,
        )
        .toList();
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Perfil')),
      body: FutureBuilder<AvailabilityView>(
        future: _status(),
        builder: (context, snap) {
          final view = snap.data ?? professional.availability;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: NeeColors.yellow,
                    child: Text(
                      professional.initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: NeeColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          professional.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          '${professional.specialty}  ·  ⭐ ${professional.rating}',
                        ),
                        Text(
                          '${professional.jobs} trabajos · ${professional.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(color: NeeColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${view.emoji} ${view.primaryLabel}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (view.secondaryLabel.isNotEmpty)
                Text(view.secondaryLabel, style: const TextStyle(color: NeeColors.muted)),
              if (past.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '✓ Ya contrataste a ${professional.firstName}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${past.length} servicio${past.length == 1 ? '' : 's'} realizados contigo',
                ),
                Text(
                  'Último servicio: ${past.first.createdAt.day} ${_month(past.first.createdAt.month)} ${past.first.createdAt.year}',
                  style: const TextStyle(color: NeeColors.muted),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final tag in professional.tags)
                    Chip(
                      label: Text(tag),
                      backgroundColor: NeeColors.yellow.withValues(alpha: 0.45),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Su trabajo',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    _Preview(video: false),
                    _Preview(video: false),
                    _Preview(video: true),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: view.acceptingRequests
                    ? () => startDirectHire(
                          context,
                          state: state,
                          professional: professional.withAvailability(view),
                        )
                    : null,
                child: Text(
                  past.isEmpty
                      ? 'Solicitar servicio'
                      : 'Solicitar nuevamente',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<AvailabilityView> _status() {
    return HireRepository.statusFor(professional.id);
  }

  static String _month(int m) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return months[(m - 1).clamp(0, 11)];
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.video});
  final bool video;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EBD0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(video ? Icons.play_circle_fill : Icons.photo_outlined, size: 36),
    );
  }
}
