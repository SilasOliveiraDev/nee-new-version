import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/chat.dart';

void main() {
  test('conversation is not a contract before selection', () {
    final thread = ServiceConversation(
      id: 'c1',
      requestId: '1',
      customerId: 'u1',
      professionalId: 'p1',
    );
    expect(thread.mode, ConversationMode.preHire);
    expect(thread.badgeLabel, 'Sobre una propuesta');
    expect(thread.canSend, isTrue);
  });

  test('contact detector ignores prices and times', () {
    expect(looksLikeOffPlatformContact('Puedo ir a las 17:30 por Bs. 120'), isFalse);
    expect(looksLikeOffPlatformContact('El trabajo dura 45 minutos'), isFalse);
  });

  test('contact detector catches WhatsApp, email and +591', () {
    expect(looksLikeOffPlatformContact('escríbeme por WhatsApp'), isTrue);
    expect(looksLikeOffPlatformContact('mi correo es ana@mail.com'), isTrue);
    expect(looksLikeOffPlatformContact('llámame al +591 70000000'), isTrue);
    expect(looksLikeOffPlatformContact('https://wa.me/59170000000'), isTrue);
  });

  test('proposal accepted copy is personalized for the professional', () {
    final copy = proposalAcceptedCopy(
      professionalName: 'María Quispe',
      customerName: 'Carlos Rojas',
      service: 'Electricidad',
    );
    expect(copy, contains('Hola María'));
    expect(copy, contains('Carlos aceptó tu propuesta para Electricidad'));
    final forPro = ChatMessage(
      id: '1',
      conversationId: 'c',
      senderType: ChatSender.system,
      type: ChatMessageType.system,
      audience: 'PROFESSIONAL',
    );
    expect(forPro.visibleFor(asProfessional: true), isTrue);
    expect(forPro.visibleFor(asProfessional: false), isFalse);
  });
}
