import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../client/catalog_query.dart';
import '../client/trade_picker.dart';
import '../data/professional_repository.dart';
import '../mock_data.dart';
import '../models.dart';
import '../need_intel.dart';
import '../places/place_models.dart';
import '../service_schedule.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/nee_sheets.dart';
import '../client/account_gate.dart';
import '../domain/guest_intent.dart';
import '../widgets/schedule_picker.dart';
import 'matching_screen.dart';
import 'service_place_flow.dart';
import 'status_screen.dart';

class ServiceDraft {
  ServiceDraft({
    this.category,
    this.specialty = '',
    this.description = '',
    this.hasAudio = false,
    this.audioSeconds = 0,
    this.hasVideo = false,
    this.location = '',
    this.serviceLocation,
    ServiceSchedule? schedule,
  }) : schedule = schedule ?? ServiceSchedule();

  ServiceCategory? category;
  String specialty;
  String description;
  bool hasAudio;
  int audioSeconds;
  final photos = <Uint8List>[];
  bool hasVideo;
  String location;
  ServiceLocationSnapshot? serviceLocation;
  final ServiceSchedule schedule;

  bool get hasValidPlace => serviceLocation?.canConfirm ?? false;

  void applyPlace(ServiceLocationSnapshot snapshot) {
    serviceLocation = snapshot;
    location = snapshot.locationLabel;
  }
}

Future<void> openBuscarServicio(
  BuildContext context, {
  required NeeAppState state,
  ServiceCategory? category,
  String query = '',
}) async {
  if (state.isGuest) {
    final ok = await ensureAccount(
      context,
      state: state,
      intent: GuestIntent.buscar(
        categoryId: category?.id,
        query: query,
      ),
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
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NeedCaptureScreen(
        state: state,
        initialCategory: category,
        initialQuery: query,
      ),
    ),
  );
}

class NeedCaptureScreen extends StatefulWidget {
  const NeedCaptureScreen({
    super.key,
    required this.state,
    this.initialCategory,
    this.initialQuery = '',
  });

  final NeeAppState state;
  final ServiceCategory? initialCategory;
  final String initialQuery;

  @override
  State<NeedCaptureScreen> createState() => _NeedCaptureScreenState();
}

class _NeedCaptureScreenState extends State<NeedCaptureScreen> {
  late final controller = TextEditingController(text: widget.initialQuery);
  ServiceCategory? category;
  String specialty = '';
  var specialties = <String>[];
  var loadingSubs = false;

  @override
  void initState() {
    super.initState();
    category = widget.initialCategory;
    controller.addListener(() => setState(() {}));
    if (category != null) _loadSpecialties(category!);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool get canContinue =>
      controller.text.trim().length >= 8 || category != null;

  List<ServiceCategory> get catalog =>
      widget.state.catalog.isNotEmpty ? widget.state.catalog : categories;

  List<ServiceCategory> get spotlight => spotlightCategories(catalog);

  Future<void> _loadSpecialties(ServiceCategory selected) async {
    setState(() {
      loadingSubs = true;
      specialties = NeedIntel.specialtiesOf(selected);
    });
    final remote = await ProfessionalRepository.loadSubcategories(selected.id);
    if (!mounted) return;
    setState(() {
      loadingSubs = false;
      if (remote.isNotEmpty) specialties = remote;
    });
  }

  Future<void> _pickCategory() async {
    final picked = await showTradePicker(
      context,
      catalog: catalog,
      selected: category,
    );
    if (picked == null || !mounted) return;
    setState(() {
      category = picked;
      specialty = '';
    });
    await _loadSpecialties(picked);
  }

  void _selectCategory(ServiceCategory item) {
    setState(() {
      category = item;
      specialty = '';
    });
    _loadSpecialties(item);
  }

  void _continue() {
    final text = controller.text.trim();
    final guessed = category ?? NeedIntel.guessCategory(text, catalog: catalog);
    final saved = widget.state.defaultPlace;
    final snap =
        saved == null ? null : ServiceLocationSnapshot.fromPlace(saved);
    final draft = ServiceDraft(
      category: guessed,
      specialty: specialty,
      description: text,
      location: snap?.locationLabel ?? '',
      serviceLocation: snap,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResolveOptionsScreen(state: widget.state, draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(
        title: const NeeLogo(height: 32),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            '¿Qué necesitas resolver?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Describe el problema o elige un oficio. Ñee te muestra la mejor forma de seguir.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: NeeColors.muted,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (canContinue) _continue();
            },
            decoration: const InputDecoration(
              hintText: 'Describe o busca un servicio...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Oficios frecuentes',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: _pickCategory,
                child: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in spotlight)
                ChoiceChip(
                  label: Text(item.name),
                  selected: category?.id == item.id,
                  selectedColor: NeeColors.vest,
                  onSelected: (_) => _selectCategory(item),
                ),
            ],
          ),
          if (category != null &&
              spotlight.every((item) => item.id != category!.id)) ...[
            const SizedBox(height: 10),
            ChoiceChip(
              label: Text(category!.name),
              selected: true,
              selectedColor: NeeColors.vest,
              onSelected: (_) {},
            ),
          ],
          if (loadingSubs) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(
              color: NeeColors.vest,
              backgroundColor: Color(0xFFD8D2C4),
            ),
          ],
          if (specialties.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              '${category!.name} → especialidad (opcional)',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Cualquiera'),
                  selected: specialty.isEmpty,
                  selectedColor: NeeColors.vest,
                  onSelected: (_) => setState(() => specialty = ''),
                ),
                for (final item in specialties)
                  FilterChip(
                    label: Text(item),
                    selected: specialty == item,
                    selectedColor: NeeColors.vest,
                    onSelected: (value) {
                      setState(() => specialty = value ? item : '');
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: canContinue ? _continue : null,
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

class ResolveOptionsScreen extends StatelessWidget {
  const ResolveOptionsScreen({
    super.key,
    required this.state,
    required this.draft,
  });

  final NeeAppState state;
  final ServiceDraft draft;

  @override
  Widget build(BuildContext context) {
    final hint = NeedIntel.hintFor(
      text: draft.description,
      category: draft.category,
      specialty: draft.specialty,
    );
    final title = draft.specialty.isNotEmpty
        ? draft.specialty
        : (draft.category?.name ?? 'Tu necesidad');
    final matches = professionalsReadyToHelp(
      draft.category?.id ?? '',
      catalog: state.directory,
      categoryName: draft.category?.name,
    );
    final available = matches.length;

    final reco = switch (hint) {
      ResolveHint.browse =>
        'Hay $available profesionales disponibles cerca. Quizá te convenga elegir uno.',
      ResolveHint.publish =>
        'Esto parece un problema para diagnosticar. Publica y recibe propuestas.',
      ResolveHint.either =>
        'Elige cómo quieres resolverlo. Las dos vías llegan a un profesional.',
    };

    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const NeeLogo(height: 32)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (draft.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              draft.description,
              style: const TextStyle(color: NeeColors.muted, height: 1.35),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NeeColors.vest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(reco, style: const TextStyle(height: 1.35)),
          ),
          const SizedBox(height: 20),
          _ResolveCard(
            emphasized: hint != ResolveHint.publish,
            title: 'Ver profesionales disponibles',
            body: 'Explora gente cerca de ti y elige con quién hablar.',
            action: 'Encontrar ahora',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MatchingScreen(
                    state: state,
                    categoryId: draft.category?.id,
                    title: 'Profesionales cerca',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ResolveCard(
            emphasized: hint != ResolveHint.browse,
            title: 'Publicar mi solicitud',
            body: 'Cuéntanos qué necesitas y recibe propuestas de interesados.',
            action: 'Recibir propuestas',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PublishRequestFlow(state: state, draft: draft),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ResolveCard extends StatelessWidget {
  const _ResolveCard({
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
    required this.emphasized,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? NeeColors.vest : NeeColors.chalk,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: NeeColors.soot,
          width: emphasized ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(body, style: const TextStyle(height: 1.35)),
              const SizedBox(height: 12),
              Text(
                action,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PublishRequestFlow extends StatefulWidget {
  const PublishRequestFlow({
    super.key,
    required this.state,
    required this.draft,
  });

  final NeeAppState state;
  final ServiceDraft draft;

  @override
  State<PublishRequestFlow> createState() => _PublishRequestFlowState();
}

class _PublishRequestFlowState extends State<PublishRequestFlow> {
  var step = 0;
  late final description = TextEditingController(
    text: widget.draft.description,
  );
  Timer? _audioTimer;
  var recording = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final raw = prefs.getString('nee_schedule_draft');
      if (!mounted || raw == null) return;
      try {
        setState(() => draft.schedule.applyJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    });
  }

  ServiceDraft get draft => widget.draft;

  @override
  void dispose() {
    description.dispose();
    _audioTimer?.cancel();
    super.dispose();
  }

  void _next() {
    if (step == 0) {
      draft.description = description.text.trim();
      if (draft.description.isEmpty && !draft.hasAudio) return;
    }
    if (step == 2 && !draft.hasValidPlace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Elige o confirma la ubicación del servicio para continuar.',
          ),
        ),
      );
      return;
    }
    if (step == 3 && !draft.schedule.isComplete) {
      setState(() {});
      return;
    }
    if (step < 4) {
      setState(() => step += 1);
      return;
    }
    _publish();
  }

  void _back() {
    if (step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => step -= 1);
  }

  Future<void> _pick(ImageSource source, {required bool video}) async {
    final picker = ImagePicker();
    if (video) {
      final file = await picker.pickVideo(source: source);
      if (file == null) return;
      setState(() => draft.hasVideo = true);
      return;
    }
    final file = await picker.pickImage(source: source, imageQuality: 70);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => draft.photos.add(bytes));
  }

  void _toggleAudio() {
    if (recording) {
      _audioTimer?.cancel();
      setState(() {
        recording = false;
        draft.hasAudio = draft.audioSeconds > 0;
      });
      return;
    }
    setState(() {
      recording = true;
      draft.audioSeconds = 0;
    });
    _audioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => draft.audioSeconds += 1);
    });
  }

  Future<void> _publish() async {
    if (widget.state.blocksNewSolicitud && widget.state.createBlock != null) {
      await showRestrictionSheet(
        context,
        restriction: widget.state.createBlock!,
        title:
            'Podrás solicitar nuevamente en ${widget.state.createBlock!.countdown}',
        body:
            'Detectamos varios cambios en pocos minutos. Tus servicios anteriores y tus mensajes siguen disponibles.',
      );
      return;
    }
    final category = draft.category ??
        NeedIntel.guessCategory(draft.description) ??
        categories.first;
    final request = await widget.state.createRequest(
      category: category,
      description: draft.description.isEmpty
          ? (draft.hasAudio
              ? 'Nota de voz (${draft.audioSeconds}s)'
              : category.name)
          : draft.description,
      location: draft.location,
      urgency: draft.schedule.summary,
      schedule: draft.schedule,
      serviceLocation: draft.serviceLocation,
      photoCount: draft.photos.length,
      hasAudio: draft.hasAudio,
      hasVideo: draft.hasVideo,
      specialty: draft.specialty,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SeekingMatchesScreen(
          state: widget.state,
          request: request,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text('Paso ${step + 1} de 5'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (step + 1) / 5,
                minHeight: 6,
                color: NeeColors.vest,
                backgroundColor: const Color(0xFFD8D2C4),
              ),
            ),
          ),
          Expanded(child: _step()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: FilledButton(
              onPressed: step == 2 && !draft.hasValidPlace ? null : _next,
              child: Text(step == 4 ? 'Publicar solicitud' : 'Continuar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step() {
    switch (step) {
      case 0:
        return _storyStep();
      case 1:
        return _mediaStep();
      case 2:
        return _placeStep();
      case 3:
        return _whenStep();
      default:
        return _confirmStep();
    }
  }

  Widget _storyStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        const NeeHeader(
          title: 'Cuéntanos qué necesitas',
          subtitle: '¿Qué está pasando?',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: description,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Ej: Mi ducha eléctrica dejó de funcionar.',
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _toggleAudio,
          icon: Icon(recording ? Icons.stop : Icons.mic_none),
          label: Text(
            recording
                ? 'Grabando ${draft.audioSeconds}s — toca para listo'
                : draft.hasAudio
                    ? 'Nota de voz · ${draft.audioSeconds}s'
                    : 'Grabar un audio',
          ),
        ),
      ],
    );
  }

  Widget _mediaStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        const NeeHeader(
          title: 'Muéstranos el problema',
          subtitle:
              'Agrega fotos o un video para que el profesional entienda mejor.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => _pick(ImageSource.camera, video: false),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Tomar foto'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _pick(ImageSource.camera, video: true),
          icon: const Icon(Icons.videocam_outlined),
          label: const Text('Grabar video'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _pick(ImageSource.gallery, video: false),
          icon: const Icon(Icons.photo_outlined),
          label: const Text('Galería'),
        ),
        const SizedBox(height: 16),
        Text(
          [
            if (draft.photos.isNotEmpty) '${draft.photos.length} fotos',
            if (draft.hasVideo) '1 video',
          ].join(' · ').ifEmpty('Puedes seguir sin media si quieres.'),
          style: const TextStyle(color: NeeColors.muted),
        ),
      ],
    );
  }

  Widget _placeStep() {
    final snap = draft.serviceLocation;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        const NeeHeader(
          title: '¿Dónde será el servicio?',
          subtitle: 'El profesional irá a esta ubicación.',
        ),
        const SizedBox(height: 18),
        Material(
          color: NeeColors.chalk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: NeeColors.soot),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snap == null) ...[
                  const Text(
                    'Todavía no hay un lugar del servicio.',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No usamos automáticamente la dirección de tu cuenta. Elige un lugar guardado o agrega uno nuevo.',
                    style: TextStyle(color: NeeColors.muted),
                  ),
                ] else ...[
                  Text(
                    '${_placeIcon(snap.label)} ${snap.displayTitle}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snap.displayBody,
                    style: const TextStyle(height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    snap.hasCoords
                        ? '📍 Ubicación confirmada'
                        : '📍 Falta confirmar en el mapa',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: snap.hasCoords
                          ? NeeColors.soot
                          : NeeColors.waiting,
                    ),
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final next = await pickServicePlace(
                        context: context,
                        state: widget.state,
                        current: draft.serviceLocation,
                      );
                      if (next == null || !mounted) return;
                      setState(() => draft.applyPlace(next));
                    },
                    child: Text(snap == null ? 'Elegir' : 'Cambiar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _placeIcon(String label) {
    if (label == 'Casa') return '🏠';
    if (label == 'Trabajo') return '💼';
    return '📍';
  }

  Widget _whenStep() {
    final recommended = ServiceSchedule.recommend(
      categoryId: draft.category?.id,
      text: draft.description,
      specialty: draft.specialty,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        const NeeHeader(
          title: '¿Cuándo necesitas el servicio?',
          subtitle: 'Cuéntale a Ñee cuándo te viene bien. Puedes cambiar antes de publicar.',
        ),
        const SizedBox(height: 16),
        SchedulePicker(
          schedule: draft.schedule,
          recommended: recommended,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _confirmStep() {
    final category = draft.category?.name ?? 'Servicio';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        const NeeHeader(title: 'Tu solicitud está lista'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: NeeColors.chalk,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NeeColors.soot),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.specialty.isEmpty ? category : '$category · ${draft.specialty}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                draft.description.isEmpty
                    ? 'Nota de voz'
                    : '“${draft.description}”',
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 12),
              if (draft.photos.isNotEmpty || draft.hasVideo || draft.hasAudio)
                Text(
                  [
                    if (draft.photos.isNotEmpty)
                      '📷 ${draft.photos.length} fotos',
                    if (draft.hasVideo) '🎥 video',
                    if (draft.hasAudio) '🎙️ audio',
                  ].join('   '),
                ),
              const SizedBox(height: 8),
              Text(
                draft.serviceLocation == null
                    ? '📍  ${draft.location}'
                    : '📍  ${draft.serviceLocation!.displayTitle}\n${draft.serviceLocation!.displayBody}',
              ),
              Text(draft.schedule.summary),
            ],
          ),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

class SeekingMatchesScreen extends StatefulWidget {
  const SeekingMatchesScreen({
    super.key,
    required this.state,
    required this.request,
  });

  final NeeAppState state;
  final ServiceRequest request;

  @override
  State<SeekingMatchesScreen> createState() => _SeekingMatchesScreenState();
}

class _SeekingMatchesScreenState extends State<SeekingMatchesScreen> {
  var phase = 0;
  Professional? interested;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      final matches = widget.state.readyToHelp(widget.request.category.id);
      widget.request.interestedCount = matches.length;
      widget.state.ensureOffers(widget.request);
      setState(() => phase = 1);
    });
    Future<void>.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      final matches = widget.state.readyToHelp(widget.request.category.id);
      interested = matches.isEmpty ? null : matches.first;
      setState(() => phase = 2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.state.readyToHelp(widget.request.category.id);
    final available = matches.length;

    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const NeeLogo(height: 32)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (phase == 0) ...[
              const LinearProgressIndicator(
                color: NeeColors.vest,
                backgroundColor: Color(0xFFD8D2C4),
              ),
              const SizedBox(height: 28),
              Text(
                widget.request.schedule?.type == ScheduleType.asap
                    ? 'Buscando profesionales disponibles cerca de ti...'
                    : 'Estamos buscando profesionales para ti…',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Categoría, distancia, disponibilidad y reputación.',
                style: TextStyle(color: NeeColors.muted),
              ),
            ] else ...[
              Text(
                'Encontramos ${widget.request.interestedCount} profesionales cerca de ti.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '$available están disponibles ahora.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (phase >= 2 && interested != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NeeColors.vest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '🔔  ${interested!.name} está interesado en tu solicitud.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => StatusScreen(
                        state: widget.state,
                        request: widget.request,
                      ),
                    ),
                  );
                },
                child: const Text('Ver mi solicitud'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MatchingScreen(
                        state: widget.state,
                        categoryId: widget.request.category.id,
                        request: widget.request,
                        title: 'Propuestas',
                      ),
                    ),
                  );
                },
                child: const Text('Comparar profesionales'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
