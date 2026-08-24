import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/hire_repository.dart';
import '../data/nee_supabase.dart';
import '../data/professional_repository.dart';
import '../models.dart';
import '../theme.dart';
import 'direct_hire_flow.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  const ProfessionalProfileScreen({
    super.key,
    required this.state,
    required this.professional,
  });

  final NeeAppState state;
  final Professional professional;

  @override
  State<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  ProfessionalProfileView? _view;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final origin = widget.state.user.currentLocation.hasCoords
        ? widget.state.user.currentLocation
        : widget.state.user.registeredAddress;
    try {
      final loaded = await ProfessionalRepository.loadProfile(
        widget.professional.id,
        originLat: origin.latitude,
        originLng: origin.longitude,
      );
      final status = await HireRepository.statusFor(loaded.professional.id);
      if (!mounted) return;
      setState(() {
        _view = ProfessionalProfileView(
          professional: loaded.professional.withAvailability(status),
          portfolio: loaded.portfolio,
          reviews: loaded.reviews,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Perfil')),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const _ProfileSkeleton();
    }
    if (_error != null || _view == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
        children: [
          const Text(
            'No se pudo cargar este perfil',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          const SizedBox(height: 8),
          const Text(
            'El profesional no está disponible o hubo un problema al consultar Ñee.',
            style: TextStyle(color: NeeColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      );
    }
    final professional = _view!.professional;
    final past = widget.state.requests
        .where(
          (r) =>
              r.professional?.id == professional.id &&
              r.status == RequestStatus.completed,
        )
        .toList();
    final view = professional.availability;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProAvatar(professional: professional, radius: 36),
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
                  if ((professional.categoryName ?? professional.specialty)
                      .isNotEmpty)
                    Text(
                      professional.categoryName ?? professional.specialty,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  const SizedBox(height: 4),
                  Text(professional.ratingLabel),
                  Text(
                    professional.jobsLabel,
                    style: const TextStyle(color: NeeColors.muted),
                  ),
                  if (professional.distanceLabel != null)
                    Text(
                      '📍 ${professional.distanceLabel} de ti',
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
        if ((professional.serviceArea ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            professional.serviceArea!,
            style: const TextStyle(color: NeeColors.muted),
          ),
        ],
        if (past.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '✓ Ya contrataste a ${professional.firstName}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
        if (professional.specialty.isNotEmpty &&
            professional.specialty != professional.categoryName) ...[
          const SizedBox(height: 18),
          const Text(
            'Especialidades',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in professional.specialty.split(RegExp(r'[,/]')))
                if (tag.trim().isNotEmpty)
                  Chip(
                    label: Text(tag.trim()),
                    backgroundColor: NeeColors.yellow.withValues(alpha: 0.45),
                  ),
            ],
          ),
        ],
        if ((professional.bio ?? '').isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Sobre ${professional.firstName}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(professional.bio!, style: const TextStyle(height: 1.4)),
        ],
        const SizedBox(height: 20),
        const Text(
          'Su trabajo',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 10),
        if (_view!.portfolio.isEmpty)
          const Text(
            'Aún no agregó trabajos a su portafolio',
            style: TextStyle(color: NeeColors.muted),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _view!.portfolio.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _view!.portfolio[index];
                return _PortfolioThumb(work: item);
              },
            ),
          ),
        if (_view!.reviews.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text(
            'Opiniones',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(professional.ratingLabel),
          for (final review in _view!.reviews.take(3)) ...[
            const SizedBox(height: 10),
            Text('⭐ ${review.rating.toStringAsFixed(1)}'),
            if (review.comment.isNotEmpty)
              Text(review.comment, style: const TextStyle(height: 1.35)),
          ],
        ],
        const SizedBox(height: 28),
        if (professional.isProvider && professional.isActive)
          FilledButton(
            onPressed: view.acceptingRequests
                ? () => startDirectHire(
                      context,
                      state: widget.state,
                      professional: professional,
                    )
                : null,
            child: Text(
              past.isEmpty ? 'Solicitar servicio' : 'Solicitar nuevamente',
            ),
          ),
      ],
    );
  }
}

class _ProAvatar extends StatelessWidget {
  const _ProAvatar({required this.professional, required this.radius});

  final Professional professional;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = resolvePublicMedia(professional.avatarUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: NeeColors.yellow,
      backgroundImage: url == null ? null : NetworkImage(url),
      child: url == null
          ? Text(
              professional.initials,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.55,
                color: NeeColors.ink,
              ),
            )
          : null,
    );
  }
}

class _PortfolioThumb extends StatelessWidget {
  const _PortfolioThumb({required this.work});

  final PortfolioWork work;

  @override
  Widget build(BuildContext context) {
    final url = resolvePublicMedia(work.url);
    return GestureDetector(
      onTap: url == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _MediaViewer(url: url, video: work.isVideo),
                ),
              );
            },
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF3EBD0),
          borderRadius: BorderRadius.circular(16),
          image: url == null || work.isVideo
              ? null
              : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
        child: work.isVideo
            ? const Icon(Icons.play_circle_fill, size: 36)
            : (url == null ? const Icon(Icons.photo_outlined, size: 36) : null),
      ),
    );
  }
}

class _MediaViewer extends StatelessWidget {
  const _MediaViewer({required this.url, required this.video});

  final String url;
  final bool video;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      backgroundColor: Colors.black,
      body: Center(
        child: video
            ? const Text(
                'Video',
                style: TextStyle(color: Colors.white),
              )
            : InteractiveViewer(child: Image.network(url)),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: NeeColors.soot.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: NeeColors.soot.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(160, 14),
                  const SizedBox(height: 8),
                  bar(110, 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          bar(220, 12),
          const SizedBox(height: 12),
          bar(180, 12),
        ],
      ),
    );
  }
}

String? resolvePublicMedia(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  if (value.startsWith('http')) return value;
  if (!NeeSupabase.ready) return null;
  try {
    return NeeSupabase.client.storage.from('avatars').getPublicUrl(value);
  } catch (_) {
    return null;
  }
}
