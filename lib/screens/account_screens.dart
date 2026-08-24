import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_state.dart';
import '../data/account_repository.dart';
import '../domain/account.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/nee_sheets.dart';
import 'password_flow.dart';
import 'tickets_screen.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Seguridad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ListTile(
            title: const Text('Cambiar contraseña'),
            trailing: const Icon(Icons.chevron_right, weight: 200),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangePasswordScreen(state: state),
              ),
            ),
          ),
          ListTile(
            title: const Text('Dispositivos y sesiones'),
            subtitle: const Text('Próximamente'),
            onTap: () => showInformationSheet(
              context,
              title: 'Dispositivos y sesiones',
              body:
                  'Aquí podrás ver dónde está abierta tu cuenta. Face ID y 2FA llegarán más adelante.',
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final p = state.notifPrefs;
        return Scaffold(
          backgroundColor: NeeColors.paper,
          appBar: AppBar(title: const Text('Notificaciones')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              SwitchListTile(
                title: const Text('Notificaciones push'),
                value: p.pushEnabled,
                onChanged: (value) {
                  p.pushEnabled = value;
                  state.saveNotifPrefs();
                },
              ),
              const Divider(),
              _Pref(
                label: 'Mensajes del chat',
                value: p.chatMessages,
                enabled: p.pushEnabled,
                onChanged: (v) {
                  p.chatMessages = v;
                  state.saveNotifPrefs();
                },
              ),
              _Pref(
                label: 'Nuevas ofertas',
                value: p.newOffers,
                enabled: p.pushEnabled,
                onChanged: (v) {
                  p.newOffers = v;
                  state.saveNotifPrefs();
                },
              ),
              _Pref(
                label: 'Actualizaciones de mis solicitudes',
                value: p.requestUpdates,
                enabled: p.pushEnabled,
                onChanged: (v) {
                  p.requestUpdates = v;
                  state.saveNotifPrefs();
                },
              ),
              _Pref(
                label: 'Profesional en camino',
                value: p.professionalOnTheWay,
                enabled: p.pushEnabled,
                onChanged: (v) {
                  p.professionalOnTheWay = v;
                  state.saveNotifPrefs();
                },
              ),
              _Pref(
                label: 'Servicio iniciado',
                value: p.serviceStarted,
                enabled: p.pushEnabled,
                onChanged: (v) {
                  p.serviceStarted = v;
                  state.saveNotifPrefs();
                },
              ),
              _Pref(
                label: 'Servicio finalizado',
                value: p.serviceFinished,
                enabled: p.pushEnabled,
                onChanged: (v) {
                  p.serviceFinished = v;
                  state.saveNotifPrefs();
                },
              ),
              _Pref(
                label: 'Recordatorios',
                value: p.reminders,
                enabled: p.pushEnabled,
                onChanged: (v) {
                  p.reminders = v;
                  state.saveNotifPrefs();
                },
              ),
              _Pref(
                label: 'Promociones y novedades',
                value: p.marketing,
                enabled: p.pushEnabled,
                onChanged: (v) {
                  p.marketing = v;
                  state.saveNotifPrefs();
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Si el sistema de tu teléfono bloqueó los avisos, actívalos ahí. Ñee no puede encender un permiso del dispositivo.',
                style: TextStyle(color: NeeColors.muted, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pref extends StatelessWidget {
  const _Pref({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      value: enabled && value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Idioma')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ListTile(
            title: const Text('Español'),
            trailing: const Icon(Icons.check, color: NeeColors.open),
            onTap: () {},
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Pronto más idiomas. Ñee está pensado para Bolivia.',
              style: TextStyle(color: NeeColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  String location = 'Consultando…';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() {
      location = status == LocationPermission.always ||
              status == LocationPermission.whileInUse
          ? 'Permitido'
          : 'Desactivado';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Permisos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ListTile(title: const Text('📍 Ubicación'), trailing: Text(location)),
          const ListTile(title: Text('📷 Cámara'), trailing: Text('Según el dispositivo')),
          const ListTile(title: Text('🖼 Fotos'), trailing: Text('Según el dispositivo')),
          const ListTile(title: Text('🔔 Notificaciones'), trailing: Text('Según el dispositivo')),
          const SizedBox(height: 12),
          if (location == 'Desactivado') ...[
            const Text(
              'Las notificaciones o la ubicación pueden estar desactivadas en el sistema.',
              style: TextStyle(color: NeeColors.muted),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: () => Geolocator.openAppSettings(),
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }
}

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  var query = '';
  List<FaqItem> items = fallbackFaqs;
  var loading = true;

  @override
  void initState() {
    super.initState();
    AccountRepository.loadFaq().then((value) {
      if (mounted) {
        setState(() {
          items = value;
          loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((item) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return item.question.toLowerCase().contains(q) ||
          item.answer.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q);
    }).toList();
    final cats = {for (final item in filtered) item.category};
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Preguntas frecuentes')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'Buscar una pregunta...',
                    prefixIcon: Icon(Icons.search, weight: 200),
                  ),
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  const Text(
                    'No encontramos esa pregunta. Prueba con otras palabras o contacta soporte.',
                    style: TextStyle(color: NeeColors.muted),
                  ),
                for (final cat in cats) ...[
                  Text(cat, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final item in filtered.where((i) => i.category == cat))
                    ExpansionTile(
                      title: Text(item.question),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            item.answer,
                            style: const TextStyle(color: NeeColors.muted, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Centro de ayuda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ListTile(
            title: const Text('Preguntas frecuentes'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FaqScreen()),
            ),
          ),
          ListTile(
            title: const Text('Contactar soporte'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TicketsScreen(state: state),
              ),
            ),
          ),
          ListTile(
            title: const Text('Reportar un problema'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TicketsScreen(state: state),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutNeeScreen extends StatelessWidget {
  const AboutNeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Sobre Ñee')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const NeeLogo(height: 56),
          const SizedBox(height: 16),
          Text(
            'Ñee conecta personas que necesitan resolver algo con profesionales preparados para hacerlo.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Publicas lo que necesitas, recibes propuestas de gente cerca y eliges con quién trabajar. Conversar no es contratar: la relación oficial empieza cuando confirmas al profesional.',
            style: TextStyle(height: 1.45, color: NeeColors.muted),
          ),
          const SizedBox(height: 24),
          const Text('Versión 1.0.0', style: TextStyle(fontWeight: FontWeight.w800)),
          const Text('Build 1', style: TextStyle(color: NeeColors.muted)),
        ],
      ),
    );
  }
}

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.slug});

  final String slug;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String title = '';
  String body = '';
  var loading = true;

  @override
  void initState() {
    super.initState();
    AccountRepository.loadLegal(widget.slug).then((doc) {
      if (!mounted) return;
      setState(() {
        loading = false;
        title = doc?.title ??
            (widget.slug == 'terms' ? 'Términos y condiciones' : 'Política de privacidad');
        body = doc?.body ??
            'El documento se actualizará desde Ñee. Al continuar usas la aplicación de acuerdo con nuestras reglas de uso y privacidad.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: Text(title.isEmpty ? 'Ñee' : title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(body, style: const TextStyle(height: 1.45)),
              ],
            ),
    );
  }
}
