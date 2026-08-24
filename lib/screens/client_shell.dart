import 'package:flutter/material.dart';

import '../app_state.dart';
import '../client/air_query.dart';
import '../client/nee_adaptive_nav.dart';
import '../client/nee_category_strip.dart';
import '../client/nee_motion.dart';
import '../client/nee_on_air_tile.dart';
import '../client/nee_status_pill.dart';
import '../domain/chat.dart';
import '../models.dart';
import '../domain/request_lifecycle.dart';
import '../theme.dart';
import '../widgets.dart';
import 'buscar_servicio_flow.dart';
import 'chat_thread_screen.dart';
import 'client_map_screen.dart';
import 'direct_hire_flow.dart';
import 'inbox_screen.dart';
import 'professional_profile_screen.dart';
import 'profile_hub.dart';
import 'status_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key, required this.state});

  final NeeAppState state;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final unread = widget.state.unreadTotal;
        final tabs = [
          const NeeTabSpec(label: 'Inicio', glyph: NeeNavGlyph.home),
          const NeeTabSpec(label: 'Solicitudes', glyph: NeeNavGlyph.list),
          NeeTabSpec(label: 'Mensajes', glyph: NeeNavGlyph.chat, badge: unread),
          const NeeTabSpec(label: 'Perfil', glyph: NeeNavGlyph.person),
        ];
        final pages = [
          ClientHomeScreen(state: widget.state),
          ClientOrdersScreen(state: widget.state),
          ClientMessagesScreen(state: widget.state),
          ClientProfileScreen(state: widget.state),
        ];
        final index = widget.state.clientNavIndex.clamp(0, 3);

        return Scaffold(
          body: IndexedStack(index: index, children: pages),
          floatingActionButton: index == 1
              ? FloatingActionButton(
                  backgroundColor: NeeColors.vest,
                  foregroundColor: NeeColors.soot,
                  onPressed: () {
                    openBuscarServicio(context, state: widget.state);
                  },
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: NeeAdaptiveNav(
            index: index,
            onChange: (value) => widget.state.goClientTab(value),
            tabs: tabs,
          ),
        );
      },
    );
  }
}

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  String query = '';
  int nearbyPage = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => _homeBody(context),
    );
  }

  Widget _homeBody(BuildContext context) {
    final user = widget.state.user;
    final q = query.trim().toLowerCase();
    var nearby = onAirNearby(widget.state.highlightedProfessionals);
    var featured = featuredOnAir(widget.state.highlightedProfessionals);
    if (q.isNotEmpty) {
      bool matches(Professional p) =>
          p.name.toLowerCase().contains(q) ||
          p.specialty.toLowerCase().contains(q) ||
          p.categoryLabel.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
      nearby = nearby.where(matches).toList();
      featured = featured.where(matches).toList();
    }
    final pages = nearbyPageCount(nearby.length);
    final page = pages == 0 ? 0 : nearbyPage.clamp(0, pages - 1);
    final pageItems = nearbyPageOf(nearby, page);
    final ink = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surface,
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 16,
              right: 8,
              bottom: 10,
            ),
            child: Row(
              children: [
                const NeeLogo(height: 36),
                const SizedBox(width: 10),
                Icon(Icons.place_outlined, size: 16, color: ink),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    user.cityLabel,
                    style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InboxScreen(state: widget.state),
                      ),
                    );
                  },
                  icon: Badge(
                    isLabelVisible: widget.state.unreadInboxCount > 0,
                    label: Text(
                      widget.state.unreadInboxCount > 9
                          ? '9+'
                          : '${widget.state.unreadInboxCount}',
                    ),
                    backgroundColor: NeeColors.waiting,
                    child: Icon(Icons.notifications_none_rounded, color: ink),
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.state.goClientTab(3),
                  child: ProfileAvatar(user: user, radius: 16),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: NeeColors.vest,
              onRefresh: widget.state.refreshDirectory,
              child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              children: [
                TextField(
                  onChanged: (value) => setState(() {
                    query = value;
                    nearbyPage = 0;
                  }),
                  decoration: const InputDecoration(
                    hintText: '¿Qué servicio buscas hoy?',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
                _SintoniaCard(
                  name: user.first,
                  onExplore: () => _openRequest(context, null),
                ),
                const SizedBox(height: 22),
                NeeCategoryStrip(
                  categories: widget.state.catalog,
                  onTap: (category) => _openRequest(context, category),
                ),
                const SizedBox(height: 8),
                if (nearby.isNotEmpty) ...[
                Text(
                  'Cerca de ti',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ClientMapScreen(state: widget.state),
                        ),
                      );
                    },
                    child: const Text('Ver mapa'),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.state.directoryError != null)
                  Text(
                    widget.state.directoryError!,
                    style: TextStyle(color: ink.withValues(alpha: 0.62)),
                  ),
                for (final pro in pageItems) ...[
                  NeeOnAirTile(
                    professional: pro,
                    onOpen: () => _openPro(context, pro),
                    onQuote: () => startDirectHire(
                      context,
                      state: widget.state,
                      professional: pro,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (pages > 1) ...[
                  const SizedBox(height: 4),
                  _NearbyPager(
                    page: page,
                    pageCount: pages,
                    total: nearby.length,
                    onPage: (value) => setState(() => nearbyPage = value),
                  ),
                ],
                const SizedBox(height: 10),
                ],
                if (widget.state.directoryError != null && nearby.isEmpty)
                  Text(
                    widget.state.directoryError!,
                    style: TextStyle(color: ink.withValues(alpha: 0.62)),
                  ),
                if (featured.isNotEmpty) ...[
                Text(
                  'Profesionales destacados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: featured.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final pro = featured[i];
                      return NeeFeaturedAirCard(
                        professional: pro,
                        onOpen: () => _openPro(context, pro),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                ],
                FilledButton(
                  onPressed: () => _openRequest(context, null),
                  child: const Text('Buscar servicio'),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRequest(BuildContext context, ServiceCategory? category) {
    return openBuscarServicio(context, state: widget.state, category: category);
  }

  void _openPro(BuildContext context, Professional pro) {
    widget.state.completeChallenge('ver_profesional');
    Navigator.of(context).push(
      NeeTunePage(
        child: ProfessionalProfileScreen(
          state: widget.state,
          professional: pro,
        ),
      ),
    );
  }
}

class _NearbyPager extends StatelessWidget {
  const _NearbyPager({
    required this.page,
    required this.pageCount,
    required this.total,
    required this.onPage,
  });

  final int page;
  final int pageCount;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final canBack = page > 0;
    final canNext = page < pageCount - 1;
    return Row(
      children: [
        IconButton(
          tooltip: 'Anterior',
          onPressed: canBack ? () => onPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            'Página ${page + 1} de $pageCount · $total',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: ink.withValues(alpha: 0.72),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Siguiente',
          onPressed: canNext ? () => onPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _SintoniaCard extends StatelessWidget {
  const _SintoniaCard({required this.name, required this.onExplore});

  final String name;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NeeColors.vest,
        borderRadius: BorderRadius.circular(NeeRadii.dial),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $name',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NeeColors.soot,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Profesionales cerca de ti',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: NeeColors.soot,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onExplore,
                  style: FilledButton.styleFrom(
                    backgroundColor: NeeColors.chalk,
                    foregroundColor: NeeColors.soot,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Buscar servicio'),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.near_me_outlined,
            size: 40,
            weight: 200,
            color: NeeColors.soot,
          ),
        ],
      ),
    );
  }
}

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  String? when;

  bool get history => widget.state.solicitudesHistory;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final items = widget.state.requests.where((r) {
            final done =
                RequestLifecycle.isClosed(r.status) ||
                r.status == RequestStatus.awaitingRating;
            if (history != done) return false;
            final now = DateTime.now();
            if (when == 'hoy') {
              final d = r.createdAt;
              if (d.year != now.year ||
                  d.month != now.month ||
                  d.day != now.day) {
                return false;
              }
            }
            if (when == 'semana' && now.difference(r.createdAt).inDays > 7) {
              return false;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
            children: [
              Text(
                'Solicitudes',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _TabChip(
                    label: 'En cola',
                    selected: !history,
                    onTap: () => widget.state.goClientTab(1, history: false),
                  ),
                  const SizedBox(width: 8),
                  _TabChip(
                    label: 'Historial',
                    selected: history,
                    onTap: () => widget.state.goClientTab(1, history: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Todas',
                      selected: when == null,
                      onTap: () => setState(() => when = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Hoy',
                      selected: when == 'hoy',
                      onTap: () => setState(() => when = 'hoy'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Esta semana',
                      selected: when == 'semana',
                      onTap: () => setState(() => when = 'semana'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                Text(
                  history
                      ? 'Aún no hay solicitudes en el historial. Las finalizadas y canceladas aparecen aquí.'
                      : 'No hay solicitudes en curso. Publica una y empieza a recibir propuestas.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.62),
                  ),
                ),
              for (final request in items) ...[
                _SolicitudCard(request: request, state: widget.state),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: NeeColors.vest,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: NeeColors.soot,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected
          ? NeeColors.vest
          : Theme.of(context).colorScheme.surface,
    );
  }
}

void _openThread(
  BuildContext context,
  NeeAppState state,
  ServiceConversation thread,
) {
  final request = state.requestForThread(thread);
  final offer = state.offerForThread(thread);
  if (request == null) return;
  final fallback = ServiceOffer(
    id: thread.offerId ?? thread.id,
    professional: Professional(
      id: thread.professionalId,
      name: thread.professionalName,
      specialty: request.category.name,
      categoryId: request.category.id,
      city: request.location,
      initials: thread.professionalInitials,
      rating: 0,
      jobs: 0,
    ),
  );
  openServiceChat(
    context,
    state: state,
    request: request,
    offer: offer ?? fallback,
  );
}

class ClientMessagesScreen extends StatelessWidget {
  const ClientMessagesScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final threads = state.threads;
        final active = threads.where((t) => t.canSend).toList();
        final history = threads.where((t) => !t.canSend).toList();
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'Mensajes',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (threads.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Text(
                    'Cuando un profesional envíe una propuesta, puedes escribirle aquí antes de decidir.',
                    style: TextStyle(color: NeeColors.muted, height: 1.4),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [
                      if (active.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Text(
                            'Activos',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      for (final thread in active)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _ThreadTile(
                            thread: thread,
                            onTap: () => _openThread(context, state, thread),
                          ),
                        ),
                      if (history.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
                          child: Text(
                            'Historial',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      for (final thread in history)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _ThreadTile(
                            thread: thread,
                            onTap: () => _openThread(context, state, thread),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.onTap});

  final ServiceConversation thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NeeColors.chalk,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: NeeColors.vest,
                foregroundColor: NeeColors.soot,
                child: Text(
                  thread.professionalInitials,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.professionalName.isEmpty
                                ? 'Profesional'
                                : thread.professionalName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          relativeEs(thread.lastMessageAt),
                          style: const TextStyle(
                            color: NeeColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      thread.requestTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: NeeColors.muted, fontSize: 13),
                    ),
                    Text(
                      thread.lastPreview.isEmpty
                          ? 'Sin mensajes todavía'
                          : thread.lastPreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      thread.badgeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: NeeColors.assigned,
                      ),
                    ),
                  ],
                ),
              ),
              if (thread.unread > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE23D28),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolicitudCard extends StatelessWidget {
  const _SolicitudCard({required this.request, required this.state});

  final ServiceRequest request;
  final NeeAppState state;

  String? get _extra {
    switch (request.status) {
      case RequestStatus.sent:
        return 'Mostrando tu solicitud a profesionales cerca';
      case RequestStatus.professionalFound:
        final n = request.offers.isNotEmpty
            ? request.offers.length
            : request.interestedCount;
        return n == 1
            ? '1 profesional envió una propuesta'
            : '$n profesionales enviaron una propuesta';
      case RequestStatus.accepted:
        return request.professional == null
            ? null
            : '${request.professional!.name}\nConfirmado para la visita';
      case RequestStatus.completed:
        return 'Calificar';
      case RequestStatus.awaitingRating:
        return 'Pendiente de calificación';
      case RequestStatus.onTheWay:
        return request.professional == null
            ? 'En camino'
            : '${request.professional!.name}\nEn camino';
      case RequestStatus.inProgress:
        return 'Servicio en curso';
      case RequestStatus.cancelledByCustomer:
      case RequestStatus.cancelledByProfessional:
        return 'Cancelado';
      case RequestStatus.notCompleted:
        return 'No se pudo realizar';
    }
  }

  String get _cta {
    switch (request.status) {
      case RequestStatus.sent:
        return 'Ver solicitud';
      case RequestStatus.professionalFound:
        return 'Ver ofertas';
      case RequestStatus.completed:
      case RequestStatus.awaitingRating:
        return 'Calificar';
      case RequestStatus.cancelledByCustomer:
      case RequestStatus.cancelledByProfessional:
      case RequestStatus.notCompleted:
        return 'Ver detalles';
      default:
        return 'Ver detalle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final face = Theme.of(context).colorScheme.surface;
    return Material(
      color: face,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeeRadii.tile),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            NeeTunePage(
              child: StatusScreen(state: state, request: request),
            ),
          );
        },
        borderRadius: BorderRadius.circular(NeeRadii.tile),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.description,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              NeeStatusPill(status: request.status, label: request.stageLabel),
              if (_extra != null) ...[
                const SizedBox(height: 8),
                Text(
                  _extra!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.62),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      NeeTunePage(
                        child: StatusScreen(state: state, request: request),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: request.status == RequestStatus.completed
                        ? NeeColors.waiting
                        : NeeColors.vest,
                    foregroundColor: NeeColors.soot,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(_cta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
