class NotificationPrefs {
  NotificationPrefs({
    this.pushEnabled = true,
    this.chatMessages = true,
    this.newOffers = true,
    this.requestUpdates = true,
    this.professionalOnTheWay = true,
    this.serviceStarted = true,
    this.serviceFinished = true,
    this.reminders = true,
    this.marketing = false,
  });

  bool pushEnabled;
  bool chatMessages;
  bool newOffers;
  bool requestUpdates;
  bool professionalOnTheWay;
  bool serviceStarted;
  bool serviceFinished;
  bool reminders;
  bool marketing;

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'push_enabled': pushEnabled,
        'chat_messages': chatMessages,
        'new_offers': newOffers,
        'request_updates': requestUpdates,
        'professional_on_the_way': professionalOnTheWay,
        'service_started': serviceStarted,
        'service_finished': serviceFinished,
        'reminders': reminders,
        'marketing': marketing,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory NotificationPrefs.fromMap(Map<String, dynamic> row) {
    return NotificationPrefs(
      pushEnabled: row['push_enabled'] as bool? ?? true,
      chatMessages: row['chat_messages'] as bool? ?? true,
      newOffers: row['new_offers'] as bool? ?? true,
      requestUpdates: row['request_updates'] as bool? ?? true,
      professionalOnTheWay: row['professional_on_the_way'] as bool? ?? true,
      serviceStarted: row['service_started'] as bool? ?? true,
      serviceFinished: row['service_finished'] as bool? ?? true,
      reminders: row['reminders'] as bool? ?? true,
      marketing: row['marketing'] as bool? ?? false,
    );
  }
}

class PasswordStrength {
  const PasswordStrength(this.value);

  final String value;

  bool get minLength => value.length >= 8;
  bool get hasLetter => RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(value);
  bool get hasNumber => RegExp(r'\d').hasMatch(value);
  bool get ok => minLength && hasLetter && hasNumber;
}

class FaqItem {
  const FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}

const fallbackFaqs = [
  FaqItem(
    category: 'Primeros pasos',
    question: '¿Cómo pido un servicio?',
    answer:
        'Describe lo que necesitas, elige el lugar y publica la solicitud. Los profesionales compatibles pueden enviarte propuestas.',
  ),
  FaqItem(
    category: 'Solicitudes',
    question: '¿Cómo cancelo una solicitud?',
    answer:
        'Abre la solicitud y elige Cancelar. Te pediremos un motivo. La solicitud queda en tu historial, no se elimina.',
  ),
  FaqItem(
    category: 'Solicitudes',
    question: '¿Hablar con un profesional significa contratarlo?',
    answer:
        'No. Puedes preguntar sobre una propuesta. La relación oficial empieza cuando confirmas al profesional.',
  ),
  FaqItem(
    category: 'Profesionales',
    question: '¿Cómo elijo a un profesional?',
    answer:
        'Revisa perfil, calificación y propuesta. Luego confirma. Los demás quedan notificados de forma respetuosa.',
  ),
  FaqItem(
    category: 'Pagos',
    question: '¿Puedo pagar dentro de Ñee?',
    answer:
        'Por ahora coordinas el pago con el profesional. El pago dentro de Ñee llegará más adelante.',
  ),
  FaqItem(
    category: 'Cancelaciones',
    question: '¿Qué pasa si cancelo varias veces?',
    answer:
        'Para proteger a los profesionales, varios cancelamentos seguidos pueden pausar nuevas solicitudes por unos minutos.',
  ),
  FaqItem(
    category: 'Seguridad',
    question: '¿Debo compartir mi WhatsApp?',
    answer:
        'No. Coordina el servicio en el chat de Ñee. Así protegemos tu número y el del profesional.',
  ),
  FaqItem(
    category: 'Cuenta',
    question: '¿Cómo cambio mi contraseña?',
    answer:
        'Ve a Perfil → Seguridad → Cambiar contraseña. Si la olvidaste, usa ¿Olvidaste tu contraseña? en el inicio de sesión.',
  ),
  FaqItem(
    category: 'Notificaciones',
    question: '¿Por qué no recibo avisos?',
    answer:
        'Revisa Perfil → Notificaciones y también el permiso del sistema de tu teléfono. Ñee no puede activar un permiso bloqueado por iOS o Android.',
  ),
];
