import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/phone_mask.dart';

void main() {
  test('hides the last four digits', () {
    expect(PhoneMask.display('75596052'), '+591 7559 ••••');
    expect(PhoneMask.display('7096 0805'), '+591 7096 ••••');
    expect(PhoneMask.display('+591 62491452'), '+591 6249 ••••');
  });

  test('whatsapp number keeps country code', () {
    expect(PhoneMask.whatsapp('62491452'), '59162491452');
    expect(PhoneMask.whatsapp('59162491452'), '59162491452');
  });
}
