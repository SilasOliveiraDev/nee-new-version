import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../client/air_query.dart';
import '../client/nee_motion.dart';
import '../client/nee_on_air_tile.dart';
import '../mock_data.dart';
import '../models.dart';
import '../theme.dart';
import 'buscar_servicio_flow.dart';
import 'professional_profile_screen.dart';

class ClientMapScreen extends StatefulWidget {
  const ClientMapScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  State<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends State<ClientMapScreen>
    with AutomaticKeepAliveClientMixin {
  Professional? selected;
  String? categoryId;

  @override
  bool get wantKeepAlive => true;

  List<Professional> get _pins {
    var list = onAirNearby(widget.state.highlightedProfessionals)
        .where((p) => p.hasMapPin)
        .toList();
    if (categoryId != null) {
      list = list.where((p) => p.categoryId == categoryId).toList();
    }
    return list;
  }

  LatLng get _center {
    final loc = widget.state.user.currentLocation;
    if (loc.hasCoords) {
      return LatLng(loc.latitude!, loc.longitude!);
    }
    return const LatLng(-17.7833, -63.1821);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final pins = _pins;
        final pad = MediaQuery.paddingOf(context);
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 13.4,
                  onTap: (_, _) => setState(() => selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'nee',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final pro in pins)
                        Marker(
                          point: LatLng(pro.latitude, pro.longitude),
                          width: 28 + (pro.signal * 22),
                          height: 28 + (pro.signal * 22),
                          child: GestureDetector(
                            onTap: () => setState(() => selected = pro),
                            child: _AirPin(
                              professional: pro,
                              focused: selected?.id == pro.id,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: pad.top + 8,
                left: 16,
                right: 16,
                child: _MapHeader(
                  city: widget.state.user.cityLabel,
                  count: pins.length,
                ),
              ),
              Positioned(
                top: pad.top + 68,
                left: 12,
                right: 12,
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _MapChip(
                      label: 'Todos',
                      selected: categoryId == null,
                      onTap: () => setState(() => categoryId = null),
                    ),
                    const SizedBox(width: 8),
                    for (final cat in categories.take(8)) ...[
                      _MapChip(
                        label: cat.name,
                        selected: categoryId == cat.id,
                        onTap: () => setState(() {
                          categoryId = cat.id;
                          selected = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (pins.isEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, pad.bottom + 24),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(NeeRadii.tile),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Nadie en el aire en este oficio cerca de ti. Prueba otro filtro o busca un servicio.',
                        ),
                      ),
                    ),
                  ),
                )
              else
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, pad.bottom + 12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                      ),
                      child: selected == null
                          ? _PeekList(
                              people: pins.take(3).toList(),
                              onOpen: _openPro,
                              onTune: _tune,
                            )
                          : NeeOnAirTile(
                              professional: selected!,
                              onOpen: () => _openPro(selected!),
                              onQuote: () => _tune(selected!),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openPro(Professional pro) {
    Navigator.of(context).push(
      NeeTunePage(
        child: ProfessionalProfileScreen(
          state: widget.state,
          professional: pro,
        ),
      ),
    );
  }

  Future<void> _tune(Professional pro) {
    final category = categories.firstWhere(
      (c) => c.id == pro.categoryId,
      orElse: () => categories.first,
    );
    return openBuscarServicio(context, state: widget.state, category: category);
  }
}

class _AirPin extends StatelessWidget {
  const _AirPin({required this.professional, required this.focused});

  final Professional professional;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: focused ? 1.12 : 1,
      duration: const Duration(milliseconds: 180),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NeeColors.vest,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: NeeColors.soot.withValues(alpha: 0.22),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
          border: Border.all(
            color: focused ? NeeColors.soot : NeeColors.chalk,
            width: focused ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            professional.initials,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: NeeColors.soot,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.city, required this.count});

  final String city;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(NeeRadii.dial),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, size: 18, weight: 200),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                city,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text('$count cerca', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected
          ? NeeColors.vest
          : Theme.of(context).colorScheme.surface,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: NeeColors.soot,
      ),
    );
  }
}

class _PeekList extends StatelessWidget {
  const _PeekList({
    required this.people,
    required this.onOpen,
    required this.onTune,
  });

  final List<Professional> people;
  final ValueChanged<Professional> onOpen;
  final ValueChanged<Professional> onTune;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        for (final pro in people) ...[
          NeeOnAirTile(
            professional: pro,
            onOpen: () => onOpen(pro),
            onQuote: () => onTune(pro),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
