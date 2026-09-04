import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nee_supabase.dart';
import 'professional_mapper.dart';

class LiveLocationPin {
  const LiveLocationPin({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.updatedAt,
    this.live = false,
  });

  final double latitude;
  final double longitude;
  final double? heading;
  final DateTime? updatedAt;
  final bool live;
}

class LiveLocationRepository {
  static Future<LiveLocationPin?> load(String professionalId) async {
    if (!NeeSupabase.ready || professionalId.isEmpty) return null;
    try {
      final live = await NeeSupabase.client
          .from('professional_live_locations')
          .select()
          .eq('professional_id', professionalId)
          .maybeSingle();
      if (live != null) {
        final pin = fromRow(Map<String, dynamic>.from(live));
        if (pin != null) return pin;
      }
    } catch (error) {
      debugPrint('Ñee: live location: $error');
    }
    try {
      final row = await NeeSupabase.client
          .from('users')
          .select('latlng')
          .eq('UUID', professionalId)
          .maybeSingle();
      final coords = parseLatLng(row?['latlng']);
      if (coords.lat == null || coords.lng == null) return null;
      return LiveLocationPin(
        latitude: coords.lat!,
        longitude: coords.lng!,
      );
    } catch (error) {
      debugPrint('Ñee: fallback location: $error');
      return null;
    }
  }

  static LiveLocationPin? fromRow(Map<String, dynamic> row) {
    final lat = (row['latitude'] as num?)?.toDouble();
    final lng = (row['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LiveLocationPin(
      latitude: lat,
      longitude: lng,
      heading: (row['heading'] as num?)?.toDouble(),
      updatedAt: DateTime.tryParse('${row['updated_at'] ?? ''}'),
      live: true,
    );
  }

  static RealtimeChannel? subscribe({
    required String professionalId,
    required void Function(LiveLocationPin pin) onUpdate,
  }) {
    if (!NeeSupabase.ready || professionalId.isEmpty) return null;
    return NeeSupabase.client
        .channel(
          'live-loc-$professionalId-${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'professional_live_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'professional_id',
            value: professionalId,
          ),
          callback: (payload) {
            final pin = fromRow(Map<String, dynamic>.from(payload.newRecord));
            if (pin != null) onUpdate(pin);
          },
        )
        .subscribe();
  }
}
