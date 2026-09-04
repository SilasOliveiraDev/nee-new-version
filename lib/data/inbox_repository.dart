import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/inbox.dart';
import 'nee_supabase.dart';

class InboxPage {
  const InboxPage({required this.items, required this.hasMore});

  final List<InboxNotice> items;
  final bool hasMore;
}

class InboxRepository {
  static const pageSize = 20;
  static RealtimeChannel? _live;

  static Future<InboxPage> loadPage(
    String userId, {
    int offset = 0,
    NoticeFilter filter = NoticeFilter.all,
  }) async {
    if (!NeeSupabase.ready || userId == 'local-customer') {
      return const InboxPage(items: [], hasMore: false);
    }
    final notices = <InboxNotice>[];
    var hasMore = false;
    try {
      var query = NeeSupabase.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);
      final category = filter.apiCategory;
      if (category != null) {
        query = query.eq('category', category);
      }
      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + pageSize - 1);
      hasMore = rows.length >= pageSize;
      for (final row in rows) {
        notices.add(
          InboxNotice.fromRow(
            Map<String, dynamic>.from(row),
            source: 'notifications',
            id: 'n-${row['id']}',
          ),
        );
      }
    } catch (error) {
      debugPrint('Ñee: notifications: $error');
    }
    if (offset == 0) {
      try {
        final rows = await NeeSupabase.client
            .from('service_inbox')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(40);
        for (final row in rows) {
          final notice = InboxNotice.fromRow(
            Map<String, dynamic>.from(row),
            source: 'inbox',
            id: 'i-${row['id']}',
            fallbackKind: '${row['kind'] ?? 'sistema'}',
            fallbackCta: row['cta'] as String?,
            payloadRelatedId: _payloadId(row['payload']),
          );
          if (!filter.matches(notice)) continue;
          if (notices.any((item) => item.id == notice.id)) continue;
          notices.add(notice);
        }
      } catch (error) {
        debugPrint('Ñee: service_inbox: $error');
      }
    }
    notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return InboxPage(items: _dedupe(notices), hasMore: hasMore);
  }

  static List<InboxNotice> _dedupe(List<InboxNotice> notices) {
    final out = <InboxNotice>[];
    for (final notice in notices) {
      final duplicate = out.any((existing) {
        if (existing.id == notice.id) return true;
        final related = existing.relatedId;
        if (related == null ||
            related.isEmpty ||
            related != notice.relatedId ||
            existing.title != notice.title) {
          return false;
        }
        return existing.createdAt.difference(notice.createdAt).abs() <
            const Duration(minutes: 3);
      });
      if (!duplicate) out.add(notice);
    }
    return out;
  }

  static Future<int> countUnread(String userId) async {
    if (!NeeSupabase.ready || userId == 'local-customer') {
      return 0;
    }
    var total = 0;
    try {
      final rows = await NeeSupabase.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('is_read', false);
      total += rows.length;
    } catch (error) {
      debugPrint('Ñee: unread notifications: $error');
    }
    try {
      final rows = await NeeSupabase.client
          .from('service_inbox')
          .select('id')
          .eq('user_id', userId)
          .isFilter('read_at', null);
      total += rows.length;
    } catch (error) {
      debugPrint('Ñee: unread inbox: $error');
    }
    return total;
  }

  static Object? _notificationsId(String noticeId) {
    final raw =
        noticeId.startsWith('n-') ? noticeId.substring(2) : noticeId;
    final asInt = int.tryParse(raw);
    if (asInt != null) return asInt;
    final asNum = num.tryParse(raw);
    if (asNum != null) return asNum.round();
    if (raw.isEmpty) return null;
    return raw;
  }

  static String? _payloadId(dynamic payload) {
    if (payload is! Map) return null;
    final map = Map<String, dynamic>.from(payload);
    final requestId = map['request_id'];
    if (requestId != null) return '$requestId';
    final conversationId = map['conversation_id'];
    if (conversationId != null) return '$conversationId';
    return null;
  }

  static Future<void> markRead(InboxNotice notice) async {
    if (!NeeSupabase.ready) return;
    try {
      final stamp = DateTime.now().toUtc().toIso8601String();
      if (notice.source == 'notifications') {
        final id = _notificationsId(notice.id);
        if (id == null) return;
        await NeeSupabase.client.from('notifications').update({
          'is_read': true,
          'read_at': stamp,
        }).eq('id', id);
      } else if (notice.source == 'inbox') {
        final id = notice.id.startsWith('i-')
            ? notice.id.substring(2)
            : notice.id;
        await NeeSupabase.client.from('service_inbox').update({
          'read_at': stamp,
        }).eq('id', id);
      }
    } catch (error) {
      debugPrint('Ñee: marcar notificación: $error');
    }
  }

  static Future<void> markAllRead(String userId) async {
    if (!NeeSupabase.ready || userId == 'local-customer') return;
    try {
      await NeeSupabase.client.rpc('mark_my_client_notices_read');
      return;
    } catch (error) {
      debugPrint('Ñee: rpc marcar todas: $error');
    }
    final stamp = DateTime.now().toUtc().toIso8601String();
    try {
      await NeeSupabase.client
          .from('notifications')
          .update({'is_read': true, 'read_at': stamp})
          .eq('user_id', userId)
          .or('is_read.eq.false,is_read.is.null');
    } catch (error) {
      debugPrint('Ñee: marcar todas notifications: $error');
    }
    try {
      await NeeSupabase.client
          .from('service_inbox')
          .update({'read_at': stamp})
          .eq('user_id', userId)
          .isFilter('read_at', null);
    } catch (error) {
      debugPrint('Ñee: marcar todas inbox: $error');
    }
  }

  static RealtimeChannel? subscribe({
    required String userId,
    required void Function(InboxNotice notice) onInsert,
    required void Function(InboxNotice notice) onUpdate,
  }) {
    if (!NeeSupabase.ready || userId == 'local-customer') return null;
    unsubscribe();
    _live = NeeSupabase.client
        .channel('client-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onInsert(
              InboxNotice.fromRow(
                Map<String, dynamic>.from(payload.newRecord),
                source: 'notifications',
                id: 'n-${payload.newRecord['id']}',
              ),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onUpdate(
              InboxNotice.fromRow(
                Map<String, dynamic>.from(payload.newRecord),
                source: 'notifications',
                id: 'n-${payload.newRecord['id']}',
              ),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'service_inbox',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            onUpdate(
              InboxNotice.fromRow(
                Map<String, dynamic>.from(row),
                source: 'inbox',
                id: 'i-${row['id']}',
                fallbackKind: '${row['kind'] ?? 'sistema'}',
                fallbackCta: row['cta'] as String?,
                payloadRelatedId: _payloadId(row['payload']),
              ),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'service_inbox',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            onInsert(
              InboxNotice.fromRow(
                Map<String, dynamic>.from(row),
                source: 'inbox',
                id: 'i-${row['id']}',
                fallbackKind: '${row['kind'] ?? 'sistema'}',
                fallbackCta: row['cta'] as String?,
                payloadRelatedId: _payloadId(row['payload']),
              ),
            );
          },
        )
        .subscribe();
    return _live;
  }

  static Future<void> unsubscribe() async {
    final channel = _live;
    _live = null;
    if (channel == null || !NeeSupabase.ready) return;
    await NeeSupabase.client.removeChannel(channel);
  }
}
