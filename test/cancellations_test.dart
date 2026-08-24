import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/cancellation.dart';

void main() {
  test('safety and professional faults do not count toward rapid cancel', () {
    expect(countsTowardRapidCancel(CancelReason.safetyConcern), isFalse);
    expect(
      countsTowardRapidCancel(CancelReason.professionalCouldNotPerform),
      isFalse,
    );
    expect(countsTowardRapidCancel(CancelReason.noLongerNeeded), isTrue);
  });
}
