import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/account.dart';

void main() {
  test('password rules stay simple', () {
    expect(const PasswordStrength('abc').ok, isFalse);
    expect(const PasswordStrength('abcdefgh').ok, isFalse);
    expect(const PasswordStrength('clave123').ok, isTrue);
  });

  test('client notification prefs do not include new requests', () {
    final prefs = NotificationPrefs();
    expect(prefs.newOffers, isTrue);
    expect(prefs.requestUpdates, isTrue);
    expect(prefs.toMap('u').containsKey('new_requests'), isFalse);
  });
}
