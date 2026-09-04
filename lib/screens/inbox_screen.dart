// THESIS: Central de actividad del oficio, no un buzón plano de backend.
// OWN-WORLD: papel Ñee, acento vest sólo en no leídas y filtro activo, iconos de trazo fino.
// STORY: el cliente ve qué pasó, cuándo y adónde seguir, agrupado por tiempo.
// FIRST VIEWPORT: header + chips + HOY con cards compactos; ••• marca todas leídas.
// FORM: operate / superficie existente Ñee / sin mundo nuevo.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/inbox.dart';
import '../theme.dart';
import 'notification_router.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _scroll = ScrollController();
  var _filter = NoticeFilter.all;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await widget.state.refreshInbox(
        filter: _filter,
        silent: widget.state.inbox.isNotEmpty,
      );
      if (!mounted) return;
      await widget.state.markAllNoticesRead();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels > position.maxScrollExtent - 420) {
      widget.state.loadMoreInbox();
    }
  }

  Future<void> _open(InboxNotice notice) async {
    await widget.state.markNoticeRead(notice);
    if (!mounted) return;
    await NotificationRouter.open(
      context,
      state: widget.state,
      notice: notice,
    );
  }

  Future<void> _applyFilter(NoticeFilter filter) async {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    await widget.state.refreshInbox(filter: filter);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final items = state.inbox.where(_filter.matches).toList();
        final grouped = groupNotices(items);
        return Scaffold(
          backgroundColor: NeeColors.paper,
          appBar: AppBar(
            title: const Text('Notificaciones'),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Más acciones',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  if (value == 'read') state.markAllNoticesRead();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'read',
                    enabled: state.unreadInboxCount > 0,
                    child: const Text('Marcar todas como leídas'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: [
                    for (final filter in NoticeFilter.values) ...[
                      _NoticeFilterChip(
                        label: filter.label,
                        selected: _filter == filter,
                        onTap: () => _applyFilter(filter),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reduce ? 0 : 180),
                  switchInCurve: Curves.easeOutCubic,
                  child: RefreshIndicator(
                    key: ValueKey(_filter),
                    color: NeeColors.soot,
                    onRefresh: () => state.refreshInbox(filter: _filter),
                    child: _body(
                      loading: state.inboxLoading && items.isEmpty,
                      hasAny: state.inbox.isNotEmpty || state.inboxLoading,
                      items: items,
                      grouped: grouped,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _body({
    required bool loading,
    required bool hasAny,
    required List<InboxNotice> items,
    required List<(NoticePeriod, List<InboxNotice>)> grouped,
  }) {
    if (loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          _NoticeSkeleton(),
          SizedBox(height: 10),
          _NoticeSkeleton(),
          SizedBox(height: 10),
          _NoticeSkeleton(),
          SizedBox(height: 10),
          _NoticeSkeleton(),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 56, 28, 32),
        children: [
          _EmptyInbox(
            global: !hasAny || _filter == NoticeFilter.all,
            filter: _filter,
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final (period, notices) = grouped[index];
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  periodLabel(period).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              for (var i = 0; i < notices.length; i++) ...[
                NotificationCard(
                  notice: notices[i],
                  onTap: () => _open(notices[i]),
                ),
                if (i != notices.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NoticeFilterChip extends StatelessWidget {
  const _NoticeFilterChip({
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
      backgroundColor: selected ? NeeColors.vest : NeeColors.chalk,
      side: BorderSide(
        color: selected
            ? NeeColors.vest
            : NeeColors.soot.withValues(alpha: 0.08),
      ),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: NeeColors.soot,
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notice,
    required this.onTap,
  });

  final InboxNotice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = visualFor(notice);
    final unread = !notice.read;
    return Material(
      color: unread
          ? NeeColors.vest.withValues(alpha: 0.16)
          : NeeColors.chalk,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: visual.tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(visual.icon, size: 20, color: visual.tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notice.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 15,
                              height: 1.2,
                              color: NeeColors.soot,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: const BoxDecoration(
                              color: NeeColors.waiting,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notice.shortBody.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notice.shortBody,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NeeColors.soot,
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                    if ((notice.contextLabel ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notice.contextLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NeeColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            noticeWhenEs(notice.createdAt),
                            style: const TextStyle(
                              color: NeeColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: NeeColors.soot.withValues(alpha: 0.35),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeSkeleton extends StatelessWidget {
  const _NoticeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: NeeColors.soot.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeeColors.chalk,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NeeColors.soot.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(180, 12),
                const SizedBox(height: 10),
                bar(240, 10),
                const SizedBox(height: 8),
                bar(120, 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.global, required this.filter});

  final bool global;
  final NoticeFilter filter;

  @override
  Widget build(BuildContext context) {
    final title = global && filter == NoticeFilter.all
        ? 'Todo al día'
        : filter.emptyTitle();
    final body = global && filter == NoticeFilter.all
        ? 'No tienes nuevas notificaciones por ahora.'
        : filter.emptyBody();
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: NeeColors.chalk,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            size: 32,
            color: NeeColors.muted,
          ),
        ),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: NeeColors.muted, height: 1.4),
        ),
        if (global && filter == NoticeFilter.all) ...[
          const SizedBox(height: 8),
          const Text(
            'Cuando haya novedades sobre tus servicios, las verás aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NeeColors.muted, height: 1.4),
          ),
        ],
      ],
    );
  }
}
