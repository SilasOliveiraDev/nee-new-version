enum GuestIntentKind { hire, buscar, chat, profileEdit, messages, whatsapp }

class GuestIntent {
  const GuestIntent({
    required this.kind,
    this.professionalId,
    this.categoryId,
    this.query = '',
  });

  final GuestIntentKind kind;
  final String? professionalId;
  final String? categoryId;
  final String query;

  factory GuestIntent.hire(String professionalId) => GuestIntent(
        kind: GuestIntentKind.hire,
        professionalId: professionalId,
      );

  factory GuestIntent.buscar({String? categoryId, String query = ''}) =>
      GuestIntent(
        kind: GuestIntentKind.buscar,
        categoryId: categoryId,
        query: query,
      );

  factory GuestIntent.whatsapp(String professionalId) => GuestIntent(
        kind: GuestIntentKind.whatsapp,
        professionalId: professionalId,
      );
}
