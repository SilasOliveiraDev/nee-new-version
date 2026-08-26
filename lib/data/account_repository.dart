import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account.dart';
import 'nee_supabase.dart';

class AccountRepository {
  static Future<NotificationPrefs> loadPrefs(String userId) async {
    if (!NeeSupabase.ready) return NotificationPrefs();
    try {
      final row = await NeeSupabase.client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return NotificationPrefs();
      return NotificationPrefs.fromMap(row);
    } catch (error) {
      debugPrint('Ñee: prefs: $error');
      return NotificationPrefs();
    }
  }

  static Future<void> savePrefs(String userId, NotificationPrefs prefs) async {
    if (!NeeSupabase.ready) return;
    try {
      await NeeSupabase.client
          .from('notification_preferences')
          .upsert(prefs.toMap(userId));
    } catch (error) {
      debugPrint('Ñee: save prefs: $error');
    }
  }

  static Future<List<FaqItem>> loadFaq() async {
    if (!NeeSupabase.ready) return fallbackFaqs;
    try {
      final rows = await NeeSupabase.client
          .from('faq_items')
          .select()
          .eq('published', true)
          .order('sort_order');
      final items = [
        for (final row in rows)
          FaqItem(
            category: '${row['category']}',
            question: '${row['question']}',
            answer: '${row['answer']}',
          ),
      ];
      return items.isEmpty ? fallbackFaqs : items;
    } catch (error) {
      debugPrint('Ñee: faq: $error');
      return fallbackFaqs;
    }
  }

  static Future<({String title, String body, String version})?> loadLegal(
    String slug,
  ) async {
    if (!NeeSupabase.ready) return null;
    try {
      final row = await NeeSupabase.client
          .from('legal_documents')
          .select()
          .eq('slug', slug)
          .maybeSingle();
      if (row == null) return null;
      return (
        title: '${row['title']}',
        body: '${row['body']}',
        version: '${row['version']}',
      );
    } catch (error) {
      debugPrint('Ñee: legal: $error');
      return null;
    }
  }

  static String storagePathFor(String userId) => '$userId/profile.jpg';

  static Future<String?> signedAvatarUrl(String? stored) async {
    if (stored == null || stored.trim().isEmpty) return null;
    if (stored.startsWith('http')) return stored;
    if (!NeeSupabase.ready) return null;
    try {
      return await NeeSupabase.client.storage
          .from('avatars')
          .createSignedUrl(stored.trim(), 60 * 60 * 24 * 7);
    } catch (error) {
      debugPrint('Ñee: avatar url: $error');
      return null;
    }
  }

  static Future<String?> uploadAvatar(String userId, Uint8List bytes) async {
    if (!NeeSupabase.ready) return null;
    if (bytes.length > 5 * 1024 * 1024) return null;
    try {
      final path = storagePathFor(userId);
      await NeeSupabase.client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      await NeeSupabase.client
          .from('users')
          .update({'imagemPerfil': path})
          .eq('UUID', userId);
      return await signedAvatarUrl(path);
    } catch (error) {
      debugPrint('Ñee: avatar: $error');
      return null;
    }
  }

  static Future<void> clearAvatar(String userId) async {
    if (!NeeSupabase.ready) return;
    try {
      await NeeSupabase.client.storage.from('avatars').remove(['$userId/profile.jpg']);
      await NeeSupabase.client
          .from('users')
          .update({'imagemPerfil': null})
          .eq('UUID', userId);
    } catch (error) {
      debugPrint('Ñee: clear avatar: $error');
    }
  }

  static Future<String?> resetPasswordEmail(String email) async {
    if (!NeeSupabase.ready) return null;
    try {
      await NeeSupabase.client.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (error) {
      debugPrint('Ñee: reset: ${error.message}');
      return null;
    } catch (error) {
      debugPrint('Ñee: reset: $error');
      return null;
    }
  }

  static Future<String?> updatePassword(String next) async {
    if (!NeeSupabase.ready) return 'No hay conexión.';
    try {
      await NeeSupabase.client.auth.updateUser(UserAttributes(password: next));
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return '$error';
    }
  }

  static Future<String?> reauthAndUpdatePassword({
    required String email,
    required String current,
    required String next,
  }) async {
    final signInError = await _signIn(email, current);
    if (signInError != null) return 'La contraseña actual no es correcta.';
    return updatePassword(next);
  }

  static Future<String?> _signIn(String email, String password) async {
    if (!NeeSupabase.ready) return null;
    try {
      await NeeSupabase.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return '$error';
    }
  }

  static Future<bool> deleteAccount() async {
    if (!NeeSupabase.ready) return true;
    try {
      await NeeSupabase.client.rpc('delete_my_account');
      await NeeSupabase.client.auth.signOut();
      return true;
    } catch (error) {
      debugPrint('Ñee: delete account: $error');
      return false;
    }
  }
}
