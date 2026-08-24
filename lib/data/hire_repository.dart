import 'package:flutter/foundation.dart';

import '../domain/availability.dart';
import '../models.dart';
import 'nee_supabase.dart';

class HireResult {
  const HireResult({
    required this.ok,
    this.error,
    this.conversationId,
    this.nextAvailableAt,
    this.status,
  });

  final bool ok;
  final String? error;
  final String? conversationId;
  final DateTime? nextAvailableAt;
  final String? status;

  factory HireResult.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const HireResult(ok: false, error: 'INVALID');
    }
    final map = Map<String, dynamic>.from(raw);
    return HireResult(
      ok: map['ok'] == true,
      error: map['error'] as String?,
      conversationId: map['conversation_id']?.toString(),
      nextAvailableAt: DateTime.tryParse('${map['next_available_at'] ?? ''}'),
      status: map['status'] as String?,
    );
  }
}

class HireRepository {
  static Future<void> applyStatuses(List<Professional> directory) async {
    if (!NeeSupabase.ready || directory.isEmpty) return;
    try {
      final ids = directory.map((p) => p.id).toList();
      final result = await NeeSupabase.client.rpc(
        'professional_statuses',
        params: {'p_ids': ids},
      );
      if (result is! Map) return;
      final payload = Map<String, dynamic>.from(result);
      for (var i = 0; i < directory.length; i++) {
        final raw = payload[directory[i].id];
        if (raw is Map) {
          directory[i] = directory[i].withAvailability(
            AvailabilityView.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
    } catch (error) {
      debugPrint('Ñee: falha ao ler disponibilidade: $error');
    }
  }

  static Future<AvailabilityView> statusFor(String professionalId) async {
    if (!NeeSupabase.ready) {
      return const AvailabilityView(
        status: ProOpsStatus.available,
        acceptingRequests: true,
      );
    }
    try {
      final result = await NeeSupabase.client.rpc(
        'professional_public_status',
        params: {'p_professional_id': professionalId},
      );
      if (result is Map) {
        return AvailabilityView.fromJson(Map<String, dynamic>.from(result));
      }
    } catch (error) {
      debugPrint('Ñee: falha ao ler status público: $error');
    }
    return const AvailabilityView(
      status: ProOpsStatus.available,
      acceptingRequests: true,
    );
  }

  static Future<void> notifyDirect(int requestId) async {
    if (!NeeSupabase.ready) return;
    try {
      await NeeSupabase.client.rpc(
        'notify_direct_request',
        params: {'p_request_id': requestId},
      );
    } catch (error) {
      debugPrint('Ñee: falha ao notificar solicitud directa: $error');
    }
  }

  static Future<HireResult> respond({
    required int requestId,
    required bool accept,
    String? reason,
  }) async {
    if (!NeeSupabase.ready) {
      return HireResult(ok: true, status: accept ? 'NEGOTIATION' : 'DECLINED');
    }
    try {
      final result = await NeeSupabase.client.rpc(
        'respond_direct_request',
        params: {
          'p_request_id': requestId,
          'p_accept': accept,
          'p_reason': reason,
        },
      );
      return HireResult.fromJson(result);
    } catch (error) {
      debugPrint('Ñee: falha ao responder solicitud directa: $error');
      return const HireResult(ok: false, error: 'RPC');
    }
  }

  static Future<HireResult> confirm(int requestId) async {
    if (!NeeSupabase.ready) return const HireResult(ok: true);
    try {
      final result = await NeeSupabase.client.rpc(
        'confirm_direct_service',
        params: {'p_request_id': requestId},
      );
      return HireResult.fromJson(result);
    } catch (error) {
      debugPrint('Ñee: falha ao confirmar servicio: $error');
      return const HireResult(ok: false, error: 'RPC');
    }
  }

  static Future<HireResult> propose({
    required int requestId,
    required DateTime start,
    required DateTime end,
    required double price,
    required int durationMinutes,
  }) async {
    if (!NeeSupabase.ready) return const HireResult(ok: true);
    try {
      final result = await NeeSupabase.client.rpc(
        'propose_direct_terms',
        params: {
          'p_request_id': requestId,
          'p_start': start.toUtc().toIso8601String(),
          'p_end': end.toUtc().toIso8601String(),
          'p_price': price,
          'p_duration_minutes': durationMinutes,
        },
      );
      return HireResult.fromJson(result);
    } catch (error) {
      debugPrint('Ñee: falha ao enviar propuesta: $error');
      return const HireResult(ok: false, error: 'RPC');
    }
  }

  static Future<void> cancelDirect(int requestId) async {
    if (!NeeSupabase.ready) return;
    try {
      await NeeSupabase.client.rpc(
        'cancel_direct_request',
        params: {'p_request_id': requestId},
      );
    } catch (error) {
      debugPrint('Ñee: falha ao cancelar solicitud directa: $error');
    }
  }

  static Future<void> closeConversations({
    required String requestId,
    required String reason,
  }) async {
    if (!NeeSupabase.ready) return;
    try {
      await NeeSupabase.client.rpc(
        'close_service_conversations',
        params: {'p_request_id': requestId, 'p_reason': reason},
      );
    } catch (error) {
      debugPrint('Ñee: falha ao cerrar conversaciones: $error');
    }
  }

  static Future<List<ServiceRequest>> loadIncomingDirect({
    required String professionalId,
    required ServiceRequest Function(Map<String, dynamic>) mapRow,
  }) async {
    if (!NeeSupabase.ready) return const [];
    try {
      final rows = await NeeSupabase.client
          .from('service_requests')
          .select()
          .eq('target_professional_id', professionalId)
          .eq('direct_status', 'PENDING_PROFESSIONAL_RESPONSE')
          .order('created_at', ascending: false);
      return [
        for (final row in rows) mapRow(Map<String, dynamic>.from(row)),
      ];
    } catch (error) {
      debugPrint('Ñee: falha ao ler solicitudes directas: $error');
      return const [];
    }
  }
}
