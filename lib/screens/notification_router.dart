import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/chat.dart';
import '../domain/inbox.dart';
import '../domain/request_lifecycle.dart';
import '../models.dart';
import '../theme.dart';
import 'account_screens.dart';
import 'chat_thread_screen.dart';
import 'status_screen.dart';

enum NoticeRouteKind { sheet, status, chat, unavailable }

class NoticeRoute {
  const NoticeRoute._({
    required this.kind,
    this.notice,
    this.request,
    this.conversationId,
    this.showRateCta = false,
  });

  final NoticeRouteKind kind;
  final InboxNotice? notice;
  final ServiceRequest? request;
  final String? conversationId;
  final bool showRateCta;

  factory NoticeRoute.sheet(InboxNotice notice, {bool showRateCta = false}) =>
      NoticeRoute._(
        kind: NoticeRouteKind.sheet,
        notice: notice,
        showRateCta: showRateCta,
      );

  factory NoticeRoute.status(ServiceRequest request) =>
      NoticeRoute._(kind: NoticeRouteKind.status, request: request);

  factory NoticeRoute.chat(String conversationId) => NoticeRoute._(
        kind: NoticeRouteKind.chat,
        conversationId: conversationId,
      );

  factory NoticeRoute.unavailable() =>
      const NoticeRoute._(kind: NoticeRouteKind.unavailable);
}

class NotificationRouter {
  static Future<NoticeRoute> resolve({
    required NeeAppState state,
    required InboxNotice notice,
  }) async {
    if (notice.action == NoticeAction.publicationRemoved ||
        notice.action == NoticeAction.accountUpdate ||
        notice.target == NoticeTarget.notificationDetail) {
      if (notice.action == NoticeAction.newMessage) {
        return _conversationRoute(state, notice);
      }
      if (_needsEntity(notice) && (notice.relatedId ?? '').isNotEmpty) {
        final live = await _liveRequest(state, notice.relatedId);
        if (live == null) return NoticeRoute.unavailable();
        return NoticeRoute.status(live);
      }
      return NoticeRoute.sheet(notice);
    }

    if (notice.action == NoticeAction.newMessage ||
        notice.target == NoticeTarget.conversation) {
      return _conversationRoute(state, notice);
    }

    final relatedId = notice.relatedId;
    if (relatedId == null || relatedId.isEmpty) {
      return NoticeRoute.sheet(notice);
    }

    final request = await _liveRequest(state, relatedId);
    if (request == null) return NoticeRoute.unavailable();

    if (RequestLifecycle.isClosed(request.status) &&
        (request.status == RequestStatus.cancelledByCustomer ||
            request.status == RequestStatus.cancelledByProfessional ||
            request.status == RequestStatus.notCompleted ||
            notice.action == NoticeAction.serviceCancelled ||
            notice.target == NoticeTarget.serviceHistory)) {
      return NoticeRoute.status(request);
    }

    if (notice.action == NoticeAction.serviceFinished &&
        request.status == RequestStatus.awaitingRating) {
      return NoticeRoute.status(request);
    }

    return NoticeRoute.status(request);
  }

  static bool _needsEntity(InboxNotice notice) {
    switch (notice.target) {
      case NoticeTarget.serviceOffer:
      case NoticeTarget.activeService:
      case NoticeTarget.serviceDetail:
      case NoticeTarget.serviceHistory:
        return true;
      case NoticeTarget.conversation:
      case NoticeTarget.notificationDetail:
        return false;
    }
  }

  static Future<NoticeRoute> _conversationRoute(
    NeeAppState state,
    InboxNotice notice,
  ) async {
    var thread = _threadFor(state, notice.relatedId);
    if (thread != null) {
      await state.refreshConversation(thread.id);
      thread = _threadFor(state, notice.relatedId) ?? thread;
      return NoticeRoute.chat(thread.id);
    }
    if ((notice.relatedId ?? '').isNotEmpty) {
      final fetched = await state.ensureConversation(notice.relatedId!);
      if (fetched != null) return NoticeRoute.chat(fetched.id);
    }
    final request = await _liveRequest(state, notice.relatedId);
    if (request != null) return NoticeRoute.status(request);
    return NoticeRoute.unavailable();
  }

  static ServiceConversation? _threadFor(NeeAppState state, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final thread in state.threads) {
      if (thread.id == id || thread.requestId == id) return thread;
    }
    return null;
  }

  static Future<ServiceRequest?> _liveRequest(
    NeeAppState state,
    String? relatedId,
  ) async {
    var request = state.requestByRelatedId(relatedId);
    if (request != null) return request;
    await state.refreshClientRequests();
    return state.requestByRelatedId(relatedId);
  }

  static Future<void> open(
    BuildContext context, {
    required NeeAppState state,
    required InboxNotice notice,
  }) async {
    final route = await resolve(state: state, notice: notice);
    if (!context.mounted) return;
    switch (route.kind) {
      case NoticeRouteKind.status:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                StatusScreen(state: state, request: route.request!),
          ),
        );
        return;
      case NoticeRouteKind.chat:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(
              state: state,
              conversationId: route.conversationId!,
            ),
          ),
        );
        state.viewingConversationId = null;
        return;
      case NoticeRouteKind.unavailable:
        await showNotificationUnavailableSheet(context);
        return;
      case NoticeRouteKind.sheet:
        await showNotificationDetailSheet(
          context,
          state: state,
          notice: notice,
        );
    }
  }
}

Future<void> showNotificationUnavailableSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NeeColors.chalk,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NeeColors.soot.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            const Icon(Icons.info_outline_rounded, size: 32, color: NeeColors.muted),
            const SizedBox(height: 12),
            Text(
              'Esta información ya no está disponible',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'El contenido relacionado con esta notificación ya no está activo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: NeeColors.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showNotificationDetailSheet(
  BuildContext context, {
  required NeeAppState state,
  required InboxNotice notice,
}) {
  final visual = visualFor(notice);
  final help = notice.action == NoticeAction.publicationRemoved;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NeeColors.chalk,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NeeColors.soot.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Ñee',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: visual.tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(visual.icon, color: visual.tint),
            ),
            const SizedBox(height: 14),
            Text(notice.title, style: Theme.of(context).textTheme.headlineMedium),
            if ((notice.contextLabel ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '“${notice.contextLabel}”',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
            const SizedBox(height: 10),
            Text(notice.body, style: const TextStyle(height: 1.45, fontSize: 15)),
            const SizedBox(height: 10),
            Text(
              noticeWhenEs(notice.createdAt),
              style: const TextStyle(color: NeeColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ),
            if (help) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HelpCenterScreen(state: state),
                      ),
                    );
                  },
                  child: const Text('Ir al centro de ayuda'),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
