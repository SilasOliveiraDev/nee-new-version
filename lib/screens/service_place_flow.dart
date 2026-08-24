import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../places/geocoding_provider.dart';
import '../places/place_models.dart';
import '../theme.dart';
import '../widgets.dart';

Future<ServiceLocationSnapshot?> pickServicePlace({
  required BuildContext context,
  required NeeAppState state,
  ServiceLocationSnapshot? current,
}) {
  return showModalBottomSheet<ServiceLocationSnapshot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: NeeColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.94,
        child: PlaceHubScreen(state: state, current: current),
      );
    },
  );
}

class PlaceHubScreen extends StatefulWidget {
  const PlaceHubScreen({super.key, required this.state, this.current});

  final NeeAppState state;
  final ServiceLocationSnapshot? current;

  @override
  State<PlaceHubScreen> createState() => _PlaceHubScreenState();
}

class _PlaceHubScreenState extends State<PlaceHubScreen> {
  final geocoder = NominatimGeocoding();

  Future<void> _selectSaved(UserPlace place) async {
    var chosen = place;
    if (!place.hasCoords || !place.isLocationConfirmed) {
      final mapped = await Navigator.of(context).push<UserPlace>(
        MaterialPageRoute(
          builder: (_) => ConfirmMapScreen(geocoder: geocoder, initial: place),
        ),
      );
      if (mapped == null || !mounted) return;
      chosen = mapped;
    }
    if (!chosen.canConfirm) {
      final detailed = await Navigator.of(context).push<UserPlace>(
        MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: chosen)),
      );
      if (detailed == null || !mounted) return;
      chosen = detailed;
    }
    if (!mounted) return;
    Navigator.pop(context, ServiceLocationSnapshot.fromPlace(chosen));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final places = widget.state.places;
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NeeColors.muted,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: NeeHeader(
                title: '¿Dónde será el servicio?',
                subtitle: places.isEmpty
                    ? 'Aún no tienes lugares. Agrega uno o usa el mapa.'
                    : 'Selecciona un lugar guardado o agrega una nueva ubicación.',
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text(
                    'Tus lugares',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (places.isEmpty)
                    const Text(
                      'Cuando guardes Casa, Trabajo u otro lugar, aparecen aquí.',
                      style: TextStyle(color: NeeColors.muted),
                    ),
                  for (final place in places) ...[
                    _PlaceTile(
                      place: place,
                      selected: widget.current?.placeId == place.id,
                      onTap: () => _selectSaved(place),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final created = await Navigator.of(context).push<UserPlace>(
                        MaterialPageRoute(
                          builder: (_) => AddPlaceFlow(state: widget.state),
                        ),
                      );
                      if (created == null || !context.mounted) return;
                      Navigator.pop(
                        context,
                        ServiceLocationSnapshot.fromPlace(created),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('+ Agregar otro lugar'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.onTap,
    required this.selected,
  });

  final UserPlace place;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? NeeColors.vest : NeeColors.chalk,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: NeeColors.soot, width: selected ? 2 : 1),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Text(place.icon, style: const TextStyle(fontSize: 22)),
        title: Text(
          place.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [place.listSubtitle, place.city].where((e) => e.isNotEmpty).toSet().join('\n'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (place.isDefault)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(
                  'Principal',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class AddPlaceFlow extends StatefulWidget {
  const AddPlaceFlow({super.key, required this.state});

  final NeeAppState state;

  @override
  State<AddPlaceFlow> createState() => _AddPlaceFlowState();
}

class _AddPlaceFlowState extends State<AddPlaceFlow> {
  final geocoder = NominatimGeocoding();
  final search = TextEditingController();
  Timer? _debounce;
  var loading = false;
  String? error;
  var emptySearch = false;
  List<PlaceSuggestion> results = [];

  @override
  void dispose() {
    search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (value.trim().length < 3) {
        setState(() {
          results = [];
          emptySearch = false;
        });
        return;
      }
      setState(() {
        loading = true;
        error = null;
        emptySearch = false;
      });
      try {
        final found = await geocoder.search(value);
        if (!mounted) return;
        setState(() {
          results = found;
          loading = false;
          emptySearch = found.isEmpty;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          loading = false;
          error = 'No se pudo buscar. Prueba el mapa o tu ubicación.';
        });
      }
    });
  }

  Future<void> _openMap(UserPlace seed) async {
    final confirmed = await Navigator.of(context).push<UserPlace>(
      MaterialPageRoute(
        builder: (_) => ConfirmMapScreen(geocoder: geocoder, initial: seed),
      ),
    );
    if (confirmed == null || !mounted) return;
    final detailed = await Navigator.of(context).push<UserPlace>(
      MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: confirmed)),
    );
    if (detailed == null || !mounted) return;
    final saved = await Navigator.of(context).push<UserPlace>(
      MaterialPageRoute(
        builder: (_) => SavePlaceScreen(state: widget.state, place: detailed),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, saved ?? detailed);
  }

  Future<void> _useGps() async {
    setState(() {
      loading = true;
      error = null;
    });
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() {
        loading = false;
        error = 'Activa el GPS para usar tu ubicación, o busca la dirección.';
      });
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        loading = false;
        error =
            'Sin permiso de ubicación. Puedes buscar la dirección o elegirla en el mapa.';
      });
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      UserPlace place;
      try {
        place = await geocoder.reverse(position.latitude, position.longitude);
      } catch (_) {
        place = UserPlace(
          id: 'tmp',
          latitude: position.latitude,
          longitude: position.longitude,
          city: widget.state.user.currentLocation.city,
          country: 'Bolivia',
        );
      }
      place.locationAccuracy = position.accuracy;
      if (position.accuracy > 80) {
        error = 'La precisión es baja. Ajusta el pin en el mapa.';
      }
      if (!mounted) return;
      setState(() => loading = false);
      await _openMap(place);
    } on TimeoutException {
      setState(() {
        loading = false;
        error = 'Tardó demasiado. Busca la dirección o elige en el mapa.';
      });
    } catch (_) {
      setState(() {
        loading = false;
        error = 'No se obtuvo la ubicación. Usa búsqueda o el mapa.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Busca la dirección')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          TextField(
            controller: search,
            onChanged: _onQuery,
            decoration: const InputDecoration(
              hintText: 'Calle, avenida, edificio o lugar...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(color: NeeColors.vest),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: NeeColors.waiting)),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: loading ? null : _useGps,
            icon: const Icon(Icons.my_location),
            label: const Text('Usar mi ubicación actual'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              final geo = widget.state.user.registeredAddress;
              _openMap(
                UserPlace(
                  id: 'tmp',
                  city: geo.city.isEmpty ? 'Bolivia' : geo.city,
                  country: geo.country.isEmpty ? 'Bolivia' : geo.country,
                  latitude: geo.latitude ?? -16.2902,
                  longitude: geo.longitude ?? -63.5887,
                ),
              );
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Seleccionar en el mapa'),
          ),
          const SizedBox(height: 16),
          if (emptySearch)
            const Text(
              'Sin resultados. Prueba con calle y ciudad, o el mapa.',
              style: TextStyle(color: NeeColors.muted),
            ),
          for (final item in results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(item.title),
              subtitle: Text(item.subtitle, maxLines: 2),
              onTap: () {
                _openMap(
                  UserPlace(
                    id: 'tmp',
                    formattedAddress: item.subtitle,
                    street: item.street,
                    streetNumber: item.number,
                    neighborhood: item.neighborhood,
                    city: item.city,
                    state: item.state,
                    country: item.country,
                    postalCode: item.postalCode,
                    latitude: item.latitude,
                    longitude: item.longitude,
                    placeId: item.placeId,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class ConfirmMapScreen extends StatefulWidget {
  const ConfirmMapScreen({
    super.key,
    required this.geocoder,
    required this.initial,
  });

  final GeocodingProvider geocoder;
  final UserPlace initial;

  @override
  State<ConfirmMapScreen> createState() => _ConfirmMapScreenState();
}

class _ConfirmMapScreenState extends State<ConfirmMapScreen> {
  late UserPlace place;
  final map = MapController();
  var reverseLoading = false;
  String? error;
  Timer? _moveDebounce;

  @override
  void initState() {
    super.initState();
    place = widget.initial.copy();
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _reverse(LatLng center) async {
    setState(() {
      reverseLoading = true;
      error = null;
      place.latitude = center.latitude;
      place.longitude = center.longitude;
    });
    try {
      final updated = await widget.geocoder.reverse(
        center.latitude,
        center.longitude,
      );
      if (!mounted) return;
      setState(() {
        place
          ..formattedAddress = updated.formattedAddress
          ..street = updated.street
          ..streetNumber = updated.streetNumber
          ..neighborhood = updated.neighborhood
          ..city = updated.city
          ..state = updated.state
          ..country = updated.country
          ..postalCode = updated.postalCode
          ..geocodingProvider = updated.geocodingProvider;
        reverseLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        reverseLoading = false;
        error = 'No se leyó la dirección. Puedes editarla en el siguiente paso.';
      });
    }
  }

  Future<void> _useGps() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => error = 'Activa el GPS o mueve el mapa a mano.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(
        () => error =
            'Sin permiso de ubicación. Mueve el mapa o busca otra dirección.',
      );
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final next = LatLng(position.latitude, position.longitude);
      map.move(next, 16);
      place.locationAccuracy = position.accuracy;
      await _reverse(next);
    } on TimeoutException {
      setState(() => error = 'Tardó demasiado. Mueve el mapa a mano.');
    } catch (_) {
      setState(() => error = 'No se obtuvo GPS. Mueve el mapa o busca.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      place.latitude ?? -16.2902,
      place.longitude ?? -63.5887,
    );
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Confirmar ubicación')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: place.hasCoords ? 16 : 5.2,
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd) {
                        _moveDebounce?.cancel();
                        _moveDebounce = Timer(
                          const Duration(milliseconds: 400),
                          () => _reverse(event.camera.center),
                        );
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'nee',
                    ),
                  ],
                ),
                const IgnorePointer(
                  child: Icon(Icons.location_on, size: 44, color: NeeColors.vest),
                ),
                if (reverseLoading)
                  const Positioned(
                    top: 12,
                    child: Chip(label: Text('Actualizando dirección…')),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Mueve el mapa para indicar exactamente dónde será el servicio.',
                  style: TextStyle(color: NeeColors.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  place.formattedAddress.isEmpty
                      ? place.line1
                      : place.formattedAddress,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (error != null) Text(error!, style: const TextStyle(color: NeeColors.waiting)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    place.isLocationConfirmed = place.hasCoords;
                    Navigator.pop(context, place);
                  },
                  child: const Text('Usar esta ubicación'),
                ),
                TextButton.icon(
                  onPressed: _useGps,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Usar mi ubicación actual'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceDetailsScreen extends StatefulWidget {
  const PlaceDetailsScreen({super.key, required this.place});

  final UserPlace place;

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  late final street = TextEditingController(text: widget.place.street);
  late final number = TextEditingController(text: widget.place.streetNumber);
  late final floor = TextEditingController(
    text: [
      if (widget.place.floor.isNotEmpty) widget.place.floor,
      if (widget.place.apartment.isNotEmpty) widget.place.apartment,
    ].join(' — '),
  );
  late final zone = TextEditingController(text: widget.place.neighborhood);
  late final city = TextEditingController(text: widget.place.city);
  late final reference = TextEditingController(text: widget.place.reference);
  String? error;

  @override
  void dispose() {
    street.dispose();
    number.dispose();
    floor.dispose();
    zone.dispose();
    city.dispose();
    reference.dispose();
    super.dispose();
  }

  void _confirm() {
    widget.place
      ..street = street.text.trim()
      ..streetNumber = number.text.trim()
      ..neighborhood = zone.text.trim()
      ..city = city.text.trim()
      ..reference = reference.text.trim()
      ..floor = floor.text.trim()
      ..formattedAddress = [
        street.text.trim(),
        number.text.trim(),
        zone.text.trim(),
        city.text.trim(),
      ].where((e) => e.isNotEmpty).join(', ')
      ..isLocationConfirmed = widget.place.hasCoords;
    if (!widget.place.canConfirm &&
        (widget.place.city.isEmpty || !widget.place.hasCoords)) {
      setState(() {
        error =
            'Falta ciudad o coordenadas. Vuelve al mapa o completa la ciudad.';
      });
      return;
    }
    Navigator.pop(context, widget.place);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Detalles del lugar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text('Dirección', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          TextField(controller: street, decoration: const InputDecoration(hintText: 'Av. San Martín')),
          const SizedBox(height: 12),
          const Text('Número', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          TextField(
            controller: number,
            decoration: const InputDecoration(hintText: 'Número de casa / edificio'),
          ),
          const SizedBox(height: 12),
          const Text('Piso / Departamento (opcional)', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          TextField(
            controller: floor,
            decoration: const InputDecoration(hintText: 'Piso 4 — Dpto. 4B'),
          ),
          const SizedBox(height: 12),
          const Text('Barrio / Zona', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          TextField(controller: zone),
          const SizedBox(height: 12),
          const Text('Ciudad', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          TextField(controller: city),
          const SizedBox(height: 12),
          const Text('Referencia (opcional)', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          TextField(
            controller: reference,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Agrega una referencia para ayudar al profesional a encontrarte.',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: NeeColors.waiting)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _confirm,
            child: const Text('Confirmar ubicación'),
          ),
        ],
      ),
    );
  }
}

class SavePlaceScreen extends StatefulWidget {
  const SavePlaceScreen({super.key, required this.state, required this.place});

  final NeeAppState state;
  final UserPlace place;

  @override
  State<SavePlaceScreen> createState() => _SavePlaceScreenState();
}

class _SavePlaceScreenState extends State<SavePlaceScreen> {
  PlaceType? type;
  final name = TextEditingController();
  var saving = false;
  var asDefault = false;
  String? error;

  @override
  void initState() {
    super.initState();
    asDefault = widget.state.places.isEmpty;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (type == null) {
      setState(() => error = 'Elige Casa, Trabajo u Otro, o no guardar.');
      return;
    }
    if (type == PlaceType.other && name.text.trim().isEmpty) {
      setState(() => error = 'Ponle un nombre a este lugar.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final place = widget.place.copy()
      ..id = DateTime.now().millisecondsSinceEpoch.toString()
      ..type = type!
      ..customLabel = name.text.trim()
      ..isDefault = asDefault;
    try {
      widget.state.addPlace(place);
      if (!mounted) return;
      Navigator.pop(context, place);
    } catch (_) {
      setState(() {
        saving = false;
        error = 'No se pudo guardar. Puedes continuar sin guardar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('¿Quieres guardar este lugar?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _option(PlaceType.home, '🏠  Casa'),
          _option(PlaceType.work, '💼  Trabajo'),
          _option(PlaceType.other, '📍  Otro'),
          if (type == PlaceType.other) ...[
            const SizedBox(height: 12),
            const Text('Nombre del lugar', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(
              controller: name,
              decoration: const InputDecoration(hintText: 'Casa de mamá'),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: NeeColors.waiting)),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dirección principal'),
            subtitle: const Text(
              'La usaremos al crear una solicitud. Siempre puedes cambiarla.',
            ),
            value: asDefault,
            onChanged: (value) => setState(() => asDefault = value),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : _save,
            child: Text(saving ? 'Guardando…' : 'Guardar lugar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, widget.place),
            child: const Text('No guardar'),
          ),
        ],
      ),
    );
  }

  Widget _option(PlaceType value, String label) {
    final selected = type == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? NeeColors.vest : NeeColors.chalk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: NeeColors.soot, width: selected ? 2 : 1),
        ),
        child: ListTile(
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          onTap: () => setState(() => type = value),
        ),
      ),
    );
  }
}
