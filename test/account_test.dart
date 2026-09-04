import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/account.dart';
import 'package:nee/data/users_row.dart';

void main() {
  test('password rules stay simple', () {
    expect(const PasswordStrength('abc').ok, isFalse);
    expect(const PasswordStrength('abcdefgh').ok, isFalse);
    expect(const PasswordStrength('clave123').ok, isTrue);
  });

  test('direct pay copy does not promise in-app checkout', () {
    final pagos = fallbackFaqs.where((f) => f.category == 'Pagos').toList();
    expect(pagos, isNotEmpty);
    expect(pagos.first.answer.toLowerCase(), contains('directo al profesional'));
    expect(pagos.first.answer.toLowerCase(), isNot(contains('llegará más adelante')));
  });

  test('client notification prefs do not include new requests', () {
    final prefs = NotificationPrefs();
    expect(prefs.newOffers, isTrue);
    expect(prefs.requestUpdates, isTrue);
    expect(prefs.toMap('u').containsKey('new_requests'), isFalse);
  });

  test('deleted user row is detected', () {
    expect(UsersRow.isDeleted(null), isFalse);
    expect(UsersRow.isDeleted({'isDeletado': false}), isFalse);
    expect(UsersRow.isDeleted({'isDeletado': true}), isTrue);
  });
}
