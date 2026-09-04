import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../data/hire_repository.dart';
import '../domain/availability.dart';
import '../models.dart';
import '../places/place_models.dart';
import '../service_schedule.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/nee_sheets.dart';
import '../client/account_gate.dart';
import '../domain/guest_intent.dart';
import 'buscar_servicio_flow.dart';
import 'chat_thread_screen.dart';
import 'service_place_flow.dart';
import 'status_screen.dart';

Future<void> startDirectHire(
  BuildContext context, {
  required NeeAppState state,
  required Professional professional,
}) async {
  if (state.isGuest) {
    final ok = await ensureAccount(
      context,
      state: state,
      intent: GuestIntent.hire(professional.id),
    );
    if (!ok || !context.mounted) return;
  }
  if (state.blocksNewSolicitud && state.createBlock != null) {
    await showRestrictionSheet(
      context,
      restriction: state.createBlock!,
      title: 'Podrás solicitar nuevamente en ${state.createBlock!.countdown}',
      body:
          'Detectamos varios cambios en pocos minutos. Tus servicios anteriores y tus mensajes siguen disponibles.',
    );
    return;
  }
  final request = await Navigator.of(context).push<ServiceRequest>(
    MaterialPageRoute(
      builder: (_) => DirectHireFlow(state: state, professional: professional),
    ),
  );
  if (!context.mounted || request == null) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DirectHireSentScreen(state: state, request: request),
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
  final description = TextEditingController();
  int photos = 0;
  bool video = false;
  ServiceLocationSnapshot? place;
  ServiceSchedule schedule = ServiceSchedule();
  AvailabilityView? live;
  bool sending = false;

  Professional get pro => widget.professional;
  String get first => pro.firstName;
  String get categoryLine => pro.categoryLabel;
  String get specialtyLine =>
      pro.specialtyIfDifferent ?? (pro.specialty.trim().isEmpty ? categoryLine : pro.specialty);

  @override
  void initState() {
    super.initState();
    final saved = widget.state.defaultPlace;
    if (saved != null) {
      place = ServiceLocationSnapshot.fromPlace(saved);
    }
    HireRepository.statusFor(pro.id).then((view) {
      if (!mounted || !view.reported) return;
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

  bool get needsPlaceConfirm =>
      step == 1 && !(place?.canConfirm ?? false);

  bool get canContinue {
    switch (step) {
      case 0:
        return description.text.trim().isNotEmpty;
      case 1:
        if (needsPlaceConfirm) return true;
        return schedule.type != null;
      default:
        return true;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source);
      if (file != null && mounted) setState(() => photos += 1);
    } catch (_) {}
  }

  Future<void> _pickVideo() async {
    try {
      final file = await ImagePicker().pickVideo(source: ImageSource.camera);
      if (file != null && mounted) setState(() => video = true);
    } catch (_) {
      if (mounted) setState(() => video = true);
    }
  }

  Future<void> _changePlace() async {
    final next = await pickServicePlace(
      context: context,
      state: widget.state,
      current: place,
    );
    if (next != null) setState(() => place = next);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked == null) return;
    setState(() {
      schedule.type = ScheduleType.specificDate;
      schedule.startDate = picked;
      schedule.flexibleTime = true;
      schedule.period = SchedulePeriod.flexible;
    });
  }

  void _chooseAsap() {
    setState(() {
      schedule.type = ScheduleType.asap;
      schedule.urgency = UrgencyLevel.immediate;
      schedule.receiveNow = ReceiveNow.yes;
      schedule.startDate = DateTime.now();
    });
  }

  void _chooseFrom(DateTime when, ScheduleType type) {
    setState(() {
      schedule.type = type;
      schedule.startDate = when;
      if (type == ScheduleType.today && !canAsap) {
        schedule.period = SchedulePeriod.custom;
        schedule.startMinutes = when.hour * 60 + when.minute;
        schedule.endMinutes = (schedule.startMinutes ?? 0) + 60;
        schedule.flexibleTime = false;
      } else {
        schedule.period = SchedulePeriod.flexible;
        schedule.flexibleTime = true;
      }
    });
  }

  Future<void> _send() async {
    if (sending) return;
    setState(() => sending = true);
    final start = schedule.startDate ?? DateTime.now();
    final requestedStart = view.status == ProOpsStatus.busy &&
            view.nextAvailableAt != null
        ? view.nextAvailableAt!
        : start;
    try {
    final request = await widget.state.createRequest(
        category: ServiceCategory(
          id: pro.categoryId.isEmpty ? 'direct' : pro.categoryId,
          name: categoryLine.isEmpty ? specialtyLine : categoryLine,
          icon: Icons.handyman_outlined,
          hint: specialtyLine,
        ),
        description: description.text.trim(),
        location: place?.locationLabel ?? place?.publicHint ?? '',
        urgency: schedule.summary,
        photoCount: photos,
        hasVideo: video,
        specialty: specialtyLine,
        schedule: schedule,
        serviceLocation: place,
        kind: RequestKind.direct,
        professional: pro,
        directStatus: DirectStatus.pending,
        requestedStart: requestedStart,
        requestedEnd: requestedStart.add(const Duration(hours: 1)),
      );
      if (!mounted) return;
      Navigator.of(context).pop(request);
    } catch (_) {
      if (!mounted) return;
      setState(() => sending = false);
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
        title: Text('Paso ${step + 1} de 3'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: LinearProgressIndicator(
              value: (step + 1) / 3,
              color: NeeColors.vest,
              backgroundColor: const Color(0xFFD8D2C4),
              minHeight: 4,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (step == 0) ..._need(),
                if (step == 1) ..._whereWhen(),
                if (step == 2) ..._summary(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: !canContinue || sending
                ? null
                : () {
                    if (needsPlaceConfirm) {
                      _changePlace();
                      return;
                    }
                    if (step < 2) {
                      setState(() => step += 1);
                    } else {
                      _send();
                    }
                  },
            child: Text(
              needsPlaceConfirm
                  ? (place == null ? 'Elegir ubicación' : 'Confirmar en el mapa')
                  : step < 2
                      ? 'Continuar'
                      : 'Enviar solicitud a $first',
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _need() {
    return [
      Text(
        '¿Qué necesitas que haga $first?',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 10),
      if (categoryLine.isNotEmpty) _CategoryChip(label: categoryLine),
      if (specialtyLine.isNotEmpty &&
          specialtyLine.toLowerCase() != categoryLine.toLowerCase()) ...[
        const SizedBox(height: 8),
        Text(
          specialtyLine,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ],
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
      const SizedBox(height: 22),
      const Text(
        '¿Quieres mostrarle el problema?',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      const SizedBox(height: 6),
      const Text(
        'Opcional',
        style: TextStyle(color: NeeColors.muted, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => _pickImage(ImageSource.camera),
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(photos == 0 ? 'Tomar foto' : '$photos fotos'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _pickVideo,
        icon: const Icon(Icons.videocam_outlined),
        label: Text(video ? 'Video agregado' : 'Grabar video'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _pickImage(ImageSource.gallery),
        icon: const Icon(Icons.photo_outlined),
        label: const Text('Galería'),
      ),
    ];
  }

  List<Widget> _whereWhen() {
    final next = view.nextAvailableAt;
    return [
      Text(
        '¿Dónde será el servicio?',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 6),
      const Text(
        'El profesional irá a esta ubicación.',
        style: TextStyle(color: NeeColors.muted),
      ),
      const SizedBox(height: 14),
      _PlaceCard(place: place, onChange: _changePlace),
      const SizedBox(height: 28),
      Text(
        '¿Cuándo necesitas a $first?',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      _AvailabilityBanner(first: first, view: view),
      const SizedBox(height: 16),
      if (canAsap)
        _WhenTile(
          selected: schedule.type == ScheduleType.asap,
          label: '🔥 Lo antes posible',
          onTap: _chooseAsap,
        ),
      if (!canAsap && next != null)
        _WhenTile(
          selected: schedule.type == ScheduleType.today &&
              schedule.startDate != null &&
              schedule.startDate!.isAtSameMomentAs(next),
          label: 'Hoy desde las ${AvailabilityView.clock(next)}',
          onTap: () => _chooseFrom(next, ScheduleType.today),
        ),
      if (canAsap)
        _WhenTile(
          selected: schedule.type == ScheduleType.today,
          label: '☀️ Hoy',
          onTap: () => _chooseFrom(DateTime.now(), ScheduleType.today),
        ),
      _WhenTile(
        selected: schedule.type == ScheduleType.tomorrow,
        label: '🌤 Mañana',
        onTap: () => _chooseFrom(
          DateTime.now().add(const Duration(days: 1)),
          ScheduleType.tomorrow,
        ),
      ),
      _WhenTile(
        selected: schedule.type == ScheduleType.specificDate,
        label: schedule.type == ScheduleType.specificDate &&
                schedule.startDate != null
            ? '📅 ${_prettyDate(schedule.startDate!)}'
            : '📅 Elegir fecha',
        onTap: _pickDate,
      ),
    ];
  }

  List<Widget> _summary() {
    return [
      Text(
        'Tu solicitud para $first',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NeeColors.chalk,
          borderRadius: BorderRadius.circular(NeeRadii.tile),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: NeeColors.vest,
                  foregroundColor: NeeColors.soot,
                  backgroundImage: (pro.avatarUrl ?? '').startsWith('http')
                      ? NetworkImage(pro.avatarUrl!)
                      : null,
                  child: (pro.avatarUrl ?? '').startsWith('http')
                      ? null
                      : Text(
                          pro.initials,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              first,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (pro.verified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: NeeColors.vest,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Verificado',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (categoryLine.isNotEmpty)
                        Text(
                          categoryLine,
                          style: const TextStyle(color: NeeColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (specialtyLine.isNotEmpty)
              Text(
                '🔧 $specialtyLine',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            const SizedBox(height: 6),
            Text('“${description.text.trim()}”'),
            if (photos > 0 || video) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (photos > 0) '📷 $photos fotos',
                  if (video) '🎥 Video',
                ].join('  '),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '📍 ${place?.displayTitle ?? 'Lugar'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(place?.displayBody.replaceAll('\n', ', ') ?? ''),
            const SizedBox(height: 8),
            Text(schedule.summary.isEmpty ? '📅 Horario por coordinar' : schedule.summary),
          ],
        ),
      ),
    ];
  }
}

class DirectHireSentScreen extends StatelessWidget {
  const DirectHireSentScreen({
    super.key,
    required this.state,
    required this.request,
  });

  final NeeAppState state;
  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final pro = request.professional;
    final first = pro?.firstName ?? 'el profesional';
    final available = pro?.availability.availableNow ?? false;
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const NeeLogo(height: 34)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Solicitud enviada ✓',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$first recibió tu solicitud.',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Estamos esperando su respuesta. Te avisaremos cuando responda. El pago, cuando acuerden el precio, lo haces directo al profesional.',
              style: TextStyle(color: NeeColors.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (available)
              Text(
                '🟢 $first estaba disponible al momento del envío.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                final professional = pro;
                if (professional == null) return;
                await openServiceChat(
                  context,
                  state: state,
                  request: request,
                  offer: ServiceOffer(
                    id: 'direct',
                    professional: professional,
                  ),
                );
              },
              child: const Text('Abrir chat'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        StatusScreen(state: state, request: request),
                  ),
                );
              },
              child: const Text('Ver mi solicitud'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                state.goClientTab(1, history: false);
              },
              child: const Text('Ir a mis solicitudes'),
            ),
          ],
        ),
      ),
    );
  }
}

class DirectHireDeclinedActions {
  static Future<void> findAnother(
    BuildContext context, {
    required NeeAppState state,
    required ServiceRequest request,
  }) {
    return openBuscarServicio(
      context,
      state: state,
      category: request.category,
      query: request.description,
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onChange});

  final ServiceLocationSnapshot? place;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final confirmed = place?.canConfirm ?? false;
    return Material(
      color: NeeColors.chalk,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: NeeColors.soot.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place == null ? '📍 Lugar del servicio' : '🏠 ${place!.displayTitle}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              place?.displayBody.replaceAll('\n', ', ') ??
                  'Elige dónde irá el profesional.',
              style: const TextStyle(color: NeeColors.muted, height: 1.35),
            ),
            if (place != null && !confirmed) ...[
              const SizedBox(height: 8),
              const Text(
                'Falta confirmar en el mapa',
                style: TextStyle(
                  color: NeeColors.waiting,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onChange,
                child: Text(place == null ? 'Elegir' : 'Cambiar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityBanner extends StatelessWidget {
  const _AvailabilityBanner({required this.first, required this.view});

  final String first;
  final AvailabilityView view;

  @override
  Widget build(BuildContext context) {
    if (view.availableNow) {
      return Text(
        '🟢 $first está disponible ahora',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      );
    }
    final next = view.nextAvailableAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🟡 $first está trabajando ahora',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        if (next != null) ...[
          const SizedBox(height: 4),
          Text(
            'Próxima disponibilidad: ${AvailabilityView.clock(next)}',
            style: const TextStyle(color: NeeColors.muted),
          ),
        ],
      ],
    );
  }
}

class _WhenTile extends StatelessWidget {
  const _WhenTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? NeeColors.vest.withValues(alpha: 0.35) : NeeColors.chalk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? NeeColors.soot : NeeColors.soot.withValues(alpha: 0.14),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NeeColors.chalk,
        borderRadius: BorderRadius.circular(NeeRadii.pill),
        border: Border.all(color: NeeColors.soot.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

String _prettyDate(DateTime date) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${date.day} de ${months[date.month - 1]}';
}
