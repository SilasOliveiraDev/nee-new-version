import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../data/hire_repository.dart';
import '../data/nee_supabase.dart';
import '../data/professional_repository.dart';
import '../domain/availability.dart';
import '../models.dart';
import '../client/nee_on_air_tile.dart';
import '../theme.dart';
import '../widgets/nee_sheets.dart';
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
  var _openingChat = false;

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
          professional: status.reported
              ? loaded.professional.withAvailability(status)
              : loaded.professional,
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

  Future<void> _openWhatsApp(Professional professional) async {
    if (_openingChat) return;
    if (!professional.verified) {
      await showInformationSheet(
        context,
        title: 'WhatsApp bloqueado',
        body:
            'El teléfono se desbloquea cuando el profesional está verificado. Mientras tanto, puedes solicitar el servicio desde Ñee.',
      );
      return;
    }
    setState(() => _openingChat = true);
    try {
      final number = await ProfessionalRepository.whatsappNumber(
        professional.id,
      );
      if (!mounted) return;
      if (number == null || number.isEmpty) {
        await showErrorSheet(
          context,
          title: 'No se pudo abrir WhatsApp',
          body: 'Este profesional aún no tiene un número disponible.',
        );
        return;
      }
      final uri = Uri.parse('https://wa.me/$number');
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        await showErrorSheet(
          context,
          title: 'No se pudo abrir WhatsApp',
          body: 'Inténtalo de nuevo en un momento.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final professional = _view?.professional;
    final past = professional == null
        ? const <ServiceRequest>[]
        : widget.state.requests
            .where(
              (r) =>
                  r.professional?.id == professional.id &&
                  r.status == RequestStatus.completed,
            )
            .toList();
    final canHire = professional != null &&
        professional.isProvider &&
        professional.isActive &&
        professional.availability.acceptingRequests;

    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Perfil')),
      body: _body(context),
      bottomNavigationBar: professional == null || !canHire
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: FilledButton(
                  onPressed: () => startDirectHire(
                    context,
                    state: widget.state,
                    professional: professional,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        past.isEmpty
                            ? 'Solicitar servicio'
                            : 'Solicitar nuevamente',
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ),
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
    final phone = (professional.phoneMasked ?? '').trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _IdentityCard(professional: professional),
        if (past.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            '✓ Ya contrataste a ${professional.firstName}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 22),
        _SectionTitle(
          icon: Icons.menu_book_outlined,
          label: 'Sobre ${professional.firstName}',
        ),
        const SizedBox(height: 12),
        _AboutCard(
          bio: (professional.bio ?? '').trim(),
          emptyHint: 'Aún no escribió sobre su oficio.',
        ),
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PhoneRow(
            display: phone,
            unlocked: professional.verified,
            busy: _openingChat,
            onTap: () => _openWhatsApp(professional),
          ),
        ],
        if (professional.specialtyIfDifferent != null) ...[
          const SizedBox(height: 18),
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
        const SizedBox(height: 24),
        const _SectionTitle(
          icon: Icons.work_outline,
          label: 'Su trabajo',
        ),
        const SizedBox(height: 12),
        if (_view!.portfolio.isEmpty)
          const _EmptyPortfolio()
        else
          SizedBox(
            height: 112,
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
          const SizedBox(height: 24),
          const _SectionTitle(
            icon: Icons.star_outline,
            label: 'Opiniones',
          ),
          const SizedBox(height: 8),
          if (professional.ratingLabel != null)
            Text(professional.ratingLabel!),
          for (final review in _view!.reviews.take(3)) ...[
            const SizedBox(height: 10),
            Text('⭐ ${review.rating.toStringAsFixed(1)}'),
            if (review.comment.isNotEmpty)
              Text(review.comment, style: const TextStyle(height: 1.35)),
          ],
        ],
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.professional});

  final Professional professional;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: NeeColors.chalk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NeeColors.soot.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProAvatar(professional: professional, radius: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  professional.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    height: 1.2,
                  ),
                ),
                if (professional.categoryLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    professional.categoryLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: NeeColors.muted,
                    ),
                  ),
                ],
                if (professional.areaLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    professional.areaLabel!,
                    style: const TextStyle(color: NeeColors.muted, fontSize: 13),
                  ),
                ],
                if (professional.ratingLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    professional.ratingLabel!,
                    style: const TextStyle(color: NeeColors.muted),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  professional.jobsLabel,
                  style: const TextStyle(color: NeeColors.muted, fontSize: 13),
                ),
                if (professional.verified) ...[
                  const SizedBox(height: 8),
                  const NeeVerifiedBadge(),
                ],
                if (professional.distanceLabel != null)
                  Text(
                    '📍 ${professional.distanceLabel} de ti',
                    style: const TextStyle(color: NeeColors.muted, fontSize: 13),
                  ),
                if (professional.hasReportedAvailability) ...[
                  const SizedBox(height: 10),
                  _AvailabilityPill(view: professional.availability),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.view});

  final AvailabilityView view;

  @override
  Widget build(BuildContext context) {
    final available = view.availableNow;
    final color = available ? NeeColors.open : NeeColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: available ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(NeeRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            view.primaryLabel,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: NeeColors.yellowDeep),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.bio, required this.emptyHint});

  final String bio;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final empty = bio.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        empty ? emptyHint : bio,
        style: TextStyle(
          height: 1.45,
          color: empty ? NeeColors.muted : NeeColors.soot,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.display,
    required this.unlocked,
    required this.busy,
    required this.onTap,
  });

  final String display;
  final bool unlocked;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFBF3E1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NeeColors.vest.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.call_outlined, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  display,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: NeeColors.muted,
                  ),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  unlocked ? Icons.chat_outlined : Icons.lock_outline,
                  size: 18,
                  color: NeeColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPortfolio extends StatelessWidget {
  const _EmptyPortfolio();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: NeeColors.chalk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NeeColors.soot.withValues(alpha: 0.14),
          style: BorderStyle.solid,
        ),
      ),
      child: const Column(
        children: [
          Icon(Icons.photo_library_outlined, size: 28, color: NeeColors.muted),
          SizedBox(height: 10),
          Text(
            'Aún no agregó trabajos a su portafolio',
            textAlign: TextAlign.center,
            style: TextStyle(color: NeeColors.muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
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
    final badge = (radius * 0.42).clamp(14.0, 20.0);
    return SizedBox(
      width: radius * 2 + 4,
      height: radius * 2 + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: NeeColors.yellow,
            backgroundImage: url == null ? null : NetworkImage(url),
            child: url == null
                ? Text(
                    professional.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: radius * 0.5,
                      color: NeeColors.ink,
                    ),
                  )
                : null,
          ),
          if (professional.verified)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: badge,
                height: badge,
                decoration: const BoxDecoration(
                  color: NeeColors.chalk,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified,
                  color: NeeColors.vest,
                  size: badge - 2,
                ),
              ),
            ),
        ],
      ),
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
        width: 132,
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
            ? const Text('Video', style: TextStyle(color: Colors.white))
            : InteractiveViewer(child: Image.network(url)),
      ),
    );
  }
}

class MapProfessionalSheet extends StatefulWidget {
  const MapProfessionalSheet({
    super.key,
    required this.state,
    required this.professional,
  });

  final NeeAppState state;
  final Professional professional;

  @override
  State<MapProfessionalSheet> createState() => _MapProfessionalSheetState();
}

class _MapProfessionalSheetState extends State<MapProfessionalSheet> {
  ProfessionalProfileView? _view;
  var _openingChat = false;

  Professional get _pro => _view?.professional ?? widget.professional;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(MapProfessionalSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.professional.id != widget.professional.id) {
      _view = null;
      _hydrate();
    }
  }

  Future<void> _hydrate() async {
    try {
      final origin = widget.state.user.currentLocation.hasCoords
          ? widget.state.user.currentLocation
          : widget.state.user.registeredAddress;
      final loaded = await ProfessionalRepository.loadProfile(
        widget.professional.id,
        originLat: origin.latitude,
        originLng: origin.longitude,
      );
      if (!mounted) return;
      setState(() => _view = loaded);
    } catch (_) {}
  }

  Future<void> _openWhatsApp() async {
    final professional = _pro;
    if (_openingChat) return;
    if (!professional.verified) {
      await showInformationSheet(
        context,
        title: 'WhatsApp bloqueado',
        body:
            'El teléfono se desbloquea cuando el profesional está verificado. Mientras tanto, puedes solicitar el servicio desde Ñee.',
      );
      return;
    }
    setState(() => _openingChat = true);
    try {
      final number = await ProfessionalRepository.whatsappNumber(
        professional.id,
      );
      if (!mounted) return;
      if (number == null || number.isEmpty) {
        await showErrorSheet(
          context,
          title: 'No se pudo abrir WhatsApp',
          body: 'Este profesional aún no tiene un número disponible.',
        );
        return;
      }
      final uri = Uri.parse('https://wa.me/$number');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final professional = _pro;
    final phone = (professional.phoneMasked ?? '').trim();
    final past = widget.state.requests.where(
      (r) =>
          r.professional?.id == professional.id &&
          r.status == RequestStatus.completed,
    );
    final canHire = professional.isProvider &&
        professional.isActive &&
        professional.availability.acceptingRequests;
    return Material(
      color: NeeColors.paper,
      elevation: 16,
      shadowColor: NeeColors.soot.withValues(alpha: 0.28),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NeeColors.soot.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              children: [
                _IdentityCard(professional: professional),
                if (professional.approximatePinLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    professional.approximatePinLabel!,
                    style: const TextStyle(
                      color: NeeColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _SectionTitle(
                  icon: Icons.menu_book_outlined,
                  label: 'Sobre ${professional.firstName}',
                ),
                const SizedBox(height: 8),
                _AboutCard(
                  bio: (professional.bio ?? '').trim(),
                  emptyHint: 'Aún no escribió sobre su oficio.',
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _PhoneRow(
                    display: phone,
                    unlocked: professional.verified,
                    busy: _openingChat,
                    onTap: _openWhatsApp,
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfessionalProfileScreen(
                            state: widget.state,
                            professional: professional,
                          ),
                        ),
                      );
                    },
                    child: const Text('Ver perfil completo'),
                  ),
                  FilledButton(
                    onPressed: !canHire
                        ? null
                        : () => startDirectHire(
                              context,
                              state: widget.state,
                              professional: professional,
                            ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          past.isEmpty
                              ? 'Solicitar servicio'
                              : 'Solicitar nuevamente',
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: NeeColors.soot.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(180, 16),
                  const SizedBox(height: 8),
                  bar(110, 10),
                  const SizedBox(height: 8),
                  bar(90, 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          bar(140, 14),
          const SizedBox(height: 12),
          bar(double.infinity, 88),
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
