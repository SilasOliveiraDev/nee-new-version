import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../domain/chat.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/nee_sheets.dart';
import '../client/account_gate.dart';
import '../domain/guest_intent.dart';
import 'direct_confirm_flow.dart';

Future<void> openServiceChat(
  BuildContext context, {
  required NeeAppState state,
  required ServiceRequest request,
  required ServiceOffer offer,
}) async {
  if (state.isGuest) {
    final ok = await ensureAccount(
      context,
      state: state,
      intent: const GuestIntent(kind: GuestIntentKind.chat),
    );
    if (!ok || !context.mounted) return;
  }
  final thread = await state.openConversation(request, offer);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatThreadScreen(
        state: state,
        conversationId: thread.id,
      ),
    ),
  );
  state.viewingConversationId = null;
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.state,
    required this.conversationId,
  });

  final NeeAppState state;
  final String conversationId;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _sync;

  NeeAppState get state => widget.state;

  ServiceConversation? get thread {
    for (final item in state.threads) {
      if (item.id == widget.conversationId) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final current = thread;
    if (current != null) {
      state.markThreadRead(current);
      state.loadMessages(current);
      state.refreshConversation(current.id);
    }
    _sync = Timer.periodic(const Duration(seconds: 4), (_) {
      final open = thread;
      if (open == null) return;
      state.loadMessages(open);
      state.markThreadRead(open);
    });
  }

  @override
  void dispose() {
    _sync?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final current = thread;
    if (text.isEmpty || current == null || !current.canSend) return;
    if (looksLikeOffPlatformContact(text) && mounted) {
      await showInformationSheet(
        context,
        title: 'Mantén tu conversación dentro de Ñee',
        body:
            'Por tu seguridad y la del profesional, recomendamos coordinar el servicio directamente desde la aplicación.',
      );
    }
    _input.clear();
    await state.sendText(current, text);
    _jump();
  }

  Future<void> _photo() async {
    final current = thread;
    if (current == null || !current.canSend) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 72,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (!mounted) return;
      await showInformationSheet(
        context,
        title: 'La foto es muy grande',
        body: 'Elige una imagen de hasta 5 MB.',
      );
      return;
    }
    await state.sendImage(current, bytes);
    _jump();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final current = thread;
        if (current == null) {
          return const Scaffold(body: Center(child: Text('Conversación no encontrada')));
        }
        final request = state.requestForThread(current);
        final messages = state.messagesByConversation[current.id] ?? const <ChatMessage>[];
        final official = current.mode == ConversationMode.activeService;
        return Scaffold(
          backgroundColor: NeeColors.paper,
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.professionalName.isEmpty
                      ? 'Profesional'
                      : current.professionalName,
                ),
                Text(
                  official ? 'Profesional confirmado' : current.badgeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NeeColors.open,
                  ),
                ),
              ],
            ),
            actions: [
              if (request != null)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Ver servicio'),
                ),
            ],
          ),
          body: Column(
            children: [
              _ServiceBanner(thread: current, request: request, official: official),
              if (current.status != ConversationStatus.active)
                _ClosedBanner(status: current.status),
              if (request?.canConfirmDirect == true && current.canSend)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: FilledButton(
                    onPressed: () => startDirectConfirm(
                      context,
                      state: state,
                      request: request!,
                    ),
                    child: const Text('Confirmar profesional'),
                  ),
                ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final visible = messages
                        .where(
                          (m) => m.visibleFor(
                            asProfessional: false,
                          ),
                        )
                        .toList();
                    if (visible.isEmpty) return const _EmptyChat();
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final message = visible[index];
                        if (message.isSystem) {
                          return SystemMessage(
                            event: message.systemEvent,
                            name: current.professionalName,
                            content: message.content,
                          );
                        }
                        return _Bubble(
                          message: message,
                          mine: message.mineAsCustomer(state.customerId),
                          onRetry: () => state.retryMessage(current, message),
                        );
                      },
                    );
                  },
                ),
              ),
              _Composer(
                controller: _input,
                enabled: current.canSend,
                onSend: _send,
                onPhoto: _photo,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceBanner extends StatelessWidget {
  const _ServiceBanner({
    required this.thread,
    required this.request,
    required this.official,
  });

  final ServiceConversation thread;
  final ServiceRequest? request;
  final bool official;

  @override
  Widget build(BuildContext context) {
    final location = official
        ? (request?.serviceLocation?.locationLabel ?? request?.location ?? '')
        : (request?.discoveryLabel ?? 'Ubicación aproximada');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeeColors.chalk,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A3A3328)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request?.description ?? thread.requestTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (request?.schedule != null)
            Text(request!.schedule!.summary),
          const SizedBox(height: 4),
          Text(
            official ? '📍 $location' : '📍 $location',
            style: const TextStyle(color: NeeColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.status});

  final ConversationStatus status;

  @override
  Widget build(BuildContext context) {
    final cancelled = status == ConversationStatus.serviceCancelled ||
        status == ConversationStatus.serviceNotCompleted;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeeColors.chalk,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cancelled ? '🔒 Conversación cerrada' : '🔒 Conversación finalizada',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            cancelled
                ? 'Este servicio fue cancelado y ya no es posible enviar nuevos mensajes.'
                : status == ConversationStatus.closedNotSelected
                    ? 'Seleccionaste a otro profesional para realizar el servicio.'
                    : 'Este servicio ya terminó y la conversación está cerrada.',
            style: const TextStyle(color: NeeColors.muted),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Todavía no hay mensajes',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Puedes escribirle al profesional para aclarar cualquier duda sobre su propuesta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: NeeColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class SystemMessage extends StatelessWidget {
  const SystemMessage({
    super.key,
    required this.event,
    required this.name,
    required this.content,
  });

  final String? event;
  final String name;
  final String content;

  @override
  Widget build(BuildContext context) {
    final first = name.split(' ').first;
    String lead = systemTitle(event);
    if (event == 'PROFESSIONAL_ON_THE_WAY') lead = '🚗 $first está en camino';
    if (event == 'PROFESSIONAL_ARRIVED') lead = '📍 $first llegó';
    if (event == 'SERVICE_STARTED') lead = '🔧 Servicio iniciado';
    if (event == 'SERVICE_FINISHED') lead = '✓ Trabajo finalizado';
    if (event == 'PROPOSAL_ACCEPTED') {
      lead = '¡Tu propuesta fue aceptada! 🎉';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            lead,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: NeeColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content.isEmpty ? systemCopy(event, name: first) : content,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NeeColors.muted, fontSize: 13),
          ),
          if (event == 'SERVICE_FINISHED')
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Calificar servicio'),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.onRetry,
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final time =
        '${message.sentAt.hour.toString().padLeft(2, '0')}:${message.sentAt.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: mine ? NeeColors.vest : NeeColors.chalk,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.type == ChatMessageType.image)
                _Photo(message: message)
              else
                Text(message.content, style: const TextStyle(height: 1.35)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: NeeColors.muted),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.status == DeliveryStatus.sending
                          ? Icons.schedule
                          : message.status == DeliveryStatus.failed
                              ? Icons.error_outline
                              : message.status == DeliveryStatus.read ||
                                    message.status == DeliveryStatus.delivered
                                  ? Icons.done_all
                                  : Icons.done,
                      size: 16,
                      color: message.status == DeliveryStatus.read
                          ? const Color(0xFF1F4E8C)
                          : NeeColors.muted,
                    ),
                  ],
                  if (message.status == DeliveryStatus.failed)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Reintentar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final raw = message.localBytes;
    if (raw != null && raw.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          Uint8List.fromList(raw),
          width: 220,
          height: 160,
          fit: BoxFit.cover,
        ),
      );
    }
    final url = message.mediaUrl;
    if (url != null && url.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(url, width: 220, height: 160, fit: BoxFit.cover),
      );
    }
    if (message.status == DeliveryStatus.sending) {
      return const SizedBox(
        width: 220,
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return const Text('Foto');
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.onPhoto,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: enabled ? onPhoto : null,
              icon: const Icon(Icons.add, weight: 200),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje...',
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send, weight: 200),
            ),
          ],
        ),
      ),
    );
  }
}
