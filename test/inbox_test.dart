import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/chat.dart';
import 'package:nee/domain/inbox.dart';
import 'package:nee/models.dart';
import 'package:nee/domain/request_lifecycle.dart';

void main() {
  test('service notices map to a client-facing label', () {
    final notice = InboxNotice(
      id: 'n-1',
      source: 'notifications',
      title: 'Nueva propuesta',
      body: 'Un profesional envió una oferta.',
      kind: 'propuesta',
      createdAt: DateTime(2026, 8, 23, 18),
    );
    expect(notice.kindLabel, 'Oferta');
  });

  test('infers offer and publication routing from titles', () {
    final offer = inferNoticeRouting(
      kind: 'sistema',
      title: '¡Tienes una nueva propuesta!',
      body: '',
    );
    expect(offer.category, NoticeCategory.offer);
    expect(offer.action, NoticeAction.newOffer);
    expect(offer.target, NoticeTarget.serviceOffer);

    final removed = inferNoticeRouting(
      kind: 'sistema',
      title: 'Publicación eliminada',
      body: 'Tu publicación fue eliminada porque no cumple con las normas de Ñee.',
    );
    expect(removed.category, NoticeCategory.account);
    expect(removed.action, NoticeAction.publicationRemoved);
    expect(removed.target, NoticeTarget.notificationDetail);
  });

  test('chat notices open the conversation, not a generic sheet', () {
    final notice = inferNoticeRouting(
      kind: 'chat_message',
      title: 'Nuevo mensaje de Ana',
      body: 'Estoy en camino',
    );
    expect(notice.category, NoticeCategory.message);
    expect(notice.action, NoticeAction.newMessage);
    expect(notice.target, NoticeTarget.conversation);
  });

  test('formats dates without 298 d', () {
    final now = DateTime(2026, 8, 24, 12);
    expect(
      noticeWhenEs(now.subtract(const Duration(minutes: 2)), now: now),
      'Hace 2 min',
    );
    expect(
      noticeWhenEs(DateTime(2026, 8, 23, 16, 42), now: now),
      'Ayer · 16:42',
    );
    expect(
      noticeWhenEs(DateTime(2025, 10, 20, 11), now: now),
      '20 oct 2025',
    );
  });

  test('groups notices by period', () {
    final now = DateTime(2026, 8, 24, 12);
    final groups = groupNotices(
      [
        InboxNotice(
          id: '1',
          source: 'n',
          title: 'Hoy',
          body: '',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        InboxNotice(
          id: '2',
          source: 'n',
          title: 'Ayer',
          body: '',
          createdAt: DateTime(2026, 8, 23, 16, 42),
        ),
        InboxNotice(
          id: '3',
          source: 'n',
          title: 'Vieja',
          body: '',
          createdAt: DateTime(2025, 10, 20),
        ),
      ],
      now: now,
    );
    expect(groups.map((g) => g.$1).toList(), [
      NoticePeriod.today,
      NoticePeriod.yesterday,
      NoticePeriod.earlier,
    ]);
  });

  test('noticeIsReadFromRow accepts postgres and json flags', () {
    expect(noticeIsReadFromRow({'is_read': true}), isTrue);
    expect(noticeIsReadFromRow({'is_read': 1}), isTrue);
    expect(noticeIsReadFromRow({'is_read': 't'}), isTrue);
    expect(noticeIsReadFromRow({'is_read': false}), isFalse);
    expect(
      noticeIsReadFromRow({'is_read': false, 'read_at': '2026-08-29T12:00:00Z'}),
      isTrue,
    );
    expect(noticeIsReadFromRow({'is_read': false, 'read_at': null}), isFalse);
  });

  test('filter empty copy is specific', () {
    expect(NoticeFilter.message.emptyTitle(), contains('mensajes'));
    expect(NoticeFilter.offer.emptyTitle(), contains('ofertas'));
    expect(NoticeFilter.all.emptyTitle(), 'Todo al día');
  });

  test('closed conversation cannot send even if notice is old', () {
    final closed = ServiceConversation(
      id: '123',
      requestId: 'r1',
      customerId: 'c',
      professionalId: 'p',
      status: ConversationStatus.serviceCompleted,
    );
    expect(closed.canSend, isFalse);
  });

  test('cancelled service is historical, not operational', () {
    expect(RequestLifecycle.isClosed(RequestStatus.cancelledByCustomer), isTrue);
    expect(RequestLifecycle.isClosed(RequestStatus.onTheWay), isFalse);
  });
}
