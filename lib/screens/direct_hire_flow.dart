import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../data/hire_repository.dart';
import '../domain/availability.dart';
import '../models.dart';
import '../places/place_models.dart';
import '../service_schedule.dart';
import '../theme.dart';
import '../widgets/nee_sheets.dart';
import 'service_place_flow.dart';
import 'status_screen.dart';

Future<void> startDirectHire(
  BuildContext context, {
  required NeeAppState state,
  required Professional professional,
}) async {
  final request = await Navigator.of(context).push<ServiceRequest>(
    MaterialPageRoute(
      builder: (_) => DirectHireFlow(state: state, professional: professional),
    ),
  );
  if (!context.mounted || request == null) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => StatusScreen(state: state, request: request),
    ),
  );
}

class DirectHireFlow extends StatefulWidget {
  const DirectHireFlow({
    super.key,
    required this.state,
    required this.professional,
  });

  final NeeAppState state;
  final Professional professional;

  @override
  State<DirectHireFlow> createState() => _DirectHireFlowState();
}

class _DirectHireFlowState extends State<DirectHireFlow> {
  int step = 0;
  late String specialty;
  final description = TextEditingController();
  int photos = 0;
  bool video = false;
  ServiceLocationSnapshot? place;
  ServiceSchedule schedule = ServiceSchedule();
  AvailabilityView? live;

  Professional get pro => widget.professional;
  String get first => pro.firstName;

  List<String> get specialties {
    final tags = pro.tags.where((t) => t.trim().isNotEmpty).toList();
    if (tags.isNotEmpty) return [...tags, 'Otro'];
    return [pro.specialty, 'Otro'];
  }

  @override
  void initState() {
    super.initState();
    specialty = specialties.first;
    HireRepository.statusFor(pro.id).then((view) {
      if (!mounted) return;
      setState(() => live = view);
    });
  }

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  AvailabilityView get view => live ?? pro.availability;

  bool get canAsap => view.availableNow;

  Future<void> _send() async {
    final start = schedule.startDate ?? DateTime.now();
    final requestedStart = view.status == ProOpsStatus.busy &&
            view.nextAvailableAt != null
        ? view.nextAvailableAt!
        : start;
    final requestedEnd = requestedStart.add(const Duration(hours: 1));
    try {
      final request = widget.state.createRequest(
        category: ServiceCategory(
          id: pro.categoryId,
          name: specialty,
          icon: Icons.handyman_outlined,
          hint: specialty,
        ),
        description: description.text.trim(),
        location: place?.locationLabel ?? place?.publicHint ?? '',
        urgency: schedule.summary,
        photoCount: photos,
        hasVideo: video,
        specialty: specialty,
        schedule: schedule,
        serviceLocation: place,
        kind: RequestKind.direct,
        professional: pro,
        directStatus: DirectStatus.pending,
        requestedStart: requestedStart,
        requestedEnd: requestedEnd,
      );
      if (!mounted) return;
      Navigator.of(context).pop(request);
    } catch (_) {
      if (!mounted) return;
      await showErrorSheet(
        context,
        title: 'No se pudo enviar',
        body: 'Revisa tu cuenta e inténtalo de nuevo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(
        title: Text(
          step == 0
              ? '¿Qué necesitas que haga $first?'
              : step == 1
                  ? '¿Dónde será el servicio?'
                  : step == 2
                      ? '¿Cuándo necesitas a $first?'
                      : 'Solicitud para $first',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (step == 0) ..._need(),
          if (step == 1) ..._where(),
          if (step == 2) ..._when(),
          if (step == 3) ..._summary(),
        ],
      ),
    );
  }

  List<Widget> _need() {
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in specialties)
            ChoiceChip(
              label: Text(item),
              selected: specialty == item,
              onSelected: (_) => setState(() => specialty = item),
            ),
        ],
      ),
      const SizedBox(height: 20),
      const Text(
        'Cuéntanos un poco más',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: description,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: 'Describe brevemente lo que necesitas',
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          TextButton.icon(
            onPressed: () async {
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (file != null) setState(() => photos += 1);
            },
            icon: const Icon(Icons.photo_outlined),
            label: Text(photos == 0 ? 'Agregar fotos' : '$photos fotos'),
          ),
          TextButton.icon(
            onPressed: () => setState(() => video = true),
            icon: const Icon(Icons.videocam_outlined),
            label: Text(video ? 'Video agregado' : 'Agregar video'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: description.text.trim().isEmpty
            ? null
            : () => setState(() => step = 1),
        child: const Text('Continuar'),
      ),
    ];
  }

  List<Widget> _where() {
    return [
      if (place != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            place!.locationLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      FilledButton(
        onPressed: () async {
          final next = await pickServicePlace(
            context: context,
            state: widget.state,
            current: place,
          );
          if (next != null) setState(() => place = next);
        },
        child: Text(place == null ? 'Elegir dirección' : 'Cambiar dirección'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: place == null ? null : () => setState(() => step = 2),
        child: const Text('Continuar'),
      ),
    ];
  }

  List<Widget> _when() {
    final next = view.nextAvailableAt;
    return [
      Text(
        '${view.emoji} ${view.primaryLabel}',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      if (view.status == ProOpsStatus.busy) ...[
        const SizedBox(height: 8),
        Text('$first está atendiendo otro servicio.'),
        if (next != null)
          Text('Estará disponible a partir de las ${AvailabilityView.clock(next)}.'),
      ],
      const SizedBox(height: 16),
      if (canAsap)
        _option('🔥 Lo antes posible', () {
          schedule.type = ScheduleType.asap;
          setState(() => step = 3);
        }),
      if (!canAsap && next != null)
        _option(
          'Solicitar desde las ${AvailabilityView.clock(next)}',
          () {
            schedule.type = ScheduleType.today;
            schedule.startDate = next;
            setState(() => step = 3);
          },
        ),
      _option('☀️ Hoy', () {
        schedule.type = ScheduleType.today;
        schedule.startDate = DateTime.now();
        setState(() => step = 3);
      }),
      _option('🌤 Mañana', () {
        schedule.type = ScheduleType.tomorrow;
        schedule.startDate = DateTime.now().add(const Duration(days: 1));
        setState(() => step = 3);
      }),
    ];
  }

  Widget _option(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onTap,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
      ),
    );
  }

  List<Widget> _summary() {
    return [
      Text(specialty, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
      const SizedBox(height: 8),
      Text(description.text.trim()),
      if (photos > 0) Text('📷 $photos fotos'),
      const SizedBox(height: 8),
      Text('📍 ${place?.publicHint ?? place?.locationLabel ?? ''}'),
      Text('📅 ${schedule.summary}'),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _send,
        child: Text('Enviar solicitud a $first'),
      ),
      TextButton(
        onPressed: () => setState(() => step = 0),
        child: const Text('Editar'),
      ),
    ];
  }
}
