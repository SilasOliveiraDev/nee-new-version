import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../client/catalog_query.dart';
import '../client/trade_picker.dart';
import '../data/nee_repository.dart';
import '../data/professional_repository.dart';
import '../location_service.dart';
import '../mock_data.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'password_flow.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.state,
    this.overlay = false,
  });

  final NeeAppState state;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        if (overlay && state.step == OnboardingStep.done) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }
        switch (state.step) {
          case OnboardingStep.splash:
            return overlay
                ? _ValueStep(state: state)
                : _SplashStep(state: state);
          case OnboardingStep.value:
            return _ValueStep(state: state);
          case OnboardingStep.login:
            return _LoginStep(state: state, overlay: overlay);
          case OnboardingStep.signup:
            return _SignUpStep(state: state, overlay: overlay);
          default:
            return _OnboardingBody(state: state);
        }
      },
    );
  }
}

class _SplashStep extends StatefulWidget {
  const _SplashStep({required this.state});
  final NeeAppState state;

  @override
  State<_SplashStep> createState() => _SplashStepState();
}

class _SplashStepState extends State<_SplashStep> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && widget.state.step == OnboardingStep.splash) {
        widget.state.goTo(OnboardingStep.value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: NeeColors.paper,
      body: Center(
        child: NeeSplashMark(logoHeight: 168),
      ),
    );
  }
}

class _ValueStep extends StatelessWidget {
  const _ValueStep({required this.state});
  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: NeeLogo(height: 56),
              ),
              const Spacer(),
              Text(
                'Alguien cerca\npuede resolverlo.',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Encuentra oficios en tu zona. Sin listas infinitas de precio: primero quién está cerca y qué trabajo ya hizo.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: NeeColors.muted,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => state.goTo(OnboardingStep.signup),
                child: const Text('Crear cuenta'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => state.goTo(OnboardingStep.login),
                child: const Text('Iniciar sesión'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: state.enterAsGuest,
                child: const Text('Explorar sin cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginStep extends StatefulWidget {
  const _LoginStep({required this.state, this.overlay = false});
  final NeeAppState state;
  final bool overlay;

  @override
  State<_LoginStep> createState() => _LoginStepState();
}

class _LoginStepState extends State<_LoginStep> {
  late final email = TextEditingController(text: widget.state.user.email);
  final password = TextEditingController();
  var loading = false;
  var obscure = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mail = email.text.trim();
    final pass = password.text;
    if (!mail.contains('@')) {
      setState(() {
        error = 'Entra con tu correo, o recupera la contraseña con tu teléfono.';
      });
      return;
    }
    if (pass.length < 6) {
      setState(() => error = 'Correo y contraseña de al menos 6 caracteres.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    widget.state.user.email = mail;
    final message = await NeeRepository.signIn(email: mail, password: pass);
    if (!mounted) return;
    if (message != null) {
      setState(() {
        loading = false;
        error = message;
      });
      return;
    }
    await widget.state.enterAfterLogin();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.overlay && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }
            widget.state.goTo(OnboardingStep.value);
          },
        ),
        title: const NeeLogo(height: 34),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const NeeHeader(
            title: 'Qué bueno verte de nuevo.',
            subtitle: 'Entra con tu teléfono o email.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Teléfono o email',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              hintText: 'Contraseña',
              errorText: error,
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecoverPasswordScreen(state: widget.state),
                  ),
                );
              },
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: loading ? null : _submit,
            child: Text(loading ? 'Entrando…' : 'Iniciar sesión'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => widget.state.goTo(OnboardingStep.signup),
            child: const Text('¿No tienes una cuenta? Crear cuenta'),
          ),
        ],
      ),
    );
  }
}

class _SignUpStep extends StatefulWidget {
  const _SignUpStep({required this.state, this.overlay = false});
  final NeeAppState state;
  final bool overlay;

  @override
  State<_SignUpStep> createState() => _SignUpStepState();
}

class _SignUpStepState extends State<_SignUpStep> {
  late final email = TextEditingController(text: widget.state.user.email);
  final password = TextEditingController();
  final confirm = TextEditingController();
  var loading = false;
  var obscure = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mail = email.text.trim();
    final pass = password.text;
    if (!mail.contains('@') || pass.length < 6) {
      setState(() => error = 'Correo y contraseña de al menos 6 caracteres.');
      return;
    }
    if (pass != confirm.text) {
      setState(() => error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    widget.state.user.email = mail;
    final message = await NeeRepository.signUp(email: mail, password: pass);
    if (!mounted) return;
    if (message != null) {
      setState(() {
        loading = false;
        error = message;
      });
      return;
    }
    widget.state.goTo(OnboardingStep.geo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.overlay && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }
            widget.state.goTo(OnboardingStep.value);
          },
        ),
        title: const NeeLogo(height: 34),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const NeeHeader(
            title: 'Crea tu cuenta',
            subtitle: 'Usa un correo y una contraseña. Luego completamos tu perfil.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(hintText: 'correo@email.com'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(hintText: 'Contraseña (mín. 6)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirm,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: 'Repite la contraseña',
              errorText: error,
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: loading ? null : _submit,
            child: Text(loading ? 'Creando…' : 'Crear cuenta'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => widget.state.goTo(OnboardingStep.login),
            child: const Text('Ya tengo cuenta'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBody extends StatelessWidget {
  const _OnboardingBody({required this.state});
  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    final steps = _visibleSteps();
    final index = steps.indexOf(state.step).clamp(0, steps.length - 1);
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(state),
        ),
        title: const NeeLogo(height: 34),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PASO ${index + 1} / ${steps.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (index + 1) / steps.length,
                    minHeight: 6,
                    color: NeeColors.vest,
                    backgroundColor: const Color(0xFFD8D2C4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _stepView(state)),
        ],
      ),
    );
  }
}

List<OnboardingStep> _visibleSteps() {
  return const [
    OnboardingStep.geo,
    OnboardingStep.address,
    OnboardingStep.phone,
    OnboardingStep.otp,
    OnboardingStep.profile,
    OnboardingStep.photo,
    OnboardingStep.customerPrefs,
    OnboardingStep.customerReady,
  ];
}

void _back(NeeAppState state) {
  const order = [
    OnboardingStep.geo,
    OnboardingStep.address,
    OnboardingStep.phone,
    OnboardingStep.otp,
    OnboardingStep.profile,
    OnboardingStep.photo,
    OnboardingStep.customerPrefs,
    OnboardingStep.customerReady,
  ];
  final i = order.indexOf(state.step);
  if (i <= 0) {
    state.goTo(OnboardingStep.value);
    return;
  }
  state.goTo(order[i - 1]);
}

Widget _stepView(NeeAppState state) {
  switch (state.step) {
    case OnboardingStep.login:
    case OnboardingStep.signup:
      return const SizedBox.shrink();
    case OnboardingStep.geo:
      return _GeoStep(state: state);
    case OnboardingStep.address:
      return _AddressStep(state: state);
    case OnboardingStep.phone:
      return _PhoneStep(state: state);
    case OnboardingStep.otp:
      return _OtpStep(state: state);
    case OnboardingStep.profile:
      return _ProfileStep(state: state);
    case OnboardingStep.photo:
      return _PhotoStep(state: state);
    case OnboardingStep.customerPrefs:
      return _CustomerPrefsStep(state: state);
    case OnboardingStep.customerReady:
      return _CustomerReadyStep(state: state);
    case OnboardingStep.role:
    case OnboardingStep.providerCategory:
    case OnboardingStep.providerRadius:
    case OnboardingStep.providerBio:
    case OnboardingStep.providerPortfolio:
    case OnboardingStep.providerTrust:
    case OnboardingStep.providerPreview:
      return _CustomerPrefsStep(state: state);
    default:
      return const SizedBox.shrink();
  }
}

class _GeoStep extends StatefulWidget {
  const _GeoStep({required this.state});
  final NeeAppState state;
  @override
  State<_GeoStep> createState() => _GeoStepState();
}

class _GeoStepState extends State<_GeoStep> {
  var loading = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const NeeHeader(
          title: '¿Dónde estás?',
          subtitle:
              'Usamos tu ubicación para conectarte con servicios y oportunidades cerca de ti.',
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: loading ? null : _detect,
          child: Text(loading ? 'Buscando…' : 'Usar mi ubicación actual'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => widget.state.goTo(OnboardingStep.address),
          child: const Text('Ingresar ubicación manualmente'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Color(0xFFB3261E))),
        ],
      ],
    );
  }

  Future<void> _detect() async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await detectLocation();
    if (!mounted) return;
    setState(() => loading = false);
    if (result.error != null) {
      setState(() => error = result.error);
      return;
    }
    final found = result.address!;
    _copyAddress(widget.state.user.currentLocation, found);
    _copyAddress(widget.state.user.registeredAddress, found);
    widget.state.goTo(OnboardingStep.address);
  }
}

void _copyAddress(GeoAddress to, GeoAddress from) {
  to
    ..latitude = from.latitude
    ..longitude = from.longitude
    ..country = from.country
    ..department = from.department
    ..city = from.city
    ..zone = from.zone
    ..street = from.street
    ..number = from.number
    ..reference = from.reference;
}

class _AddressStep extends StatefulWidget {
  const _AddressStep({required this.state});
  final NeeAppState state;

  @override
  State<_AddressStep> createState() => _AddressStepState();
}

class _AddressStepState extends State<_AddressStep> {
  late final country = TextEditingController(text: widget.state.user.registeredAddress.country);
  late final department = TextEditingController(text: widget.state.user.registeredAddress.department);
  late final city = TextEditingController(text: widget.state.user.registeredAddress.city);
  late final zone = TextEditingController(text: widget.state.user.registeredAddress.zone);
  late final street = TextEditingController(text: widget.state.user.registeredAddress.street);
  late final number = TextEditingController(text: widget.state.user.registeredAddress.number);
  late final reference = TextEditingController(text: widget.state.user.registeredAddress.reference);

  @override
  void dispose() {
    country.dispose();
    department.dispose();
    city.dispose();
    zone.dispose();
    street.dispose();
    number.dispose();
    reference.dispose();
    super.dispose();
  }

  void _sync() {
    final a = widget.state.user.registeredAddress;
    a
      ..country = country.text
      ..department = department.text
      ..city = city.text
      ..zone = zone.text
      ..street = street.text
      ..number = number.text
      ..reference = reference.text;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.state.user.registeredAddress;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const NeeHeader(
          title: 'Tu ubicación',
          subtitle:
              'Esta es tu dirección registrada. Puede ser distinta de donde estás ahora.',
        ),
        const SizedBox(height: 12),
        _MiniMap(
          address: a,
          onNudge: (dLat, dLng) {
            a.latitude = (a.latitude ?? -16.5) + dLat;
            a.longitude = (a.longitude ?? -68.15) + dLng;
            widget.state.notifyAndSave();
          },
        ),
        const SizedBox(height: 16),
        TextField(controller: country, decoration: const InputDecoration(labelText: 'País')),
        const SizedBox(height: 10),
        TextField(controller: department, decoration: const InputDecoration(labelText: 'Departamento')),
        const SizedBox(height: 10),
        TextField(controller: city, decoration: const InputDecoration(labelText: 'Ciudad')),
        const SizedBox(height: 10),
        TextField(controller: zone, decoration: const InputDecoration(labelText: 'Barrio / zona')),
        const SizedBox(height: 10),
        TextField(controller: street, decoration: const InputDecoration(labelText: 'Calle')),
        const SizedBox(height: 10),
        TextField(controller: number, decoration: const InputDecoration(labelText: 'Número')),
        const SizedBox(height: 10),
        TextField(controller: reference, decoration: const InputDecoration(labelText: 'Complemento / referencia')),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            _sync();
            if (!(a.isFilled || a.hasCoords)) return;
            await widget.state.confirmRegisteredAddress();
            if (!context.mounted) return;
            widget.state.goTo(OnboardingStep.phone);
          },
          child: const Text('Confirmar ubicación'),
        ),
      ],
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.address, required this.onNudge});
  final GeoAddress address;
  final void Function(double dLat, double dLng) onNudge;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFD9E8C8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.place, size: 44, color: NeeColors.ink),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Wrap(
              spacing: 4,
              children: [
                _nudge(Icons.west, () => onNudge(0, -0.0004)),
                _nudge(Icons.east, () => onNudge(0, 0.0004)),
                _nudge(Icons.north, () => onNudge(0.0004, 0)),
                _nudge(Icons.south, () => onNudge(-0.0004, 0)),
              ],
            ),
          ),
          if (address.hasCoords)
            Positioned(
              right: 12,
              top: 12,
              child: Text(
                '${address.latitude!.toStringAsFixed(4)}, ${address.longitude!.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _nudge(IconData icon, VoidCallback onTap) {
    return Material(
      color: NeeColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _PhoneStep extends StatefulWidget {
  const _PhoneStep({required this.state});
  final NeeAppState state;
  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  late final controller = TextEditingController(text: widget.state.user.phone);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const NeeHeader(title: '¿Cuál es tu número?'),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            prefixText: '+591  ',
            hintText: '77712345',
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () {
            widget.state.user.phone = controller.text.trim();
            if (widget.state.user.phone.replaceAll(RegExp(r'\D'), '').length <
                8) {
              return;
            }
            widget.state.sendSmsCode();
            widget.state.goTo(OnboardingStep.otp);
          },
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _OtpStep extends StatefulWidget {
  const _OtpStep({required this.state});
  final NeeAppState state;
  @override
  State<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<_OtpStep> {
  final controller = TextEditingController();
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        NeeHeader(
          title: 'Te enviamos un código',
          subtitle:
              'SMS a +591 ${widget.state.user.phone}. En esta prueba usa 123456.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '_ _ _ _ _ _',
            errorText: error,
            counterText: '',
          ),
        ),
        TextButton(
          onPressed: () {
            widget.state.sendSmsCode();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Código reenviado. Usa 123456.')),
            );
          },
          child: const Text('Reenviar código'),
        ),
        TextButton(
          onPressed: () => widget.state.goTo(OnboardingStep.phone),
          child: const Text('Alterar número'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            if (widget.state.verifySms(controller.text)) {
              widget.state.goTo(OnboardingStep.profile);
            } else {
              setState(() => error = 'Código incorrecto');
            }
          },
          child: const Text('Verificar'),
        ),
      ],
    );
  }
}

class _ProfileStep extends StatefulWidget {
  const _ProfileStep({required this.state});
  final NeeAppState state;
  @override
  State<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<_ProfileStep> {
  late final first = TextEditingController(text: widget.state.user.firstName);
  late final last = TextEditingController(text: widget.state.user.lastName);
  late final email = TextEditingController(text: widget.state.user.email);

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const NeeHeader(
          title: '¿Quién eres?',
          subtitle: 'Solo lo necesario para crear tu cuenta.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: first,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nombre'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: last,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Apellido'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'E-mail'),
        ),
        const SizedBox(height: 10),
        const Text('Sexo (opcional)', style: TextStyle(fontWeight: FontWeight.w700)),
        Wrap(
          spacing: 8,
          children: [
            for (final option in ['Mujer', 'Hombre', 'Otro'])
              ChoiceChip(
                label: Text(option),
                selected: widget.state.user.sexo == option,
                selectedColor: NeeColors.yellow,
                onSelected: (_) {
                  setState(() => widget.state.user.sexo = option);
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fecha de nacimiento (opcional)'),
          subtitle: Text(
            widget.state.user.birthDate == null
                ? 'Puedes omitirla'
                : MaterialLocalizations.of(context).formatCompactDate(
                    widget.state.user.birthDate!,
                  ),
          ),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(now.year - 80),
              lastDate: DateTime(now.year - 16),
              initialDate: DateTime(now.year - 25),
            );
            if (picked != null) {
              setState(() => widget.state.user.birthDate = picked);
            }
          },
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            widget.state.user
              ..firstName = first.text.trim()
              ..lastName = last.text.trim()
              ..email = email.text.trim();
            if (widget.state.user.firstName.isEmpty) return;
            widget.state.goTo(OnboardingStep.photo);
          },
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _PhotoStep extends StatefulWidget {
  const _PhotoStep({required this.state});
  final NeeAppState state;

  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  var saving = false;

  NeeAppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const NeeHeader(
          title: 'Queremos conocerte 👋',
          subtitle: 'Agrega una foto de perfil',
        ),
        const SizedBox(height: 28),
        Center(
          child: PhotoCircleButton(
            bytes: state.user.photoBytes,
            url: state.user.photoUrl,
            initials: state.user.initials,
            onTap: saving ? () {} : () => _pick(ImageSource.gallery),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: saving ? null : () => _pick(ImageSource.camera),
          child: const Text('Tomar foto'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: saving ? null : () => _pick(ImageSource.gallery),
          child: const Text('Elegir de la galería'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving ? null : _continue,
          child: Text(saving ? 'Guardando…' : 'Continuar'),
        ),
        TextButton(
          onPressed: saving
              ? null
              : () => state.goTo(OnboardingStep.customerPrefs),
          child: const Text('Omitir por ahora'),
        ),
      ],
    );
  }

  Future<void> _continue() async {
    setState(() => saving = true);
    await state.flushPendingAvatar();
    if (!mounted) return;
    setState(() => saving = false);
    state.goTo(OnboardingStep.customerPrefs);
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 900,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => saving = true);
    await state.saveProfilePhoto(bytes);
    if (!mounted) return;
    setState(() => saving = false);
  }
}

class _CustomerPrefsStep extends StatefulWidget {
  const _CustomerPrefsStep({required this.state});
  final NeeAppState state;

  @override
  State<_CustomerPrefsStep> createState() => _CustomerPrefsStepState();
}

class _CustomerPrefsStepState extends State<_CustomerPrefsStep> {
  var loading = false;

  NeeAppState get state => widget.state;

  List<ServiceCategory> get catalog =>
      state.catalog.isNotEmpty ? state.catalog : categories;

  List<ServiceCategory> get spotlight => spotlightCategories(catalog);

  @override
  void initState() {
    super.initState();
    _ensureCatalog();
  }

  Future<void> _ensureCatalog() async {
    if (state.catalog.length >= 20) return;
    setState(() => loading = true);
    try {
      final list = await ProfessionalRepository.loadCategories();
      if (list.isNotEmpty) state.catalog = list;
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  void _toggle(ServiceCategory category, bool value) {
    if (value) {
      state.user.preferredCategories.add(category.id);
    } else {
      state.user.preferredCategories.remove(category.id);
    }
    state.notifyAndSave();
    setState(() {});
  }

  Future<void> _seeAll() async {
    final picked = await showTradePicker(context, catalog: catalog);
    if (picked == null || !mounted) return;
    if (!state.user.preferredCategories.contains(picked.id)) {
      state.user.preferredCategories.add(picked.id);
      state.notifyAndSave();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final extras = <ServiceCategory>[];
    for (final id in state.user.preferredCategories) {
      if (spotlight.any((item) => item.id == id)) continue;
      for (final item in catalog) {
        if (item.id == id) extras.add(item);
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const NeeHeader(
          title: '¿Qué tipo de ayuda sueles necesitar?',
          subtitle:
              'Opcional. Elige lo frecuente; el resto está a un toque en Ver todos.',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _seeAll,
            child: const Text('Ver todos los oficios'),
          ),
        ),
        if (loading) ...[
          const LinearProgressIndicator(
            color: NeeColors.vest,
            backgroundColor: Color(0xFFD8D2C4),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in [...spotlight, ...extras])
              FilterChip(
                label: Text(category.name),
                selected: state.user.preferredCategories.contains(category.id),
                selectedColor: NeeColors.yellow,
                onSelected: (value) => _toggle(category, value),
              ),
          ],
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => state.goTo(OnboardingStep.customerReady),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _CustomerReadyStep extends StatelessWidget {
  const _CustomerReadyStep({required this.state});
  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const NeeHeader(
            title: '¡Todo listo!',
            subtitle: 'Ya puedes encontrar profesionales cerca de ti.',
          ),
          const Spacer(),
          FilledButton(
            onPressed: state.finishCustomer,
            child: const Text('Buscar un profesional'),
          ),
        ],
      ),
    );
  }
}
