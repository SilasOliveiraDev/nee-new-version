class SupportTicket {
  SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.body,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String subject;
  final String category;
  final String body;
  final String status;
  final DateTime createdAt;

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
        return 'En curso';
      case 'RESOLVED':
        return 'Resuelto';
      case 'CLOSED':
        return 'Cerrado';
      default:
        return 'Abierto';
    }
  }

  String get categoryLabel {
    switch (category.toUpperCase()) {
      case 'SERVICE':
        return 'Un servicio';
      case 'ACCOUNT':
        return 'Mi cuenta';
      case 'APP':
        return 'La aplicación';
      case 'PAY':
        return 'Pago';
      default:
        return 'Otro';
    }
  }
}

class DailyChallenge {
  const DailyChallenge({
    required this.slug,
    required this.title,
    required this.description,
    this.hint = '',
    this.sortOrder = 0,
    this.done = false,
  });

  final String slug;
  final String title;
  final String description;
  final String hint;
  final int sortOrder;
  final bool done;

  DailyChallenge copyWith({bool? done}) {
    return DailyChallenge(
      slug: slug,
      title: title,
      description: description,
      hint: hint,
      sortOrder: sortOrder,
      done: done ?? this.done,
    );
  }
}

const fallbackChallenges = [
  DailyChallenge(
    slug: 'foto_perfil',
    title: 'Pon tu cara en Ñee',
    description:
        'Sube o confirma tu foto de perfil para que el profesional te reconozca.',
    hint: 'Perfil → Editar perfil',
    sortOrder: 10,
  ),
  DailyChallenge(
    slug: 'direccion_casa',
    title: 'Deja lista tu dirección',
    description:
        'Guarda casa, trabajo u otro lugar. Así no lo escribes en cada solicitud.',
    hint: 'Perfil → Mis direcciones',
    sortOrder: 20,
  ),
  DailyChallenge(
    slug: 'primera_solicitud',
    title: 'Cuenta qué necesitas',
    description:
        'Publica una solicitud o pide un servicio directo. Pedir no es contratar.',
    hint: 'Inicio → Buscar servicio',
    sortOrder: 30,
  ),
  DailyChallenge(
    slug: 'ver_profesional',
    title: 'Mira a alguien cerca',
    description:
        'Abre el perfil de un profesional destacado y revisa su disponibilidad.',
    hint: 'Inicio → Destacados',
    sortOrder: 40,
  ),
  DailyChallenge(
    slug: 'escribir_soporte',
    title: 'Prueba el soporte',
    description:
        'Si algo no cuadra, abre un ticket. El equipo de Ñee te responde ahí.',
    hint: 'Perfil → Mis tickets',
    sortOrder: 50,
  ),
];
