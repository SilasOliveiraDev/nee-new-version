import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/availability.dart';
import '../domain/cancellation.dart';
import '../domain/request_lifecycle.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/nee_sheets.dart';
import 'chat_thread_screen.dart';
import 'direct_hire_flow.dart';
import 'professional_profile_screen.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({
    super.key,
    required this.state,
    required this.request,
  });

  final NeeAppState state;
  final ServiceRequest request;

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final _offersKey = GlobalKey();

  NeeAppState get state => widget.state;
  ServiceRequest get request => widget.request;

  @override
  void initState() {
    super.initState();
    if (request.status == RequestStatus.professionalFound) {
      state.ensureOffers(request);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Estado del servicio')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final status = request.status;
          final snap = request.serviceLocation;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                _headline(),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (request.isDirect &&
                  request.category.name.isNotEmpty &&
                  _headline() != request.category.name) ...[
                const SizedBox(height: 4),
                Text(
                  request.category.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              if (request.specialty.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  request.specialty,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                request.description,
                style: const TextStyle(height: 1.35),
              ),
              if (request.isDirect) ...[
                const SizedBox(height: 10),
                const Text(
                  'El pago lo haces directo al profesional, no dentro de Ñee.',
                  style: TextStyle(
                    color: NeeColors.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                [
                  if ((snap?.neighborhood ?? '').isNotEmpty)
                    '📍  ${snap!.neighborhood}'
                  else if (request.location.isNotEmpty)
                    '📍  ${request.location}',
                  if (request.schedule != null) '📅  ${request.schedule!.summary}',
                ].join('\n'),
                style: const TextStyle(color: NeeColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              Text(
                request.stageLabel.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 6),
              Text(
                _lead(status),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (status == RequestStatus.professionalFound &&
                  !request.isDirect &&
                  request.offers.isNotEmpty)
                KeyedSubtree(
                  key: _offersKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _offerCards(context),
                  ),
                ),
              if (RequestLifecycle.hasProfessional(status) &&
                  request.professional != null) ...[
                ProfessionalCard(professional: request.professional!),
                const SizedBox(height: 16),
              ],
              Text(
                RequestLifecycle.isClosed(status) &&
                        status != RequestStatus.completed &&
                        status != RequestStatus.awaitingRating
                    ? 'Solicitud cancelada'
                    : 'Estado',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (request.closeNote != null && request.closeNote!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  request.closeNote!,
                  style: const TextStyle(color: NeeColors.muted),
                ),
              ],
              if (request.closedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Cancelada el ${request.closedAt!.day}/${request.closedAt!.month}/${request.closedAt!.year}',
                  style: const TextStyle(color: NeeColors.muted),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: NeeColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: StatusTimeline(current: status),
              ),
              const SizedBox(height: 24),
              if (request.directStatus != DirectStatus.pending &&
                  (!RequestLifecycle.isClosed(status) ||
                      status == RequestStatus.awaitingRating ||
                      (status == RequestStatus.completed && !request.rated)))
                FilledButton(
                  onPressed: () => _primary(context),
                  child: Text(_primaryCtaLabel(status)),
                ),
              ..._secondaryActions(context, status),
              if (request.directStatus == DirectStatus.declined ||
                  request.directStatus == DirectStatus.expired) ...[
                const SizedBox(height: 8),
                Text(
                  request.directStatus == DirectStatus.expired
                      ? '${request.professional?.firstName ?? 'El profesional'} no respondió a tiempo.'
                      : '${request.professional?.firstName ?? 'El profesional'} no puede atender esta solicitud.',
                  style: const TextStyle(height: 1.35),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Podemos ayudarte a encontrar otro profesional.',
                  style: TextStyle(color: NeeColors.muted),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => DirectHireDeclinedActions.findAnother(
                    context,
                    state: state,
                    request: request,
                  ),
                  child: const Text('Buscar otro profesional'),
                ),
              ],
              if (RequestLifecycle.canCancelStatus(status))
                TextButton(
                  onPressed: () => _cancel(context),
                  child: Text(
                    RequestLifecycle.hasProfessional(status)
                        ? 'Cancelar servicio'
                        : 'Cancelar solicitud',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _secondaryActions(BuildContext context, RequestStatus status) {
    switch (status) {
      case RequestStatus.accepted:
        return [
          TextButton(
            onPressed: () => _openProfile(context, request.professional),
            child: const Text('Ver perfil'),
          ),
        ];
      case RequestStatus.onTheWay:
        return [
          TextButton(
            onPressed: () => _contact(context),
            child: const Text('Contactar profesional'),
          ),
        ];
      case RequestStatus.inProgress:
        return [
          TextButton(
            onPressed: () => _report(context),
            child: const Text('Reportar un problema'),
          ),
        ];
      default:
        return const [];
    }
  }

  String _headline() {
    final first = request.professional?.firstName ?? 'El profesional';
    if (request.isDirect) {
      switch (request.directStatus) {
        case DirectStatus.pending:
          return 'Solicitud enviada ✓';
        case DirectStatus.negotiation:
          return '$first aceptó tu solicitud 🎉';
        case DirectStatus.pendingConfirmation:
          return 'Confirmar servicio';
        case DirectStatus.expired:
          return '$first no respondió a tiempo';
        case DirectStatus.declined:
          return '$first no puede atender esta solicitud';
        default:
          break;
      }
    }
    return request.category.name;
  }

  String _primaryCtaLabel(RequestStatus status) {
    if (request.directStatus == DirectStatus.pendingConfirmation) {
      return 'Confirmar servicio';
    }
    if (request.isDirect && request.directStatus == DirectStatus.negotiation) {
      return 'Abrir chat';
    }
    return RequestLifecycle.primaryCta(status);
  }

  String _lead(RequestStatus status) {
    if (request.isDirect) {
      switch (request.directStatus) {
        case DirectStatus.pending:
          return '${request.professional?.firstName ?? 'El profesional'} recibió tu solicitud. Estamos esperando su respuesta. Te avisaremos cuando responda.';
        case DirectStatus.negotiation:
          return 'Ahora pueden conversar para coordinar los últimos detalles.';
        case DirectStatus.pendingConfirmation:
          return '${request.professional?.firstName ?? 'El profesional'} está listo para confirmar.';
        case DirectStatus.expired:
          return 'Podemos ayudarte a encontrar otro profesional.';
        case DirectStatus.declined:
          return 'Podemos ayudarte a encontrar otro profesional.';
        default:
          break;
      }
    }
    switch (status) {
      case RequestStatus.sent:
        return 'Estamos mostrando tu solicitud a profesionales cerca.';
      case RequestStatus.professionalFound:
        final n = request.offers.length;
        return n == 1
            ? '1 profesional envió una propuesta'
            : '$n profesionales enviaron una propuesta';
      case RequestStatus.accepted:
        return '${request.professional?.name ?? 'El profesional'} coordinará el servicio contigo.';
      case RequestStatus.onTheWay:
        return 'El profesional se está desplazando hacia la ubicación.';
      case RequestStatus.inProgress:
        return 'El servicio está en curso.';
      case RequestStatus.awaitingRating:
        return 'Cuéntanos cómo te fue.';
      case RequestStatus.completed:
        return 'El servicio quedó registrado.';
      default:
        return request.status.label;
    }
  }

  List<Widget> _offerCards(BuildContext context) {
    return [
      const Text(
        'Revisa sus perfiles y elige quién realizará el servicio.',
        style: TextStyle(color: NeeColors.muted),
      ),
      const SizedBox(height: 12),
      for (final offer in request.offers) ...[
        _OfferCard(
          offer: offer,
          categoryName: request.category.name,
          onOpen: () => _openOffer(context, offer),
          onAsk: () => _askProfessional(context, offer),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Future<void> _openOffer(BuildContext context, ServiceOffer offer) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NeeColors.chalk,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final p = offer.professional;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.name, style: Theme.of(context).textTheme.headlineMedium),
              Text('⭐ ${p.rating} · ${p.jobs} trabajos'),
              const SizedBox(height: 8),
              if (offer.message.isNotEmpty) Text('“${offer.message}”'),
              if (offer.priceBs != null)
                Text(
                  'Bs. ${offer.priceBs!.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, 'profile'),
                child: const Text('Ver perfil'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, 'portfolio'),
                child: const Text('Ver portafolio'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, 'ask'),
                child: const Text('Hacer una pregunta'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'select'),
                child: const Text('Seleccionar profesional'),
              ),
            ],
          ),
        );
      },
    );
    if (!context.mounted || action == null) return;
    if (action == 'profile' || action == 'portfolio') {
      await _openProfile(context, offer.professional);
      return;
    }
    if (action == 'contact' || action == 'ask') {
      await _askProfessional(context, offer);
      return;
    }
    if (action == 'select') {
      await _confirmSelect(context, offer);
    }
  }

  Future<void> _openProfile(BuildContext context, Professional? professional) async {
    if (professional == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfessionalProfileScreen(
          state: state,
          professional: professional,
        ),
      ),
    );
  }

  Future<void> _askProfessional(BuildContext context, ServiceOffer offer) {
    return openServiceChat(
      context,
      state: state,
      request: request,
      offer: offer,
    );
  }

  Future<void> _contact(BuildContext context) async {
    final professional = request.professional;
    if (professional == null) {
      await showInformationSheet(
        context,
        title: 'Chat',
        body: 'Selecciona un profesional para coordinar el servicio desde Ñee.',
      );
      return;
    }
    ServiceOffer? offer;
    for (final item in request.offers) {
      if (item.professional.id == professional.id) offer = item;
    }
    await openServiceChat(
      context,
      state: state,
      request: request,
      offer: offer ?? ServiceOffer(id: 'selected', professional: professional),
    );
  }

  Future<void> _report(BuildContext context) {
    return showWarningSheet(
      context,
      title: 'Reportar un problema',
      body:
          'Cuéntanos qué ocurrió. Si el servicio no se puede continuar, también puedes cancelarlo. Un reporte de seguridad no afecta tu cuenta.',
    );
  }

  Future<void> _confirmSelect(BuildContext context, ServiceOffer offer) async {
    if (state.blocksNewSolicitud) {
      await showRestrictionSheet(context, restriction: state.createBlock!);
      return;
    }
    final p = offer.professional;
    final ok = await showConfirmationSheet(
      context,
      title: '¿Elegir a ${p.name.split(' ').first}?',
      body:
          'Al confirmar, ${p.name} será seleccionada para realizar tu servicio y ambos podrán coordinar los detalles desde Ñee.\n\n'
          '${p.name}\n⭐ ${p.rating} · ${p.jobs} servicios realizados\n'
          '${p.specialty}\n'
          '${p.distanceLabel == null ? '' : '📍 ${p.distanceLabel}\n'}'
          'Disponibilidad: ${offer.availability}'
          '${offer.priceBs == null ? '' : '\nPropuesta: Bs. ${offer.priceBs!.toStringAsFixed(0)}'}',
      primary: 'Confirmar profesional',
      secondary: 'Seguir viendo ofertas',
    );
    if (!ok || !context.mounted) return;
    await state.selectProfessional(request, offer);
    if (!context.mounted) return;
    final open = await showConfirmationSheet(
      context,
      title: '¡Ya están conectados! 🎉',
      body:
          '${p.name} fue seleccionada para realizar tu servicio.\n\nAhora pueden coordinar todos los detalles desde el chat.',
      primary: 'Abrir chat',
      secondary: 'Entendido',
    );
    if (open && context.mounted) {
      await _askProfessional(context, offer);
    }
  }

  Future<void> _primary(BuildContext context) async {
    final status = request.status;
    if (request.directStatus == DirectStatus.pendingConfirmation) {
      final result = await state.confirmDirectService(request);
      if (!context.mounted) return;
      if (!result.ok && result.error == 'CONFLICT') {
        final next = result.nextAvailableAt;
        await showErrorSheet(
          context,
          title: '${request.professional?.firstName ?? 'El profesional'} acaba de recibir otro servicio',
          body: next == null
              ? 'Su disponibilidad cambió mientras preparabas tu solicitud.'
              : 'Próxima disponibilidad: ${AvailabilityView.clock(next)}',
        );
        return;
      }
      if (!result.ok) {
        await showErrorSheet(
          context,
          title: 'No se pudo confirmar',
          body: 'Inténtalo de nuevo en un momento.',
        );
        return;
      }
      await showSuccessSheet(
        context,
        title: '¡Servicio confirmado! 🎉',
        body:
            '${request.professional?.firstName ?? 'El profesional'} realizará tu servicio.',
      );
      return;
    }
    if (request.isDirect && request.directStatus == DirectStatus.negotiation) {
      await _contact(context);
      return;
    }
    switch (status) {
      case RequestStatus.sent:
        await showInformationSheet(
          context,
          title: 'Tu solicitud',
          body: request.description,
        );
        return;
      case RequestStatus.professionalFound:
        final target = _offersKey.currentContext;
        if (target != null) {
          await Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          );
        }
        return;
      case RequestStatus.accepted:
        await _contact(context);
        return;
      case RequestStatus.onTheWay:
        await showInformationSheet(
          context,
          title: 'Llegada',
          body:
              'El profesional ya se está desplazando hacia la ubicación del servicio. Te avisaremos cuando esté más cerca.',
        );
        return;
      case RequestStatus.inProgress:
        await showInformationSheet(
          context,
          title: 'Detalles del servicio',
          body:
              'El profesional está trabajando en lo que describiste. Si algo no cuadra, puedes reportar un problema.',
        );
        return;
      case RequestStatus.awaitingRating:
      case RequestStatus.completed:
        request.rated = true;
        request.status = RequestStatus.completed;
        state.notifyAndSave();
        await showSuccessSheet(
          context,
          title: 'Gracias',
          body: 'Tu calificación ayuda a otras personas a elegir con confianza.',
        );
        return;
      default:
        return;
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final status = request.status;
    if (request.isDirect &&
        request.directStatus != DirectStatus.confirmed &&
        request.directStatus != null) {
      final go = await showConfirmationSheet(
        context,
        title: '¿Cancelar solicitud?',
        body: 'No se tratará como un servicio iniciado.',
        primary: 'Cancelar solicitud',
        secondary: 'Volver',
        destructivePrimary: true,
      );
      if (!go || !context.mounted) return;
      await state.cancelDirectPending(request);
      if (!context.mounted) return;
      await showSuccessSheet(
        context,
        title: 'Solicitud cancelada',
        body: 'Puedes buscar otro profesional cuando quieras.',
      );
      return;
    }
    final phase = status == RequestStatus.inProgress
        ? CancelPhase.inProgress
        : status == RequestStatus.onTheWay
            ? CancelPhase.onTheWay
            : RequestLifecycle.hasProfessional(status)
                ? CancelPhase.afterSelect
                : CancelPhase.beforeSelect;

    if (phase == CancelPhase.inProgress) {
      final go = await showWarningSheet(
        context,
        title: 'El servicio ya comenzó',
        body:
            'Cancelar ahora cerrará el servicio actual. Antes de continuar, necesitamos saber qué ocurrió.',
      );
      if (!go || !context.mounted) return;
    } else if (phase == CancelPhase.onTheWay) {
      final go = await showWarningSheet(
        context,
        title: 'El profesional ya está en camino',
        body:
            'El profesional ya se está desplazando hacia la ubicación del servicio. Si necesitas cancelar, indícanos el motivo para que podamos registrar correctamente lo ocurrido.',
      );
      if (!go || !context.mounted) return;
    } else if (phase == CancelPhase.afterSelect) {
      final stay = await showConfirmationSheet(
        context,
        title: '¿Cancelar el servicio?',
        body:
            'El profesional ya confirmó tu solicitud. Si cancelas, le avisaremos inmediatamente.',
        primary: 'Continuar con el servicio',
        secondary: 'Cancelar servicio',
      );
      if (stay || !context.mounted) return;
    } else {
      final go = await showConfirmationSheet(
        context,
        title: '¿Cancelar solicitud?',
        body: 'Tu solicitud dejará de estar disponible para los profesionales.',
        primary: 'Cancelar solicitud',
        secondary: 'Volver',
        destructivePrimary: true,
      );
      if (!go || !context.mounted) return;
    }

    if (!context.mounted) return;
    final reason = await _pickReason(context, phase);
    if (reason == null || !context.mounted) return;

    var reasonText = '';
    if (reason == CancelReason.other) {
      final typed = await _otherReasonText(context);
      if (typed == null || !context.mounted) return;
      reasonText = typed;
    }

    if (phase == CancelPhase.onTheWay) {
      final ok = await showConfirmationSheet(
        context,
        title: 'Confirmar cancelación',
        body: 'Vamos a avisar al profesional ahora.',
        primary: 'Confirmar cancelación',
        secondary: 'Volver',
        destructivePrimary: true,
      );
      if (!ok || !context.mounted) return;
    }

    final result = await state.cancelAsCustomer(
      request,
      reason: reason,
      phase: phase,
      reasonText: reasonText,
    );
    if (!context.mounted) return;

    if (reason == CancelReason.professionalCouldNotPerform) {
      await showInformationSheet(
        context,
        title: 'Entendido',
        body:
            'Cerraremos este servicio. Esta cancelación no afectará automáticamente tu cuenta.',
      );
      if (!context.mounted) return;
      final again = await showConfirmationSheet(
        context,
        title: '¿Quieres buscar otro profesional?',
        body: 'Mantenemos tu solicitud tal como la publicaste.',
        primary: 'Buscar otro profesional',
        secondary: 'Finalizar solicitud',
      );
      if (again) {
        state.reopenMatching(request);
      } else if (context.mounted) {
        _leaveAfterCancel(goHome: true);
      }
    } else if (reason == CancelReason.safetyConcern) {
      await showInformationSheet(
        context,
        title: 'Gracias por contarnos',
        body:
            'Registramos lo ocurrido para que el equipo de Ñee pueda revisar y ayudarte. Tu cuenta no se pausa por este motivo.',
      );
      if (context.mounted) _leaveAfterCancel(goHome: true);
    } else {
      final goHome = await showSuccessChoiceSheet(
        context,
        title: 'Servicio cancelado',
        body: 'Tu solicitud fue cancelada correctamente.',
        primary: 'Volver al inicio',
        secondary: 'Ver mis solicitudes',
      );
      if (context.mounted) _leaveAfterCancel(goHome: goHome);
    }

    if (result.restriction != null && context.mounted) {
      await showRestrictionSheet(context, restriction: result.restriction!);
    }
  }

  void _leaveAfterCancel({required bool goHome}) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    state.goClientTab(goHome ? 0 : 1, history: !goHome);
  }

  Future<String?> _otherReasonText(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NeeColors.chalk,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cuéntanos el motivo',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Escribe con tus palabras',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Continuar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<CancelReason?> _pickReason(BuildContext context, CancelPhase phase) {
    final items = reasonsFor(phase);
    return showModalBottomSheet<CancelReason>(
      context: context,
      backgroundColor: NeeColors.chalk,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                phase == CancelPhase.inProgress
                    ? 'El servicio ya comenzó'
                    : '¿Por qué quieres cancelar?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (phase == CancelPhase.inProgress)
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    'Antes de cancelar, cuéntanos qué ocurrió. Esto nos ayuda a proteger tanto a clientes como a profesionales.',
                  ),
                ),
              const SizedBox(height: 8),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label),
                  trailing: const Icon(Icons.chevron_right, weight: 200),
                  onTap: () => Navigator.pop(context, item.code),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.categoryName,
    required this.onOpen,
    required this.onAsk,
  });

  final ServiceOffer offer;
  final String categoryName;
  final VoidCallback onOpen;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final p = offer.professional;
    return Material(
      color: NeeColors.chalk,
      borderRadius: BorderRadius.circular(NeeRadii.tile),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: NeeColors.vest,
                  foregroundColor: NeeColors.soot,
                  child: Text(
                    p.initials,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text('⭐ ${p.rating} · ${p.jobs} trabajos'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(categoryName),
            Text(
              p.specialty,
              style: const TextStyle(color: NeeColors.muted),
            ),
            if (p.distanceLabel != null)
              Text(
                '📍 ${p.distanceLabel} de ti',
                style: const TextStyle(color: NeeColors.muted),
              ),
            Text(
              '✓ ${p.jobs} trabajos realizados',
              style: const TextStyle(color: NeeColors.muted),
            ),
            if (p.documentsVerified)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Documentos verificados',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              offer.availability,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (offer.message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('“${offer.message}”'),
            ],
            if (offer.priceBs != null)
              Text(
                'Bs. ${offer.priceBs!.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: onAsk,
                  child: const Text('Hacer una pregunta'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onOpen,
                  child: const Text('Ver propuesta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
