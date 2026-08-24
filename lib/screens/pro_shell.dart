import 'package:flutter/material.dart';

import '../app_state.dart';
import '../client/nee_adaptive_nav.dart';
import '../domain/availability.dart';
import '../mock_data.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/nee_sheets.dart';

class ProShell extends StatefulWidget {
  const ProShell({super.key, required this.state});

  final NeeAppState state;

  @override
  State<ProShell> createState() => _ProShellState();
}

class _ProShellState extends State<ProShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProOpportunitiesScreen(state: widget.state),
      ProActiveScreen(state: widget.state),
      ProHistoryScreen(state: widget.state),
      ProAccountScreen(state: widget.state),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NeeAdaptiveNav(
        index: index,
        onChange: (value) => setState(() => index = value),
        tabs: const [
          NeeTabSpec(label: 'Pedidos', glyph: NeeNavGlyph.bell),
          NeeTabSpec(label: 'Activos', glyph: NeeNavGlyph.work),
          NeeTabSpec(label: 'Historial', glyph: NeeNavGlyph.clock),
          NeeTabSpec(label: 'Perfil', glyph: NeeNavGlyph.person),
        ],
      ),
    );
  }
}

class ProOpportunitiesScreen extends StatelessWidget {
  const ProOpportunitiesScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final incoming = state.incomingForPro;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              NeeHeader(
                title: '${state.user.first}, tu perfil ya está listo.',
                subtitle:
                    'Hay personas buscando profesionales como tú. Oportunidades cerca → leads → trabajos.',
              ),
              const SizedBox(height: 16),
              if (incoming.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: NeeColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Todavía no hay pedidos nuevos. Cambia a la vista de cliente, pide un servicio de tu rubro y vuelve acá.',
                    style: TextStyle(color: NeeColors.muted, height: 1.4),
                  ),
                ),
              for (final request in incoming) ...[
                _OpportunityCard(
                  request: request,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProRequestDetailScreen(
                          state: state,
                          request: request,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => state.activateRole(AppRole.customer),
                child: const Text('Usar Ñee como cliente'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.request, required this.onOpen});

  final ServiceRequest request;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NeeColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: NeeColors.yellow,
                    child: Icon(request.category.icon, color: NeeColors.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      request.isDirect
                          ? 'Nueva solicitud directa'
                          : 'Nuevo pedido · ${request.category.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(request.description),
              const SizedBox(height: 6),
              Text(
                request.status == RequestStatus.sent
                    ? request.discoveryLabel
                    : request.location,
                style: const TextStyle(color: NeeColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProRequestDetailScreen extends StatelessWidget {
  const ProRequestDetailScreen({
    super.key,
    required this.state,
    required this.request,
  });

  final NeeAppState state;
  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          request.isDirect ? 'Nueva solicitud directa' : 'Pedido del cliente',
        ),
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeeHeader(
                  title: request.category.name,
                  subtitle: request.description,
                ),
                const SizedBox(height: 12),
                Text(
                  request.status == RequestStatus.sent
                      ? request.discoveryLabel
                      : request.location,
                ),
                const SizedBox(height: 8),
                Text(
                  'Estado: ${request.status.label}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (request.isDirect &&
                    request.directStatus == DirectStatus.pending) ...[
                  FilledButton(
                    onPressed: () async {
                      final result = await state.acceptDirectToChat(request);
                      if (!context.mounted) return;
                      if (!result.ok && result.error == 'CONFLICT') {
                        await showErrorSheet(
                          context,
                          title: 'Tu disponibilidad cambió',
                          body:
                              'Ya tienes otro servicio en este horario. Puedes proponer otro momento al cliente.',
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: const Text('Aceptar y conversar'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final reason = await showModalBottomSheet<String>(
                        context: context,
                        builder: (context) {
                          const options = [
                            ('UNAVAILABLE', 'No estoy disponible'),
                            ('BAD_TIME', 'El horario no me sirve'),
                            ('OUT_OF_ZONE', 'Está fuera de mi zona'),
                            ('WRONG_JOB', 'No realizo este tipo de trabajo'),
                            ('OTHER_SERVICE', 'Ya tengo otro servicio'),
                            ('OTHER', 'Otro'),
                          ];
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    '¿Por qué no puedes atender?',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                for (final item in options)
                                  ListTile(
                                    title: Text(item.$2),
                                    onTap: () => Navigator.pop(context, item.$1),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                      if (reason == null || !context.mounted) return;
                      await state.declineDirect(request, reason);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: const Text('No puedo atender'),
                  ),
                ] else if (request.isDirect &&
                    request.directStatus == DirectStatus.negotiation)
                  FilledButton(
                    onPressed: () async {
                      final start = request.requestedStart ?? DateTime.now();
                      final end = request.requestedEnd ??
                          start.add(const Duration(hours: 1));
                      final result = await state.sendFinalProposal(
                        request,
                        start: start,
                        end: end,
                        price: request.agreedPrice ?? 120,
                        durationMinutes: request.agreedDurationMinutes ?? 60,
                      );
                      if (!context.mounted) return;
                      if (!result.ok) {
                        await showErrorSheet(
                          context,
                          title: 'Tu disponibilidad cambió',
                          body:
                              'Ya tienes otro servicio en este horario. Puedes proponer otro momento al cliente.',
                        );
                        return;
                      }
                      await showSuccessSheet(
                        context,
                        title: 'Propuesta enviada',
                        body: 'El cliente puede confirmar el servicio.',
                      );
                    },
                    child: const Text('Enviar para confirmar'),
                  )
                else if (request.status == RequestStatus.sent)
                  FilledButton(
                    onPressed: () {
                      state.acceptAsProfessional(request);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Aceptar este trabajo'),
                  )
                else if (request.status != RequestStatus.completed)
                  FilledButton(
                    onPressed: () => state.advanceStatus(request),
                    child: const Text('Avanzar estado'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ProActiveScreen extends StatelessWidget {
  const ProActiveScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final active = state.activeForPro;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const NeeHeader(
                title: 'Servicios activos',
                subtitle: 'Coordina y marca el avance del trabajo.',
              ),
              const SizedBox(height: 16),
              if (active.isEmpty)
                const Text(
                  'No tienes servicios en curso.',
                  style: TextStyle(color: NeeColors.muted),
                ),
              for (final request in active) ...[
                ListTile(
                  tileColor: NeeColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(request.category.name),
                  subtitle: Text(request.status.label),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProRequestDetailScreen(
                          state: state,
                          request: request,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class ProHistoryScreen extends StatelessWidget {
  const ProHistoryScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final history = state.historyForPro;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const NeeHeader(title: 'Historial'),
              const SizedBox(height: 16),
              if (history.isEmpty)
                const Text(
                  'Cuando completes un servicio, queda guardado acá.',
                  style: TextStyle(color: NeeColors.muted),
                ),
              for (final request in history)
                ListTile(
                  title: Text(request.category.name),
                  subtitle: Text(request.location),
                  trailing: const Icon(
                    Icons.check_circle,
                    color: NeeColors.success,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ProAccountScreen extends StatelessWidget {
  const ProAccountScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final oficios = categories
        .where((c) => user.serviceIds.contains(c.id))
        .map((c) => c.name)
        .join(', ');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const NeeHeader(title: 'Tu perfil profesional'),
          const SizedBox(height: 16),
          Center(child: ProfileAvatar(user: user, radius: 48)),
          const SizedBox(height: 12),
          Text(
            user.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          Text(
            user.fullAddress,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NeeColors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            '+591 ${user.phone}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            oficios.isEmpty ? 'Sin oficios' : oficios,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trabajos',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 10),
          if (user.portfolio.isEmpty)
            const Text(
              'Todavía no hay fotos ni videos de tu trabajo.',
              style: TextStyle(color: NeeColors.muted),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in user.portfolio)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: NeeColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    image: item.isVideo
                        ? null
                        : DecorationImage(
                            image: MemoryImage(item.bytes),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: item.isVideo
                      ? const Icon(Icons.play_circle_fill, size: 36)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: () => state.activateRole(AppRole.customer),
            child: const Text('Entrar como cliente'),
          ),
          TextButton(
            onPressed: state.restartOnboarding,
            child: const Text('Cerrar sesión / volver al inicio'),
          ),
        ],
      ),
    );
  }
}
