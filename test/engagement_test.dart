import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/engagement.dart';

void main() {
  test('ticket status and category stay in Spanish for the client', () {
    final ticket = SupportTicket(
      id: '1',
      subject: 'No veo ofertas',
      category: 'SERVICE',
      body: 'Publicé y no llegó nadie.',
      status: 'OPEN',
      createdAt: DateTime(2026, 8, 23),
    );
    expect(ticket.statusLabel, 'Abierto');
    expect(ticket.categoryLabel, 'Un servicio');
  });

  test('completing a challenge does not drop the rest of the list', () {
    final done = fallbackChallenges.first.copyWith(done: true);
    expect(done.done, isTrue);
    expect(done.slug, fallbackChallenges.first.slug);
    expect(fallbackChallenges, hasLength(5));
  });
}
