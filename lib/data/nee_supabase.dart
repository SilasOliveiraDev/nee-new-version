import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NeeSupabase {
  static var ready = false;

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zhubjmdpvkvbkbfcxeyh.supabase.co',
  );
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get configured => anonKey.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    if (!configured) {
      debugPrint(
        'Ñee: Supabase sem SUPABASE_ANON_KEY. Rode com '
        '--dart-define-from-file=env.json',
      );
      return;
    }
    await Supabase.initialize(url: url, publishableKey: anonKey);
    ready = true;
  }
}
