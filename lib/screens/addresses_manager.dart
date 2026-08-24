import 'package:flutter/material.dart';

import '../app_state.dart';
import '../places/geocoding_provider.dart';
import '../places/place_models.dart';
import '../screens/service_place_flow.dart';
import '../theme.dart';
import '../widgets/nee_sheets.dart';

class AddressesManagerScreen extends StatelessWidget {
  const AddressesManagerScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: NeeColors.paper,
          appBar: AppBar(title: const Text('Mis direcciones')),
          body: state.places.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Aún no tienes lugares guardados. Agrega casa, trabajo u otro punto.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NeeColors.muted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    for (final place in state.places) ...[
                      _AddressCard(
                        place: place,
                        onEdit: () => _edit(context, place),
                        onMenu: () => _menu(context, place),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _add(context),
                      icon: const Icon(Icons.add, weight: 200),
                      label: const Text('Agregar dirección'),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _add(BuildContext context) async {
    final snap = await pickServicePlace(context: context, state: state);
    if (snap == null || !context.mounted) return;
    final place = UserPlace(
      id: 'p-${DateTime.now().microsecondsSinceEpoch}',
      type: PlaceType.other,
      customLabel: snap.label.isEmpty ? 'Otro' : snap.label,
      formattedAddress: snap.formattedAddress,
      street: snap.street,
      streetNumber: snap.number,
      neighborhood: snap.neighborhood,
      city: snap.city,
      state: snap.state,
      country: snap.country,
      latitude: snap.latitude,
      longitude: snap.longitude,
      apartment: snap.apartment,
      floor: snap.floor,
      reference: snap.reference,
      isDefault: state.places.isEmpty,
      isLocationConfirmed: snap.hasCoords,
    );
    state.addPlace(place);
    if (!context.mounted) return;
    await showSuccessSheet(
      context,
      title: 'Dirección guardada ✓',
      body: '${place.label} fue agregada a tus lugares. Esto no cambia solicitudes anteriores.',
    );
  }

  Future<void> _edit(BuildContext context, UserPlace place) async {
    final geocoder = NominatimGeocoding();
    final mapped = await Navigator.of(context).push<UserPlace>(
      MaterialPageRoute(
        builder: (_) => ConfirmMapScreen(geocoder: geocoder, initial: place.copy()),
      ),
    );
    var next = mapped ?? place;
    if (!context.mounted) return;
    final detailed = await Navigator.of(context).push<UserPlace>(
      MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: next)),
    );
    if (detailed == null || !context.mounted) return;
    place
      ..street = detailed.street
      ..streetNumber = detailed.streetNumber
      ..neighborhood = detailed.neighborhood
      ..city = detailed.city
      ..floor = detailed.floor
      ..apartment = detailed.apartment
      ..reference = detailed.reference
      ..formattedAddress = detailed.formattedAddress
      ..latitude = detailed.latitude
      ..longitude = detailed.longitude
      ..isLocationConfirmed = detailed.isLocationConfirmed;
    state.updatePlace(place);
    await showSuccessSheet(
      context,
      title: 'Dirección guardada ✓',
      body:
          '${place.label} fue actualizada correctamente. Tus solicitudes anteriores no cambian.',
    );
  }

  Future<void> _menu(BuildContext context, UserPlace place) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NeeColors.chalk,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Editar dirección'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                title: const Text('Establecer como principal'),
                onTap: () => Navigator.pop(context, 'default'),
              ),
              ListTile(
                title: const Text('Cambiar nombre'),
                onTap: () => Navigator.pop(context, 'name'),
              ),
              ListTile(
                title: const Text('Eliminar'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;
    if (action == 'edit') {
      await _edit(context, place);
      return;
    }
    if (action == 'default') {
      state.setDefaultPlace(place);
      return;
    }
    if (action == 'name') {
      final controller = TextEditingController(text: place.label);
      final name = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: NeeColors.chalk,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Nombre del lugar', style: TextStyle(fontWeight: FontWeight.w800)),
                TextField(controller: controller),
                FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          );
        },
      );
      controller.dispose();
      if (name == null || name.isEmpty) return;
      place
        ..type = PlaceType.other
        ..customLabel = name;
      state.updatePlace(place);
      return;
    }
    if (action == 'delete') {
      if (place.isDefault && state.places.length > 1) {
        await showInformationSheet(
          context,
          title: 'Elige otra dirección principal',
          body:
              'Antes de eliminar ${place.label}, define otro lugar como principal.',
        );
        return;
      }
      final ok = await showConfirmationSheet(
        context,
        title: '¿Eliminar esta dirección?',
        body:
            '${place.label} dejará de aparecer entre tus lugares guardados. Esta acción no afectará tus solicitudes anteriores.',
        primary: 'Eliminar',
        secondary: 'Cancelar',
        destructivePrimary: true,
      );
      if (!ok) return;
      await state.removePlace(place);
    }
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.place,
    required this.onEdit,
    required this.onMenu,
  });

  final UserPlace place;
  final VoidCallback onEdit;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NeeColors.chalk,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${place.icon}  ${place.label}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                if (place.isDefault)
                  const Text('Principal', style: TextStyle(color: NeeColors.open)),
                IconButton(
                  onPressed: onMenu,
                  icon: const Icon(Icons.more_horiz, weight: 200),
                ),
              ],
            ),
            Text(place.line1),
            if (place.line2.isNotEmpty)
              Text(place.line2, style: const TextStyle(color: NeeColors.muted)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onEdit, child: const Text('Editar')),
            ),
          ],
        ),
      ),
    );
  }
}
