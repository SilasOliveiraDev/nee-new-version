import 'package:flutter/foundation.dart';

import '../domain/engagement.dart';
import 'nee_supabase.dart';

class EngagementRepository {
  static DateTime get todayInLaPaz {
    return DateTime.now().toUtc().subtract(const Duration(hours: 4));
  }

  static String get todayKey {
    final d = todayInLaPaz;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static Future<List<SupportTicket>> loadTickets() async {
    if (!NeeSupabase.ready) return const [];
    final uid = NeeSupabase.client.auth.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await NeeSupabase.client
          .from('support_tickets')
          .select()
          .eq('customer_id', uid)
          .order('created_at', ascending: false);
      return [
        for (final row in rows)
          SupportTicket(
            id: '${row['id']}',
            subject: '${row['subject'] ?? ''}',
            category: '${row['category'] ?? 'GENERAL'}',
            body: '${row['body'] ?? ''}',
            status: '${row['status'] ?? 'OPEN'}',
            createdAt:
                DateTime.tryParse('${row['created_at'] ?? ''}') ?? DateTime.now(),
          ),
      ];
    } catch (error) {
      debugPrint('Ñee: tickets: $error');
      return const [];
    }
  }

  static Future<SupportTicket?> createTicket({
    required String subject,
    required String category,
    required String body,
  }) async {
    if (!NeeSupabase.ready) {
      return SupportTicket(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        subject: subject,
        category: category,
        body: body,
        status: 'OPEN',
        createdAt: DateTime.now(),
      );
    }
    final uid = NeeSupabase.client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await NeeSupabase.client
          .from('support_tickets')
          .insert({
            'customer_id': uid,
            'subject': subject,
            'category': category,
            'body': body,
            'status': 'OPEN',
          })
          .select()
          .single();
      return SupportTicket(
        id: '${row['id']}',
        subject: '${row['subject']}',
        category: '${row['category']}',
        body: '${row['body']}',
        status: '${row['status']}',
        createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now(),
      );
    } catch (error) {
      debugPrint('Ñee: crear ticket: $error');
      return null;
    }
  }

  static Future<List<DailyChallenge>> loadChallenges(String userId) async {
    var catalog = List<DailyChallenge>.from(fallbackChallenges);
    if (NeeSupabase.ready) {
      try {
        final rows = await NeeSupabase.client
            .from('daily_challenges')
            .select()
            .eq('active', true)
            .order('sort_order');
        if (rows.isNotEmpty) {
          catalog = [
            for (final row in rows)
              DailyChallenge(
                slug: '${row['slug']}',
                title: '${row['title']}',
                description: '${row['description'] ?? ''}',
                hint: '${row['hint'] ?? ''}',
                sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
              ),
          ];
        }
      } catch (error) {
        debugPrint('Ñee: desafíos: $error');
      }
    }
    final done = <String>{};
    if (NeeSupabase.ready && userId != 'local-customer') {
      try {
        final rows = await NeeSupabase.client
            .from('daily_challenge_completions')
            .select('challenge_slug')
            .eq('user_id', userId)
            .eq('day', todayKey);
        for (final row in rows) {
          done.add('${row['challenge_slug']}');
        }
      } catch (error) {
        debugPrint('Ñee: desafíos hechos: $error');
      }
    }
    return [
      for (final item in catalog) item.copyWith(done: done.contains(item.slug)),
    ];
  }

  static Future<bool> completeChallenge({
    required String userId,
    required String slug,
  }) async {
    if (!NeeSupabase.ready || userId == 'local-customer') return true;
    try {
      await NeeSupabase.client.from('daily_challenge_completions').upsert(
        {
          'user_id': userId,
          'challenge_slug': slug,
          'day': todayKey,
        },
        onConflict: 'user_id,challenge_slug,day',
      );
      return true;
    } catch (error) {
      debugPrint('Ñee: completar desafío: $error');
      return false;
    }
  }
}
