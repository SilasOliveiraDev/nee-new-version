import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../data/account_repository.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/nee_sheets.dart';
import 'account_screens.dart';
import 'addresses_manager.dart';
import 'password_flow.dart';

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final user = state.user;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Center(child: ProfileAvatar(user: user, radius: 44)),
              const SizedBox(height: 12),
              Text(
                user.fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (user.email.isNotEmpty)
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NeeColors.muted),
                ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => _open(context, ProfileDataScreen(state: state)),
                  child: const Text('Editar perfil'),
                ),
              ),
              const SizedBox(height: 20),
              _Group(
                title: 'Mi cuenta',
                children: [
                  _Row(
                    label: 'Mis datos',
                    onTap: () => _open(context, ProfileDataScreen(state: state)),
                  ),
                  _Row(
                    label: 'Mis direcciones',
                    onTap: () => _open(context, AddressesManagerScreen(state: state)),
                  ),
                  _Row(
                    label: 'Seguridad',
                    onTap: () => _open(context, SecurityScreen(state: state)),
                  ),
                ],
              ),
              _Group(
                title: 'Preferencias',
                children: [
                  _Row(
                    label: 'Notificaciones',
                    onTap: () => _open(context, NotificationsScreen(state: state)),
                  ),
                  _Row(
                    label: 'Idioma',
                    onTap: () => _open(context, LanguageScreen(state: state)),
                  ),
                  _Row(
                    label: 'Permisos',
                    onTap: () => _open(context, PermissionsScreen(state: state)),
                  ),
                ],
              ),
              _Group(
                title: 'Ayuda',
                children: [
                  _Row(
                    label: 'Preguntas frecuentes',
                    onTap: () => _open(context, const FaqScreen()),
                  ),
                  _Row(
                    label: 'Centro de ayuda',
                    onTap: () => _open(context, HelpCenterScreen(state: state)),
                  ),
                  _Row(
                    label: 'Contactar soporte',
                    onTap: () => showInformationSheet(
                      context,
                      title: 'Soporte',
                      body:
                          'Escríbenos a soporte@nee.bo. Pronto tendrás tickets dentro de Ñee.',
                    ),
                  ),
                ],
              ),
              _Group(
                title: 'Acerca de',
                children: [
                  _Row(
                    label: 'Sobre Ñee',
                    onTap: () => _open(context, const AboutNeeScreen()),
                  ),
                  _Row(
                    label: 'Términos y condiciones',
                    onTap: () => _open(context, const LegalScreen(slug: 'terms')),
                  ),
                  _Row(
                    label: 'Política de privacidad',
                    onTap: () => _open(context, const LegalScreen(slug: 'privacy')),
                  ),
                  const _Row(label: 'Versión de la aplicación', trailing: '1.0.0 (1)'),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _logout(context),
                child: const Text('Cerrar sesión'),
              ),
              TextButton(
                onPressed: () => _delete(context),
                child: const Text(
                  'Eliminar cuenta',
                  style: TextStyle(color: NeeColors.waiting),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context, Widget page) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirmationSheet(
      context,
      title: '¿Cerrar sesión?',
      body: 'Tendrás que iniciar sesión nuevamente para acceder a tu cuenta.',
      primary: 'Cerrar sesión',
      secondary: 'Cancelar',
      destructivePrimary: true,
    );
    if (!ok || !context.mounted) return;
    state.restartOnboarding();
  }

  Future<void> _delete(BuildContext context) async {
    final first = await showWarningSheet(
      context,
      title: '¿Eliminar tu cuenta?',
      body:
          'Esta acción puede eliminar permanentemente tus datos y el acceso a tu cuenta.',
      cta: 'Continuar',
    );
    if (!first || !context.mounted) return;
    final confirm = await showConfirmationSheet(
      context,
      title: 'Confirmar eliminación',
      body:
          'Tus solicitudes anteriores conservan el snapshot del servicio. No podrás entrar de nuevo con esta cuenta.',
      primary: 'Eliminar cuenta',
      secondary: 'Cancelar',
      destructivePrimary: true,
    );
    if (!confirm || !context.mounted) return;
    final ok = await AccountRepository.deleteAccount();
    if (!context.mounted) return;
    if (!ok) {
      await showErrorSheet(
        context,
        title: 'No se pudo eliminar',
        body: 'Inténtalo de nuevo en unos minutos.',
      );
      return;
    }
    state.restartOnboarding();
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Material(
            color: NeeColors.chalk,
            borderRadius: BorderRadius.circular(18),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.onTap, this.trailing});

  final String label;
  final VoidCallback? onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: trailing != null
          ? Text(trailing!, style: const TextStyle(color: NeeColors.muted))
          : const Icon(Icons.chevron_right, weight: 200),
      onTap: onTap,
    );
  }
}

class ProfileDataScreen extends StatefulWidget {
  const ProfileDataScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  State<ProfileDataScreen> createState() => _ProfileDataScreenState();
}

class _ProfileDataScreenState extends State<ProfileDataScreen> {
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

  Future<void> _save() async {
    widget.state.user
      ..firstName = first.text.trim()
      ..lastName = last.text.trim()
      ..email = email.text.trim();
    widget.state.notifyAndSave();
    if (!mounted) return;
    await showSuccessSheet(
      context,
      title: 'Datos guardados ✓',
      body: 'Tu perfil fue actualizado correctamente.',
    );
  }

  Future<void> _photo() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NeeColors.chalk,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                title: const Text('Eliminar foto'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    if (action == 'delete') {
      widget.state.user.photoBytes = null;
      widget.state.user.photoUrl = null;
      final id = widget.state.user.supabaseUuid;
      if (id != null) await AccountRepository.clearAvatar(id);
      widget.state.notifyAndSave();
      return;
    }
    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 78,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      await showErrorSheet(
        context,
        title: 'La foto es muy grande',
        body: 'Elige una imagen de hasta 5 MB.',
      );
      return;
    }
    widget.state.user.photoBytes = bytes;
    final id = widget.state.user.supabaseUuid ?? widget.state.customerId;
    if (id != 'local-customer') {
      await AccountRepository.uploadAvatar(id, bytes);
    }
    widget.state.notifyAndSave();
    if (!mounted) return;
    await showSuccessSheet(
      context,
      title: 'Foto guardada ✓',
      body: 'Tu foto de perfil fue actualizada.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Mis datos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: PhotoCircleButton(
              bytes: user.photoBytes,
              initials: user.initials,
              onTap: _photo,
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('Cambiar foto')),
          const SizedBox(height: 20),
          TextField(
            controller: first,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: last,
            decoration: const InputDecoration(labelText: 'Apellido'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              suffixText: user.emailVerified ? '✓ Verificado' : null,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Teléfono'),
            subtitle: Text('${user.countryCode} ${user.phone}'),
            trailing: Text(
              user.phoneVerified ? '✓ Verificado' : 'Pendiente',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangePhoneScreen(state: widget.state),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
