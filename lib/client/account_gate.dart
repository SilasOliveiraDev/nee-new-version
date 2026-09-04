import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/guest_intent.dart';
import '../models.dart';
import '../screens/onboarding_screen.dart';
import '../theme.dart';

enum _AccountChoice { signup, login }

Future<bool> ensureAccount(
  BuildContext context, {
  required NeeAppState state,
  required GuestIntent intent,
}) async {
  if (!state.isGuest) return true;
  state.setPendingIntent(intent);
  final choice = await _showAccountGateSheet(context);
  if (!context.mounted) return false;
  if (choice == null) {
    state.setPendingIntent(null);
    return false;
  }
  state.goTo(
    choice == _AccountChoice.signup
        ? OnboardingStep.signup
        : OnboardingStep.login,
  );
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => OnboardingScreen(state: state, overlay: true),
    ),
  );
  if (!context.mounted) return false;
  if (state.isGuest) {
    state.setPendingIntent(null);
    return false;
  }
  state.takePendingIntent();
  return true;
}

Future<_AccountChoice?> _showAccountGateSheet(BuildContext context) {
  return showModalBottomSheet<_AccountChoice>(
    context: context,
    backgroundColor: NeeColors.chalk,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Crea tu cuenta para continuar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Puedes ver profesionales sin registrarte. Para solicitar, publicar o escribir, necesitas una cuenta.',
                style: TextStyle(color: NeeColors.muted, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, _AccountChoice.signup),
                child: const Text('Crear cuenta'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, _AccountChoice.login),
                child: const Text('Ya tengo cuenta'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ahora no'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
