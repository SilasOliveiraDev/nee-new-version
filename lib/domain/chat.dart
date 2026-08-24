enum ConversationMode { preHire, negotiation, activeService, completed, cancelled }

enum ConversationStatus {
  active,
  closedNotSelected,
  serviceCompleted,
  serviceCancelled,
  serviceNotCompleted,
}

enum ChatSender { customer, professional, system }

enum ChatMessageType { text, image, system }

enum DeliveryStatus { sending, sent, delivered, read, failed }

class ServiceConversation {
  ServiceConversation({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.professionalId,
    this.offerId,
    this.mode = ConversationMode.preHire,
    this.status = ConversationStatus.active,
    this.lastMessageAt,
    this.lastPreview = '',
    this.unread = 0,
    this.professionalName = '',
    this.professionalInitials = 'Ñ',
    this.requestTitle = '',
  });

  final String id;
  final String requestId;
  final String customerId;
  final String professionalId;
  String? offerId;
  ConversationMode mode;
  ConversationStatus status;
  DateTime? lastMessageAt;
  String lastPreview;
  int unread;
  String professionalName;
  String professionalInitials;
  String requestTitle;

  bool get canSend => status == ConversationStatus.active;

  String get badgeLabel {
    switch (status) {
      case ConversationStatus.closedNotSelected:
        return 'Otro profesional elegido';
      case ConversationStatus.serviceCompleted:
        return 'Finalizado';
      case ConversationStatus.serviceCancelled:
        return 'Cancelado';
      case ConversationStatus.serviceNotCompleted:
        return 'No completado';
      case ConversationStatus.active:
        switch (mode) {
          case ConversationMode.preHire:
            return 'Sobre una propuesta';
          case ConversationMode.negotiation:
            return 'Negociación';
          case ConversationMode.activeService:
            return 'Servicio activo';
          case ConversationMode.completed:
            return 'Finalizado';
          case ConversationMode.cancelled:
            return 'Cancelado';
        }
    }
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.type,
    this.senderId,
    this.content = '',
    this.mediaUrl,
    this.clientKey,
    this.status = DeliveryStatus.sent,
    DateTime? sentAt,
    this.systemEvent,
    this.audience,
    this.localBytes,
  }) : sentAt = sentAt ?? DateTime.now();

  final String id;
  final String conversationId;
  final String? senderId;
  final ChatSender senderType;
  final ChatMessageType type;
  String content;
  String? mediaUrl;
  String? clientKey;
  DeliveryStatus status;
  DateTime sentAt;
  String? systemEvent;
  String? audience;
  List<int>? localBytes;

  bool visibleFor({required bool asProfessional}) {
    final who = audience?.toUpperCase();
    if (who == null || who.isEmpty || who == 'ALL') return true;
    if (who == 'PROFESSIONAL') return asProfessional;
    if (who == 'CUSTOMER') return !asProfessional;
    return true;
  }

  bool get isMine => senderType == ChatSender.customer;
  bool get isSystem => senderType == ChatSender.system || type == ChatMessageType.system;
}

bool looksLikeOffPlatformContact(String text) {
  final value = text.toLowerCase();
  if (RegExp(r'\bwhats?app\b').hasMatch(value)) return true;
  if (RegExp(r'wa\.me/').hasMatch(value)) return true;
  if (RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+').hasMatch(value)) return true;
  if (RegExp(r'https?://').hasMatch(value)) return true;
  final compact = value.replaceAll(RegExp(r'[\s().-]'), '');
  if (RegExp(r'(\+591|591)\d{7,8}').hasMatch(compact)) return true;
  final invitesContact = RegExp(
    r'\b(ll[aá]mame|mi celular|mi n[uú]mero|te paso el|escr[ií]beme al)\b',
  ).hasMatch(value);
  if (invitesContact && RegExp(r'\d{7,}').hasMatch(compact)) return true;
  return false;
}

String proposalAcceptedCopy({
  required String professionalName,
  required String customerName,
  required String service,
}) {
  final pro = professionalName.trim().split(RegExp(r'\s+')).first;
  final client = customerName.trim().split(RegExp(r'\s+')).first;
  final work = service.trim().isEmpty ? 'el servicio' : service.trim();
  final hello = pro.isEmpty ? 'Hola' : 'Hola $pro';
  final who = client.isEmpty ? 'El cliente' : client;
  return '$hello, $who aceptó tu propuesta para $work. '
      'Ya pueden coordinar todos los detalles en este chat.';
}

String systemTitle(String? event) {
  switch (event) {
    case 'PROFESSIONAL_SELECTED':
      return 'Profesional seleccionado';
    case 'PROPOSAL_ACCEPTED':
      return '¡Tu propuesta fue aceptada! 🎉';
    case 'DIRECT_REQUEST_ACCEPTED':
      return 'Solicitud aceptada';
    case 'NEGOTIATION_STARTED':
      return 'Negociación';
    case 'FINAL_PROPOSAL_SENT':
      return 'Propuesta final';
    case 'CONVERSATION_CLOSED':
      return 'Conversación cerrada';
    case 'PROFESSIONAL_ON_THE_WAY':
      return 'En camino';
    case 'PROFESSIONAL_ARRIVED':
      return 'Llegó';
    case 'SERVICE_STARTED':
      return 'Servicio iniciado';
    case 'SERVICE_FINISHED':
      return 'Trabajo finalizado';
    case 'SERVICE_CANCELLED':
      return 'Servicio cancelado';
    case 'MATCHING_REOPENED':
      return 'Buscando otro profesional';
    case 'OFFER_RECEIVED':
      return 'Nueva propuesta';
    default:
      return 'Actualización';
  }
}

String relativeEs(DateTime? at) {
  if (at == null) return '';
  final delta = DateTime.now().difference(at);
  if (delta.inMinutes < 1) return 'Ahora';
  if (delta.inMinutes < 60) return '${delta.inMinutes} min';
  if (delta.inHours < 24) return '${delta.inHours} h';
  return '${delta.inDays} d';
}

ConversationMode modeFromApi(String? raw) {
  switch (raw) {
    case 'NEGOTIATION':
      return ConversationMode.negotiation;
    case 'ACTIVE_SERVICE':
      return ConversationMode.activeService;
    case 'COMPLETED':
      return ConversationMode.completed;
    case 'CANCELLED':
      return ConversationMode.cancelled;
    default:
      return ConversationMode.preHire;
  }
}

ConversationStatus statusFromApi(String? raw, {String? closedReason}) {
  switch (raw) {
    case 'CLOSED_NOT_SELECTED':
      return ConversationStatus.closedNotSelected;
    case 'SERVICE_COMPLETED':
      return ConversationStatus.serviceCompleted;
    case 'SERVICE_CANCELLED':
      return ConversationStatus.serviceCancelled;
    case 'SERVICE_NOT_COMPLETED':
      return ConversationStatus.serviceNotCompleted;
    case 'CLOSED':
      if (closedReason == 'SERVICE_CANCELLED') {
        return ConversationStatus.serviceCancelled;
      }
      if (closedReason == 'SERVICE_NOT_COMPLETED') {
        return ConversationStatus.serviceNotCompleted;
      }
      return ConversationStatus.serviceCompleted;
    default:
      return ConversationStatus.active;
  }
}

String apiMode(ConversationMode mode) {
  switch (mode) {
    case ConversationMode.preHire:
      return 'PRE_HIRE';
    case ConversationMode.negotiation:
      return 'NEGOTIATION';
    case ConversationMode.activeService:
      return 'ACTIVE_SERVICE';
    case ConversationMode.completed:
      return 'COMPLETED';
    case ConversationMode.cancelled:
      return 'CANCELLED';
  }
}

ChatSender senderFromApi(String? raw) {
  switch (raw) {
    case 'PROFESSIONAL':
      return ChatSender.professional;
    case 'SYSTEM':
      return ChatSender.system;
    default:
      return ChatSender.customer;
  }
}

ChatMessageType typeFromApi(String? raw) {
  switch (raw) {
    case 'IMAGE':
      return ChatMessageType.image;
    case 'SYSTEM':
      return ChatMessageType.system;
    default:
      return ChatMessageType.text;
  }
}

DeliveryStatus deliveryFromApi(String? raw) {
  switch (raw) {
    case 'SENDING':
      return DeliveryStatus.sending;
    case 'DELIVERED':
      return DeliveryStatus.delivered;
    case 'READ':
      return DeliveryStatus.read;
    case 'FAILED':
      return DeliveryStatus.failed;
    default:
      return DeliveryStatus.sent;
  }
}

String systemCopy(String? event, {String name = 'El profesional'}) {
  switch (event) {
    case 'PROFESSIONAL_SELECTED':
      return 'Has elegido a $name para realizar el servicio.';
    case 'PROPOSAL_ACCEPTED':
      return 'El cliente aceptó tu propuesta. Ya pueden coordinar el servicio en este chat.';
    case 'DIRECT_REQUEST_ACCEPTED':
      return '$name aceptó tu solicitud. Ahora pueden coordinar los detalles.';
    case 'FINAL_PROPOSAL_SENT':
      return '$name está listo para confirmar el servicio.';
    case 'CONVERSATION_CLOSED':
      return 'Esta conversación está cerrada.';
    case 'SERVICE_CONFIRMED':
      return 'Servicio confirmado.';
    case 'PROFESSIONAL_ON_THE_WAY':
      return '$name está en camino. Te avisaremos cuando esté cerca.';
    case 'PROFESSIONAL_ARRIVED':
      return '$name llegó.';
    case 'SERVICE_STARTED':
      return 'El trabajo está en curso.';
    case 'SERVICE_FINISHED':
      return 'Trabajo finalizado. Confirma que todo esté correcto y califica tu experiencia.';
    case 'SERVICE_CANCELLED':
      return 'Este servicio fue cancelado.';
    case 'MATCHING_REOPENED':
      return 'Esta solicitud volvió a buscar otro profesional.';
    case 'OFFER_RECEIVED':
      return 'Nueva propuesta recibida.';
    default:
      return 'Actualización del servicio.';
  }
}
