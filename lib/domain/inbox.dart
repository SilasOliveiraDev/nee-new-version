import 'package:flutter/material.dart';

import '../theme.dart';

enum NoticeCategory { service, message, offer, account, system }

enum NoticeFilter { all, service, message, offer, account }

enum NoticePeriod { today, yesterday, thisWeek, earlier }

enum NoticeAction {
  newOffer,
  newMessage,
  professionalConfirmed,
  professionalOnTheWay,
  professionalArrived,
  serviceStarted,
  serviceFinished,
  serviceCancelled,
  publicationRemoved,
  accountUpdate,
  system,
}

enum NoticeTarget {
  serviceOffer,
  conversation,
  activeService,
  serviceDetail,
  serviceHistory,
  notificationDetail,
}

class InboxNotice {
  InboxNotice({
    required this.id,
    required this.source,
    required this.title,
    required this.body,
    required this.createdAt,
    this.kind = 'sistema',
    this.preview,
    this.contextLabel,
    NoticeCategory? category,
    NoticeAction? action,
    NoticeTarget? target,
    this.read = false,
    this.readAt,
    this.cta,
    this.relatedId,
    this.relatedEntityType,
  })  : category = category ??
            inferNoticeRouting(kind: kind, title: title, body: body).category,
        action = action ??
            inferNoticeRouting(kind: kind, title: title, body: body).action,
        target = target ??
            inferNoticeRouting(kind: kind, title: title, body: body).target;

  final String id;
  final String source;
  final String title;
  final String body;
  final DateTime createdAt;
  final String kind;
  final String? preview;
  final String? contextLabel;
  final NoticeCategory category;
  final NoticeAction action;
  final NoticeTarget target;
  bool read;
  DateTime? readAt;
  final String? cta;
  final String? relatedId;
  final String? relatedEntityType;

  String get kindLabel => category.label;

  String get shortBody {
    final text = (preview ?? body).trim();
    if (text.isEmpty) return '';
    return text.length > 140 ? '${text.substring(0, 137)}…' : text;
  }

  factory InboxNotice.fromRow(
    Map<String, dynamic> row, {
    required String source,
    required String id,
    String? fallbackKind,
    String? fallbackCta,
    String? payloadRelatedId,
  }) {
    final title = '${row['title'] ?? ''}';
    final body = '${row['message'] ?? row['body'] ?? ''}';
    final kind = fallbackKind ?? '${row['type'] ?? row['kind'] ?? 'sistema'}';
    final meta = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    final relatedId =
        payloadRelatedId ??
        row['related_entity_id'] as String? ??
        row['related_id'] as String? ??
        (meta['service_id'] != null ? '${meta['service_id']}' : null) ??
        (meta['request_id'] != null ? '${meta['request_id']}' : null) ??
        (meta['conversation_id'] != null ? '${meta['conversation_id']}' : null);
    final inferred = inferNoticeRouting(kind: kind, title: title, body: body);
    return InboxNotice(
      id: id,
      source: source,
      title: _cleanTitle(title),
      body: body,
      preview: row['preview'] as String?,
      contextLabel: _contextFrom(meta, body),
      kind: kind,
      category: categoryFromApi(row['category'] as String?) ?? inferred.category,
      action: actionFromApi(row['action_type'] as String?) ?? inferred.action,
      target: targetFromApi(row['action_target'] as String?) ?? inferred.target,
      relatedId: relatedId,
      relatedEntityType: row['related_entity_type'] as String?,
      cta: fallbackCta ?? row['cta'] as String?,
      read: row['is_read'] == true || row['read_at'] != null,
      readAt: DateTime.tryParse('${row['read_at'] ?? ''}'),
      createdAt:
          DateTime.tryParse('${row['created_at'] ?? ''}') ?? DateTime.now(),
    );
  }
}

class NoticeVisual {
  const NoticeVisual({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;
}

extension NoticeCategoryX on NoticeCategory {
  String get label {
    switch (this) {
      case NoticeCategory.service:
        return 'Servicio';
      case NoticeCategory.message:
        return 'Mensaje';
      case NoticeCategory.offer:
        return 'Oferta';
      case NoticeCategory.account:
        return 'Cuenta';
      case NoticeCategory.system:
        return 'Ñee';
    }
  }

  String get api {
    switch (this) {
      case NoticeCategory.service:
        return 'SERVICE';
      case NoticeCategory.message:
        return 'MESSAGE';
      case NoticeCategory.offer:
        return 'OFFER';
      case NoticeCategory.account:
        return 'ACCOUNT';
      case NoticeCategory.system:
        return 'SYSTEM';
    }
  }
}

extension NoticeFilterX on NoticeFilter {
  String get label {
    switch (this) {
      case NoticeFilter.all:
        return 'Todas';
      case NoticeFilter.service:
        return 'Servicios';
      case NoticeFilter.message:
        return 'Mensajes';
      case NoticeFilter.offer:
        return 'Ofertas';
      case NoticeFilter.account:
        return 'Cuenta';
    }
  }

  String emptyTitle() {
    switch (this) {
      case NoticeFilter.all:
        return 'Todo al día';
      case NoticeFilter.service:
        return 'No hay notificaciones de servicios';
      case NoticeFilter.message:
        return 'No hay notificaciones de mensajes';
      case NoticeFilter.offer:
        return 'No hay notificaciones de ofertas';
      case NoticeFilter.account:
        return 'No hay notificaciones de cuenta';
    }
  }

  String emptyBody() {
    switch (this) {
      case NoticeFilter.all:
        return 'No tienes nuevas notificaciones por ahora.';
      case NoticeFilter.service:
        return 'Los avances de tus solicitudes aparecerán aquí.';
      case NoticeFilter.message:
        return 'Tus nuevos mensajes aparecerán aquí.';
      case NoticeFilter.offer:
        return 'Cuando un profesional envíe una propuesta, la verás aquí.';
      case NoticeFilter.account:
        return 'Avisos de tu cuenta y publicaciones aparecerán aquí.';
    }
  }

  bool matches(InboxNotice notice) {
    switch (this) {
      case NoticeFilter.all:
        return true;
      case NoticeFilter.service:
        return notice.category == NoticeCategory.service;
      case NoticeFilter.message:
        return notice.category == NoticeCategory.message;
      case NoticeFilter.offer:
        return notice.category == NoticeCategory.offer;
      case NoticeFilter.account:
        return notice.category == NoticeCategory.account;
    }
  }

  String? get apiCategory {
    switch (this) {
      case NoticeFilter.all:
        return null;
      case NoticeFilter.service:
        return 'SERVICE';
      case NoticeFilter.message:
        return 'MESSAGE';
      case NoticeFilter.offer:
        return 'OFFER';
      case NoticeFilter.account:
        return 'ACCOUNT';
    }
  }
}

NoticeCategory? categoryFromApi(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'SERVICE':
      return NoticeCategory.service;
    case 'MESSAGE':
      return NoticeCategory.message;
    case 'OFFER':
      return NoticeCategory.offer;
    case 'ACCOUNT':
      return NoticeCategory.account;
    case 'SYSTEM':
      return NoticeCategory.system;
    default:
      return null;
  }
}

NoticeAction? actionFromApi(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'NEW_OFFER':
      return NoticeAction.newOffer;
    case 'NEW_MESSAGE':
      return NoticeAction.newMessage;
    case 'PROFESSIONAL_CONFIRMED':
      return NoticeAction.professionalConfirmed;
    case 'PROFESSIONAL_ON_THE_WAY':
      return NoticeAction.professionalOnTheWay;
    case 'PROFESSIONAL_ARRIVED':
      return NoticeAction.professionalArrived;
    case 'SERVICE_STARTED':
      return NoticeAction.serviceStarted;
    case 'SERVICE_FINISHED':
      return NoticeAction.serviceFinished;
    case 'SERVICE_CANCELLED':
      return NoticeAction.serviceCancelled;
    case 'PUBLICATION_REMOVED':
      return NoticeAction.publicationRemoved;
    case 'ACCOUNT_UPDATE':
      return NoticeAction.accountUpdate;
    case 'SYSTEM':
      return NoticeAction.system;
    default:
      return null;
  }
}

NoticeTarget? targetFromApi(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'SERVICE_OFFER':
      return NoticeTarget.serviceOffer;
    case 'CONVERSATION':
      return NoticeTarget.conversation;
    case 'ACTIVE_SERVICE':
      return NoticeTarget.activeService;
    case 'SERVICE_DETAIL':
      return NoticeTarget.serviceDetail;
    case 'SERVICE_HISTORY':
      return NoticeTarget.serviceHistory;
    case 'NOTIFICATION_DETAIL':
      return NoticeTarget.notificationDetail;
    default:
      return null;
  }
}

class NoticeRouting {
  const NoticeRouting(this.category, this.action, this.target);
  final NoticeCategory category;
  final NoticeAction action;
  final NoticeTarget target;
}

NoticeRouting inferNoticeRouting({
  required String kind,
  required String title,
  required String body,
}) {
  final blob = '${kind.toLowerCase()} ${title.toLowerCase()} ${body.toLowerCase()}';
  if (blob.contains('publicaci') && blob.contains('elimin')) {
    return const NoticeRouting(
      NoticeCategory.account,
      NoticeAction.publicationRemoved,
      NoticeTarget.notificationDetail,
    );
  }
  if (blob.contains('contraseñ')) {
    return const NoticeRouting(
      NoticeCategory.account,
      NoticeAction.accountUpdate,
      NoticeTarget.notificationDetail,
    );
  }
  if (blob.contains('mensaje') ||
      kind.toLowerCase() == 'chat' ||
      kind.toLowerCase() == 'message') {
    return const NoticeRouting(
      NoticeCategory.message,
      NoticeAction.newMessage,
      NoticeTarget.conversation,
    );
  }
  if (blob.contains('propuesta') ||
      blob.contains('oferta') ||
      kind.toLowerCase() == 'propuesta' ||
      kind.toLowerCase() == 'offer') {
    return const NoticeRouting(
      NoticeCategory.offer,
      NoticeAction.newOffer,
      NoticeTarget.serviceOffer,
    );
  }
  if (blob.contains('camino')) {
    return const NoticeRouting(
      NoticeCategory.service,
      NoticeAction.professionalOnTheWay,
      NoticeTarget.activeService,
    );
  }
  if (blob.contains('lleg')) {
    return const NoticeRouting(
      NoticeCategory.service,
      NoticeAction.professionalArrived,
      NoticeTarget.activeService,
    );
  }
  if (blob.contains('inici')) {
    return const NoticeRouting(
      NoticeCategory.service,
      NoticeAction.serviceStarted,
      NoticeTarget.activeService,
    );
  }
  if (blob.contains('finaliz') || blob.contains('complet')) {
    return const NoticeRouting(
      NoticeCategory.service,
      NoticeAction.serviceFinished,
      NoticeTarget.serviceDetail,
    );
  }
  if (blob.contains('cancel')) {
    return const NoticeRouting(
      NoticeCategory.service,
      NoticeAction.serviceCancelled,
      NoticeTarget.serviceHistory,
    );
  }
  if (blob.contains('confirm') || blob.contains('seleccion')) {
    return const NoticeRouting(
      NoticeCategory.service,
      NoticeAction.professionalConfirmed,
      NoticeTarget.activeService,
    );
  }
  switch (kind.toLowerCase()) {
    case 'servico':
    case 'servicio':
    case 'service':
    case 'direct_accepted':
    case 'direct_request':
    case 'service_confirmed':
    case 'final_proposal':
      return const NoticeRouting(
        NoticeCategory.service,
        NoticeAction.system,
        NoticeTarget.serviceDetail,
      );
    case 'sistema':
    case 'system':
      return const NoticeRouting(
        NoticeCategory.system,
        NoticeAction.system,
        NoticeTarget.notificationDetail,
      );
    default:
      return const NoticeRouting(
        NoticeCategory.system,
        NoticeAction.system,
        NoticeTarget.notificationDetail,
      );
  }
}

NoticeVisual visualFor(InboxNotice notice) {
  switch (notice.action) {
    case NoticeAction.newMessage:
      return const NoticeVisual(
        icon: Icons.chat_bubble_outline_rounded,
        tint: NeeColors.assigned,
      );
    case NoticeAction.newOffer:
      return const NoticeVisual(
        icon: Icons.local_offer_outlined,
        tint: NeeColors.yellowDeep,
      );
    case NoticeAction.professionalOnTheWay:
      return const NoticeVisual(
        icon: Icons.directions_car_outlined,
        tint: NeeColors.waiting,
      );
    case NoticeAction.professionalArrived:
      return const NoticeVisual(
        icon: Icons.place_outlined,
        tint: NeeColors.assigned,
      );
    case NoticeAction.serviceStarted:
      return const NoticeVisual(
        icon: Icons.handyman_outlined,
        tint: NeeColors.assigned,
      );
    case NoticeAction.professionalConfirmed:
    case NoticeAction.serviceFinished:
      return const NoticeVisual(
        icon: Icons.check_circle_outline_rounded,
        tint: NeeColors.open,
      );
    case NoticeAction.serviceCancelled:
      return const NoticeVisual(
        icon: Icons.close_rounded,
        tint: Color(0xFFB42318),
      );
    case NoticeAction.publicationRemoved:
      return const NoticeVisual(
        icon: Icons.block_outlined,
        tint: Color(0xFFB42318),
      );
    case NoticeAction.accountUpdate:
      return const NoticeVisual(
        icon: Icons.lock_outline_rounded,
        tint: NeeColors.soot,
      );
    case NoticeAction.system:
      switch (notice.category) {
        case NoticeCategory.offer:
          return const NoticeVisual(
            icon: Icons.local_offer_outlined,
            tint: NeeColors.yellowDeep,
          );
        case NoticeCategory.service:
          return const NoticeVisual(
            icon: Icons.handyman_outlined,
            tint: NeeColors.assigned,
          );
        default:
          return const NoticeVisual(
            icon: Icons.notifications_none_rounded,
            tint: NeeColors.muted,
          );
      }
  }
}

NoticePeriod periodFor(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  if (day == today) return NoticePeriod.today;
  if (day == today.subtract(const Duration(days: 1))) {
    return NoticePeriod.yesterday;
  }
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  if (!day.isBefore(weekStart)) return NoticePeriod.thisWeek;
  return NoticePeriod.earlier;
}

String periodLabel(NoticePeriod period) {
  switch (period) {
    case NoticePeriod.today:
      return 'Hoy';
    case NoticePeriod.yesterday:
      return 'Ayer';
    case NoticePeriod.thisWeek:
      return 'Esta semana';
    case NoticePeriod.earlier:
      return 'Anteriores';
  }
}

List<(NoticePeriod, List<InboxNotice>)> groupNotices(
  List<InboxNotice> items, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final buckets = <NoticePeriod, List<InboxNotice>>{
    NoticePeriod.today: [],
    NoticePeriod.yesterday: [],
    NoticePeriod.thisWeek: [],
    NoticePeriod.earlier: [],
  };
  for (final item in items) {
    buckets[periodFor(item.createdAt, clock)]!.add(item);
  }
  return [
    for (final period in NoticePeriod.values)
      if (buckets[period]!.isNotEmpty) (period, buckets[period]!),
  ];
}

const _monthsEs = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

const _weekdaysEs = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

String noticeWhenEs(DateTime at, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final local = at.toLocal();
  final delta = clock.difference(local);
  if (delta.inSeconds < 45) return 'Ahora';
  if (delta.inMinutes < 60) return 'Hace ${delta.inMinutes} min';
  if (delta.inHours < 24 && _sameDay(local, clock)) {
    return 'Hace ${delta.inHours} h';
  }
  final yesterday = DateTime(clock.year, clock.month, clock.day)
      .subtract(const Duration(days: 1));
  if (_sameDay(local, yesterday)) {
    return 'Ayer · ${_hhmm(local)}';
  }
  final weekStart = DateTime(clock.year, clock.month, clock.day)
      .subtract(Duration(days: clock.weekday - 1));
  final day = DateTime(local.year, local.month, local.day);
  if (!day.isBefore(weekStart) && local.year == clock.year) {
    return '${_weekdaysEs[local.weekday - 1]} · ${_hhmm(local)}';
  }
  return '${local.day} ${_monthsEs[local.month - 1]} ${local.year}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _hhmm(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

String _cleanTitle(String title) {
  var cleaned = title;
  const marks = ['🛑', '🎉', '💬', '✨', '🎁', '✓', '📍', '🚗', '🔧'];
  for (final mark in marks) {
    cleaned = cleaned.replaceAll(mark, '');
  }
  return cleaned.trim();
}

String? _contextFrom(Map<String, dynamic> meta, String body) {
  for (final key in [
    'service_title',
    'service_name',
    'category',
    'specialty',
    'request_title',
  ]) {
    final value = meta[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  final quoted = RegExp(r'[“"]([^”"]+)[”"]').firstMatch(body);
  if (quoted != null) return quoted.group(1);
  return null;
}

List<InboxNotice> demoInbox({DateTime? now}) {
  final clock = now ?? DateTime.now();
  return [
    InboxNotice(
      id: 'demo-msg',
      source: 'demo',
      title: 'Nuevo mensaje de Carlos',
      body: 'Puedo llegar aproximadamente a las 16:30.',
      preview: '“Puedo llegar a las 16:30.”',
      contextLabel: 'Reparación eléctrica',
      kind: 'chat',
      category: NoticeCategory.message,
      action: NoticeAction.newMessage,
      target: NoticeTarget.conversation,
      createdAt: clock.subtract(const Duration(minutes: 2)),
    ),
    InboxNotice(
      id: 'demo-offer',
      source: 'demo',
      title: 'Nueva oferta recibida',
      body: 'María envió una propuesta para “Limpieza profunda”.',
      contextLabel: 'Limpieza profunda',
      kind: 'propuesta',
      category: NoticeCategory.offer,
      action: NoticeAction.newOffer,
      target: NoticeTarget.serviceOffer,
      createdAt: clock.subtract(const Duration(minutes: 18)),
    ),
    InboxNotice(
      id: 'demo-way',
      source: 'demo',
      title: 'Carlos está en camino',
      body: 'Tu profesional ya se dirige a la ubicación del servicio.',
      contextLabel: 'Reparación eléctrica',
      kind: 'servico',
      category: NoticeCategory.service,
      action: NoticeAction.professionalOnTheWay,
      target: NoticeTarget.activeService,
      read: true,
      readAt: clock.subtract(const Duration(hours: 20)),
      createdAt: clock.subtract(const Duration(hours: 20, minutes: 18)),
    ),
    InboxNotice(
      id: 'demo-pub',
      source: 'demo',
      title: 'Publicación eliminada',
      body:
          'Tu publicación fue eliminada porque no cumple con las normas de Ñee. Si crees que fue un error, puedes contactarnos desde el centro de ayuda.',
      preview: '“Profesora de inglés”',
      contextLabel: 'Profesora de inglés',
      kind: 'sistema',
      category: NoticeCategory.account,
      action: NoticeAction.publicationRemoved,
      target: NoticeTarget.notificationDetail,
      read: true,
      createdAt: DateTime(2025, 10, 20, 11),
    ),
  ];
}
