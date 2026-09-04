import 'package:flutter_test/flutter_test.dart';
import 'package:nee/app_state.dart';
import 'package:nee/domain/guest_intent.dart';
import 'package:nee/mock_data.dart';
import 'package:nee/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('exploring as guest unlocks the shell without finishing onboarding', () {
    final state = NeeAppState();
    expect(state.needsOnboarding, isTrue);
    expect(state.isGuest, isFalse);
    state.enterAsGuest();
    expect(state.isGuest, isTrue);
    expect(state.guestBrowsing, isTrue);
    expect(state.needsOnboarding, isFalse);
    expect(state.step, isNot(OnboardingStep.done));
  });

  test('hire intent is stored and consumed once', () {
    final state = NeeAppState();
    state.setPendingIntent(GuestIntent.hire('pro-1'));
    expect(state.pendingIntent?.kind, GuestIntentKind.hire);
    expect(state.pendingIntent?.professionalId, 'pro-1');
    final taken = state.takePendingIntent();
    expect(taken?.professionalId, 'pro-1');
    expect(state.pendingIntent, isNull);
  });

  test('finishCustomer clears guest browsing and keeps hire intent to resume', () {
    final state = NeeAppState();
    state.enterAsGuest();
    state.setPendingIntent(GuestIntent.hire('pro-1'));
    state.finishCustomer();
    expect(state.isGuest, isFalse);
    expect(state.guestBrowsing, isFalse);
    expect(state.step, OnboardingStep.done);
    expect(state.pendingIntent?.kind, GuestIntentKind.hire);
    expect(state.pendingIntent?.professionalId, 'pro-1');
  });

  test('createRequest still works in local mode without supabase', () async {
    final state = NeeAppState();
    expect(state.isGuest, isFalse);
    final request = await state.createRequest(
      category: categories.first,
      description: 'Prueba',
      location: 'Santa Cruz',
    );
    expect(request.description, 'Prueba');
  });

  test('guest cannot create a request', () async {
    final state = NeeAppState();
    state.enterAsGuest();
    expect(state.isGuest, isTrue);
    await expectLater(
      state.createRequest(
        category: categories.first,
        description: 'Prueba',
        location: 'Santa Cruz',
      ),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'GUEST'),
      ),
    );
  });

  test('restartOnboarding clears the local user and returns to value', () async {
    final state = NeeAppState();
    state.user
      ..firstName = 'Ana'
      ..email = 'ana@test.com'
      ..supabaseUuid = 'abc';
    state.finishCustomer();
    await state.restartOnboarding();
    expect(state.step, OnboardingStep.value);
    expect(state.user.firstName, isEmpty);
    expect(state.user.email, isEmpty);
    expect(state.user.supabaseUuid, isNull);
  });
}
