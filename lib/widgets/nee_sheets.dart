import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/cancellation.dart';
import '../theme.dart';

Future<void> showSuccessSheet(
  BuildContext context, {
  required String title,
  required String body,
  String cta = 'Entendido',
}) {
  return showInformationSheet(
    context,
    title: title,
    body: body,
    cta: cta,
  );
}

Future<void> showErrorSheet(
  BuildContext context, {
  required String title,
  required String body,
  String cta = 'Entendido',
}) {
  return showInformationSheet(context, title: title, body: body, cta: cta);
}

/// true = primary, false = secondary
Future<bool> showSuccessChoiceSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String primary,
  required String secondary,
}) {
  return showConfirmationSheet(
    context,
    title: title,
    body: body,
    primary: primary,
    secondary: secondary,
  );
}

Future<void> showInformationSheet(
  BuildContext context, {
  required String title,
  required String body,
  String cta = 'Entendido',
}) {
  return _showNeeSheet(
    context,
    child: _SheetScaffold(
      title: title,
      body: body,
      primary: cta,
      onPrimary: () => Navigator.pop(context),
    ),
  );
}

Future<bool> showConfirmationSheet(
  BuildContext context, {
  required String title,
  required String body,
  String primary = 'Continuar',
  String secondary = 'Volver',
  bool destructivePrimary = false,
}) async {
  final result = await _showNeeSheet<bool>(
    context,
    child: _SheetScaffold(
      title: title,
      body: body,
      primary: primary,
      secondary: secondary,
      destructivePrimary: destructivePrimary,
      onPrimary: () => Navigator.pop(context, true),
      onSecondary: () => Navigator.pop(context, false),
    ),
  );
  return result ?? false;
}

Future<bool> showWarningSheet(
  BuildContext context, {
  required String title,
  required String body,
  String cta = 'Continuar',
}) async {
  final result = await _showNeeSheet<bool>(
    context,
    child: _SheetScaffold(
      title: title,
      body: body,
      primary: cta,
      secondary: 'Volver',
      onPrimary: () => Navigator.pop(context, true),
      onSecondary: () => Navigator.pop(context, false),
    ),
  );
  return result ?? false;
}

Future<void> showRestrictionSheet(
  BuildContext context, {
  required UserRestriction restriction,
  String? title,
  String? body,
}) {
  return _showNeeSheet(
    context,
    child: _RestrictionBody(restriction: restriction, title: title, body: body),
  );
}

Future<T?> _showNeeSheet<T>(BuildContext context, {required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NeeColors.chalk,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: child,
    ),
  );
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.body,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.destructivePrimary = false,
    this.extra,
  });

  final String title;
  final String body;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final bool destructivePrimary;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NeeColors.muted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(height: 1.4)),
        if (extra != null) ...[const SizedBox(height: 16), extra!],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onPrimary,
          style: destructivePrimary
              ? FilledButton.styleFrom(
                  backgroundColor: NeeColors.waiting,
                  foregroundColor: NeeColors.chalk,
                )
              : null,
          child: Text(primary),
        ),
        if (secondary != null && onSecondary != null)
          TextButton(onPressed: onSecondary, child: Text(secondary!)),
      ],
    );
  }
}

class _RestrictionBody extends StatefulWidget {
  const _RestrictionBody({
    required this.restriction,
    this.title,
    this.body,
  });

  final UserRestriction restriction;
  final String? title;
  final String? body;

  @override
  State<_RestrictionBody> createState() => _RestrictionBodyState();
}

class _RestrictionBodyState extends State<_RestrictionBody> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!widget.restriction.isActive) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: widget.title ?? 'Solicitudes pausadas temporalmente',
      body: widget.body ??
          'Detectamos varios cambios en pocos minutos. Para evitar solicitudes accidentales y proteger la disponibilidad de los profesionales, pausamos temporalmente la creación de nuevos servicios.',
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Podrás volver a solicitar en:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            widget.restriction.countdown,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: NeeColors.soot,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta pausa no afecta tu cuenta, tus conversaciones ni tus servicios anteriores.',
            style: TextStyle(color: NeeColors.muted),
          ),
        ],
      ),
      primary: 'Entendido',
      onPrimary: () => Navigator.pop(context),
    );
  }
}
