import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat.dart';
import '../models.dart';
import 'nee_supabase.dart';

class ChatRepository {
  static String? get userId =>
      NeeSupabase.ready ? NeeSupabase.client.auth.currentUser?.id : null;

  static Future<ServiceConversation> upsertConversation({
    required ServiceRequest request,
    required ServiceOffer offer,
    required String customerId,
  }) async {
    final local = ServiceConversation(
      id: 'local-${request.id}-${offer.professional.id}',
      requestId: request.remoteId?.toString() ?? request.id,
      offerId: offer.id,
      customerId: customerId,
      professionalId: offer.professional.id,
      professionalName: offer.professional.name,
      professionalInitials: offer.professional.initials,
      requestTitle: request.description,
    );
    if (!NeeSupabase.ready || request.remoteId == null) return local;
    try {
      final existing = await NeeSupabase.client
          .from('service_conversations')
          .select()
          .eq('request_id', '${request.remoteId}')
          .eq('professional_id', offer.professional.id)
          .maybeSingle();
      if (existing != null) {
        return conversationFromRow(
          Map<String, dynamic>.from(existing),
          offer: offer,
          request: request,
        );
      }
      final row = await NeeSupabase.client
          .from('service_conversations')
          .insert({
            'request_id': '${request.remoteId}',
            'offer_id': offer.id,
            'customer_id': customerId,
            'professional_id': offer.professional.id,
            'mode': 'PRE_HIRE',
            'status': 'ACTIVE',
          })
          .select()
          .single();
      return conversationFromRow(row, offer: offer, request: request);
    } catch (error) {
      debugPrint('Ñee: falha ao abrir conversa: $error');
      return local;
    }
  }

  static Future<List<ServiceConversation>> fetchThreads(String customerId) async {
    if (!NeeSupabase.ready) return [];
    try {
      final rows = await NeeSupabase.client
          .from('service_conversations')
          .select()
          .eq('customer_id', customerId)
          .order('updated_at', ascending: false);
      return [
        for (final row in rows) conversationFromRow(Map<String, dynamic>.from(row)),
      ];
    } catch (error) {
      debugPrint('Ñee: falha ao ler conversas: $error');
      return [];
    }
  }

  static Future<ServiceConversation?> fetchConversation(String id) async {
    if (!NeeSupabase.ready || id.startsWith('local-')) return null;
    try {
      final byId = await NeeSupabase.client
          .from('service_conversations')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (byId != null) {
        return conversationFromRow(Map<String, dynamic>.from(byId));
      }
      final byRequest = await NeeSupabase.client
          .from('service_conversations')
          .select()
          .eq('request_id', id)
          .order('updated_at', ascending: false)
          .limit(1);
      if (byRequest.isEmpty) return null;
      return conversationFromRow(Map<String, dynamic>.from(byRequest.first));
    } catch (error) {
      debugPrint('Ñee: falha ao leer conversación: $error');
      return null;
    }
  }

  static Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    if (!NeeSupabase.ready || conversationId.startsWith('local-')) return [];
    try {
      final rows = await NeeSupabase.client
          .from('service_chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('sent_at');
      final messages = [
        for (final row in rows) messageFromRow(Map<String, dynamic>.from(row)),
      ];
      for (final message in messages) {
        await hydrateMedia(message);
      }
      return messages;
    } catch (error) {
      debugPrint('Ñee: falha ao ler mensagens: $error');
      return [];
    }
  }

  static Future<void> hydrateMedia(ChatMessage message) async {
    final path = message.mediaUrl;
    if (path == null || path.isEmpty || path.startsWith('http')) return;
    try {
      final signed = await NeeSupabase.client.storage
          .from('service-chat')
          .createSignedUrl(path, 60 * 60 * 6);
      message.mediaUrl = signed;
    } catch (error) {
      debugPrint('Ñee: falha ao assinar foto: $error');
    }
  }

  static Future<ChatMessage> insertText({
    required ServiceConversation conversation,
    required String text,
    required String clientKey,
  }) async {
    final pending = ChatMessage(
      id: clientKey,
      conversationId: conversation.id,
      senderId: userId,
      senderType: ChatSender.customer,
      type: ChatMessageType.text,
      content: text,
      clientKey: clientKey,
      status: DeliveryStatus.sending,
    );
    if (!conversation.canSend) {
      pending.status = DeliveryStatus.failed;
      return pending;
    }
    if (!NeeSupabase.ready || conversation.id.startsWith('local-')) {
      pending.status = DeliveryStatus.sent;
      return pending;
    }
    try {
      final row = await NeeSupabase.client
          .from('service_chat_messages')
          .insert({
            'conversation_id': conversation.id,
            'sender_id': userId,
            'sender_type': 'CUSTOMER',
            'message_type': 'TEXT',
            'content': text,
            'client_key': clientKey,
            'delivery_status': 'SENT',
          })
          .select()
          .single();
      await NeeSupabase.client.from('service_conversations').update({
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
        'last_message_preview': text,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', conversation.id);
      return messageFromRow(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        final existing = await NeeSupabase.client
            .from('service_chat_messages')
            .select()
            .eq('conversation_id', conversation.id)
            .eq('client_key', clientKey)
            .maybeSingle();
        if (existing != null) return messageFromRow(existing);
      }
      debugPrint('Ñee: falha ao enviar mensagem: $error');
      pending.status = DeliveryStatus.failed;
      return pending;
    } catch (error) {
      debugPrint('Ñee: falha ao enviar mensagem: $error');
      pending.status = DeliveryStatus.failed;
      return pending;
    }
  }

  static Future<ChatMessage> insertImage({
    required ServiceConversation conversation,
    required Uint8List bytes,
    required String clientKey,
  }) async {
    final pending = ChatMessage(
      id: clientKey,
      conversationId: conversation.id,
      senderId: userId,
      senderType: ChatSender.customer,
      type: ChatMessageType.image,
      content: 'Foto',
      clientKey: clientKey,
      status: DeliveryStatus.sending,
      localBytes: bytes,
    );
    if (bytes.length > 5 * 1024 * 1024) {
      pending.status = DeliveryStatus.failed;
      return pending;
    }
    if (!NeeSupabase.ready || conversation.id.startsWith('local-')) {
      pending.status = DeliveryStatus.sent;
      return pending;
    }
    try {
      final path = '${conversation.id}/$userId/$clientKey.jpg';
      await NeeSupabase.client.storage.from('service-chat').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      final row = await NeeSupabase.client
          .from('service_chat_messages')
          .insert({
            'conversation_id': conversation.id,
            'sender_id': userId,
            'sender_type': 'CUSTOMER',
            'message_type': 'IMAGE',
            'content': 'Foto',
            'media_url': path,
            'client_key': clientKey,
            'delivery_status': 'SENT',
          })
          .select()
          .single();
      final saved = messageFromRow(row)..localBytes = bytes;
      await hydrateMedia(saved);
      await NeeSupabase.client.from('service_conversations').update({
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
        'last_message_preview': 'Foto',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', conversation.id);
      return saved;
    } catch (error) {
      debugPrint('Ñee: falha ao enviar foto: $error');
      pending.status = DeliveryStatus.failed;
      return pending;
    }
  }

  static Future<String?> confirmProfessional({
    required int requestId,
    required String offerId,
    required String professionalId,
  }) async {
    if (!NeeSupabase.ready) return null;
    final parsedOffer = int.tryParse(offerId);
    if (parsedOffer == null) return null;
    try {
      final result = await NeeSupabase.client.rpc(
        'select_professional_for_request',
        params: {
          'p_request_id': requestId,
          'p_offer_id': parsedOffer,
          'p_professional_id': professionalId,
        },
      );
      if (result is Map && result['conversation_id'] != null) {
        return '${result['conversation_id']}';
      }
    } catch (error) {
      debugPrint('Ñee: falha ao selecionar profissional: $error');
    }
    return null;
  }

  static Future<void> markRead(String conversationId) async {
    final uid = userId;
    if (!NeeSupabase.ready || uid == null || conversationId.startsWith('local-')) {
      return;
    }
    try {
      await NeeSupabase.client
          .from('service_chat_messages')
          .update({
            'read_at': DateTime.now().toUtc().toIso8601String(),
            'delivery_status': 'READ',
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', uid)
          .isFilter('read_at', null);
    } catch (error) {
      debugPrint('Ñee: falha ao marcar lidas: $error');
    }
  }

  static Future<void> appendSystemEvent({
    required String requestId,
    required String event,
    required String content,
    String? mode,
    String? status,
    String? professionalId,
  }) async {
    if (!NeeSupabase.ready) return;
    try {
      await NeeSupabase.client.rpc(
        'append_service_system_event',
        params: {
          'p_request_id': requestId,
          'p_event': event,
          'p_content': content,
          'p_mode': mode,
          'p_status': status,
          'p_professional_id': professionalId,
        },
      );
    } catch (error) {
      debugPrint('Ñee: falha ao registrar evento: $error');
    }
  }

  static Future<Map<String, int>> unreadCounts(String customerId) async {
    if (!NeeSupabase.ready) return {};
    try {
      final rows = await NeeSupabase.client
          .from('service_chat_messages')
          .select('conversation_id')
          .isFilter('read_at', null)
          .neq('sender_id', customerId);
      final counts = <String, int>{};
      for (final row in rows) {
        final id = '${row['conversation_id']}';
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (error) {
      debugPrint('Ñee: falha ao contar não lidas: $error');
      return {};
    }
  }

  static RealtimeChannel? _live;

  static RealtimeChannel? subscribe({
    required void Function(ChatMessage message) onMessage,
    required void Function(Map<String, dynamic> row) onConversation,
  }) {
    if (!NeeSupabase.ready) return null;
    if (_live != null) return _live;
    _live = NeeSupabase.client
        .channel('service-chat')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'service_chat_messages',
          callback: (payload) {
            onMessage(messageFromRow(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'service_chat_messages',
          callback: (payload) {
            onMessage(messageFromRow(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'service_conversations',
          callback: (payload) {
            onConversation(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'service_conversations',
          callback: (payload) {
            onConversation(payload.newRecord);
          },
        )
        .subscribe();
    return _live;
  }

  static ServiceConversation conversationFromRow(
    Map<String, dynamic> row, {
    ServiceOffer? offer,
    ServiceRequest? request,
  }) {
    return ServiceConversation(
      id: '${row['id']}',
      requestId: '${row['request_id']}',
      offerId: row['offer_id'] as String?,
      customerId: '${row['customer_id']}',
      professionalId: '${row['professional_id']}',
      mode: modeFromApi(row['mode'] as String?),
      status: statusFromApi(
        row['status'] as String?,
        closedReason: row['closed_reason'] as String?,
      ),
      lastMessageAt: DateTime.tryParse('${row['last_message_at'] ?? ''}'),
      lastPreview: row['last_message_preview'] as String? ?? '',
      professionalName: offer?.professional.name ?? '',
      professionalInitials: offer?.professional.initials ?? 'Ñ',
      requestTitle: request?.description ?? '',
    );
  }

  static ChatMessage messageFromRow(Map<String, dynamic> row) {
    final meta = row['metadata'];
    String? event;
    String? audience;
    if (meta is Map && meta['system_event'] is Map) {
      final eventMap = Map<String, dynamic>.from(meta['system_event'] as Map);
      event = '${eventMap['type']}';
      audience = eventMap['audience'] as String?;
    }
    return ChatMessage(
      id: '${row['id']}',
      conversationId: '${row['conversation_id'] ?? ''}'.trim(),
      senderId: row['sender_id'] as String?,
      senderType: senderFromApi(row['sender_type'] as String?),
      type: typeFromApi(row['message_type'] as String?),
      content: row['content'] as String? ?? '',
      mediaUrl: row['media_url'] as String?,
      clientKey: row['client_key'] as String?,
      status: deliveryFromApi(
        row['delivery_status'] as String?,
        readAt: DateTime.tryParse('${row['read_at'] ?? ''}'),
      ),
      sentAt: DateTime.tryParse('${row['sent_at'] ?? ''}') ?? DateTime.now(),
      systemEvent: event,
      audience: audience,
    );
  }
}
