import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/account_repository.dart';
import '../data/nee_repository.dart';
import '../domain/account.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/nee_sheets.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final identifier = TextEditingController();
  var loading = false;

  @override
  void dispose() {
    identifier.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final value = identifier.text.trim();
    if (value.isEmpty) return;
    setState(() => loading = true);
    final isEmail = value.contains('@');
    if (isEmail) {
      await AccountRepository.resetPasswordEmail(value);
      if (!mounted) return;
      setState(() => loading = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecoverEmailSentScreen(email: value),
        ),
      );
      return;
    }
    widget.state.sendSmsCode();
    if (!mounted) return;
    setState(() => loading = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecoverOtpScreen(
          state: widget.state,
          phone: value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Recupera tu contraseña')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            'Ingresa el teléfono o correo asociado a tu cuenta.',
            style: TextStyle(color: NeeColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: identifier,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Teléfono o email'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: loading ? null : _continue,
            child: Text(loading ? 'Enviando…' : 'Continuar'),
          ),
        ],
      ),
    );
  }
}

class RecoverEmailSentScreen extends StatelessWidget {
  const RecoverEmailSentScreen({super.key, required this.email});

  final String email;

  String get masked {
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return email;
    final name = parts.first;
    final keep = name.length < 2 ? name : name.substring(0, 1);
    return '$keep••••@${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Revisa tu correo')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Si encontramos una cuenta asociada, te enviaremos las instrucciones para continuar.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(masked, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Volver al inicio de sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class RecoverOtpScreen extends StatefulWidget {
  const RecoverOtpScreen({super.key, required this.state, required this.phone});

  final NeeAppState state;
  final String phone;

  @override
  State<RecoverOtpScreen> createState() => _RecoverOtpScreenState();
}

class _RecoverOtpScreenState extends State<RecoverOtpScreen> {
  final code = TextEditingController();
  var seconds = 42;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds <= 0) return;
      setState(() => seconds -= 1);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    super.dispose();
  }

  String get masked {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return widget.phone;
    return '+591 •••• ${digits.substring(digits.length - 4)}';
  }

  Future<void> _verify() async {
    if (!widget.state.verifySms(code.text)) {
      await showErrorSheet(
        context,
        title: 'Código incorrecto',
        body: 'Revisa el código e inténtalo de nuevo.',
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewPasswordScreen(state: widget.state, afterReset: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wait = seconds.toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Te enviamos un código')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Ingresa el código enviado a $masked'),
          const SizedBox(height: 16),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(hintText: '••••••'),
          ),
          Text(seconds > 0 ? 'Reenviar en 00:$wait' : 'Puedes reenviar el código'),
          TextButton(
            onPressed: seconds > 0
                ? null
                : () {
                    widget.state.sendSmsCode();
                    setState(() => seconds = 42);
                  },
            child: const Text('Reenviar código'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cambiar número'),
          ),
          FilledButton(onPressed: _verify, child: const Text('Continuar')),
        ],
      ),
    );
  }
}

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({
    super.key,
    required this.state,
    this.afterReset = false,
    this.requireCurrent = false,
  });

  final NeeAppState state;
  final bool afterReset;
  final bool requireCurrent;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  var obscure = true;
  var loading = false;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strength = PasswordStrength(next.text);
    if (!strength.ok || next.text != confirm.text) return;
    setState(() => loading = true);
    String? error;
    if (widget.requireCurrent) {
      error = await AccountRepository.reauthAndUpdatePassword(
        email: widget.state.user.email,
        current: current.text,
        next: next.text,
      );
    } else {
      error = await AccountRepository.updatePassword(next.text);
    }
    if (!mounted) return;
    setState(() => loading = false);
    if (error != null && !widget.afterReset) {
      await showErrorSheet(context, title: 'No se pudo actualizar', body: error);
      return;
    }
    await showSuccessSheet(
      context,
      title: widget.afterReset ? 'Contraseña actualizada ✓' : 'Contraseña actualizada',
      body: widget.afterReset
          ? 'Ya puedes ingresar nuevamente a tu cuenta.'
          : 'Tu contraseña fue cambiada correctamente.',
    );
    if (!mounted) return;
    if (widget.afterReset) {
      await NeeRepository.signOut();
      widget.state.goTo(OnboardingStep.login);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrength(next.text);
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(
        title: Text(widget.requireCurrent ? 'Cambiar contraseña' : 'Crea una nueva contraseña'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (widget.requireCurrent) ...[
            TextField(
              controller: current,
              obscureText: obscure,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: next,
            obscureText: obscure,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirm,
            obscureText: obscure,
            decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
          ),
          const SizedBox(height: 16),
          _Rule(ok: strength.minLength, label: 'Mínimo 8 caracteres'),
          _Rule(ok: strength.hasLetter, label: 'Una letra'),
          _Rule(ok: strength.hasNumber, label: 'Un número'),
          if (confirm.text.isNotEmpty && confirm.text != next.text)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Las contraseñas no coinciden', style: TextStyle(color: NeeColors.waiting)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: loading || !strength.ok || next.text != confirm.text ? null : _save,
            child: Text(loading ? 'Guardando…' : 'Actualizar contraseña'),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${ok ? '✓' : '○'}  $label',
      style: TextStyle(
        color: ok ? NeeColors.open : NeeColors.muted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return NewPasswordScreen(state: state, requireCurrent: true);
  }
}

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  var stage = 0;

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: Text(stage == 0 ? 'Cambiar número' : 'Verifica tu nuevo número')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (stage == 0) ...[
            const Text('El número actual se mantiene hasta que el nuevo esté verificado.'),
            const SizedBox(height: 16),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nuevo teléfono', prefixText: '+591 '),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                widget.state.sendSmsCode();
                setState(() => stage = 1);
              },
              child: const Text('Enviar código'),
            ),
          ] else ...[
            Text('Ingresa el código enviado a +591 ${phone.text.trim()}'),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            FilledButton(
              onPressed: () async {
                if (!widget.state.verifySms(code.text)) {
                  await showErrorSheet(
                    context,
                    title: 'Código incorrecto',
                    body: 'Revisa el código e inténtalo de nuevo.',
                  );
                  return;
                }
                widget.state.user.phone = phone.text.trim();
                widget.state.user.phoneVerified = true;
                widget.state.notifyAndSave();
                if (!context.mounted) return;
                await showSuccessSheet(
                  context,
                  title: 'Número actualizado ✓',
                  body: 'Tu nuevo teléfono quedó verificado.',
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Verificar'),
            ),
          ],
        ],
      ),
    );
  }
}
