import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/availability.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/nee_sheets.dart';

Future<void> startDirectConfirm(
  BuildContext context, {
  required NeeAppState state,
  required ServiceRequest request,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DirectConfirmFlow(state: state, request: request),
    ),
  );
}

class DirectConfirmFlow extends StatefulWidget {
  const DirectConfirmFlow({
    super.key,
    required this.state,
    required this.request,
  });

  final NeeAppState state;
  final ServiceRequest request;

  @override
  State<DirectConfirmFlow> createState() => _DirectConfirmFlowState();
}

class _DirectConfirmFlowState extends State<DirectConfirmFlow> {
  var step = 0;
  var confirming = false;

  ServiceRequest get request => widget.request;
  Professional? get professional =>
      widget.state.professionalFor(request);

  String get first =>
      professional?.firstName ?? 'el profesional';

  Future<void> _confirm() async {
    if (confirming) return;
    setState(() => confirming = true);
    final result = await widget.state.confirmDirectService(request);
    if (!mounted) return;
    setState(() => confirming = false);
    if (!result.ok) {
      await showErrorSheet(
        context,
        title: 'No se pudo confirmar',
        body: result.error == 'CONFLICT'
            ? (result.nextAvailableAt == null
                ? 'La disponibilidad de $first cambió.'
                : 'Próxima disponibilidad: ${AvailabilityView.clock(result.nextAvailableAt!)}')
            : 'Inténtalo de nuevo en un momento.',
      );
      return;
    }
    await showSuccessSheet(
      context,
      title: '¡$first realizará tu servicio! 🎉',
      body:
          'Ya está seleccionado. El pago lo haces directo con $first, no dentro de Ñee.',
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final snap = request.serviceLocation;
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(
        title: Text(step == 0 ? 'Elegir profesional' : 'Confirmar servicio'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: step == 0 ? 0.5 : 1,
              color: NeeColors.vest,
              backgroundColor: const Color(0xFFD8D2C4),
            ),
            const SizedBox(height: 20),
            if (step == 0) ...[
              Text(
                '¿Quieres que $first haga este servicio?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Después de conversar, tú confirmas. Hasta entonces el servicio no queda cerrado.',
                style: TextStyle(color: NeeColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              if (professional != null) ProfessionalCard(professional: professional!),
              const SizedBox(height: 14),
              Text(
                request.description,
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 12),
              Text(
                [
                  if ((snap?.neighborhood ?? '').isNotEmpty)
                    '📍  ${snap!.neighborhood}'
                  else if (request.location.isNotEmpty)
                    '📍  ${request.location}',
                  if (request.schedule != null)
                    '📅  ${request.schedule!.summary}',
                  if (request.agreedPrice != null)
                    'Bs. ${request.agreedPrice!.toStringAsFixed(0)}',
                ].join('\n'),
                style: const TextStyle(color: NeeColors.muted, height: 1.4),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => setState(() => step = 1),
                child: Text('Continuar con $first'),
              ),
            ] else ...[
              Text(
                'Confirma para seleccionar a $first',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'El pago lo haces directo al profesional, no dentro de Ñee. Si el horario cambia, coordínenlo en el chat.',
                style: TextStyle(color: NeeColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NeeColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Al confirmar, $first queda seleccionado para este servicio y el estado pasa a Servicio.',
                  style: const TextStyle(height: 1.4, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: confirming ? null : _confirm,
                child: Text(
                  confirming ? 'Confirmando…' : 'Confirmar y seleccionar',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: confirming ? null : () => setState(() => step = 0),
                child: const Text('Volver'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
