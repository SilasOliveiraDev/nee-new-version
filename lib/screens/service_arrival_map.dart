import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/live_location_repository.dart';
import '../models.dart';
import '../theme.dart';

class ServiceArrivalMapScreen extends StatelessWidget {
  const ServiceArrivalMapScreen({
    super.key,
    required this.request,
    required this.professional,
  });

  final ServiceRequest request;
  final Professional professional;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Llegada')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ServiceTrackingMap(
          request: request,
          professional: professional,
          expanded: true,
        ),
      ),
    );
  }
}

class ServiceTrackingMap extends StatefulWidget {
  const ServiceTrackingMap({
    super.key,
    required this.request,
    required this.professional,
    this.expanded = false,
  });

  final ServiceRequest request;
  final Professional professional;
  final bool expanded;

  @override
  State<ServiceTrackingMap> createState() => _ServiceTrackingMapState();
}

class _ServiceTrackingMapState extends State<ServiceTrackingMap> {
  final _map = MapController();
  final _distance = const Distance();
  LiveLocationPin? pin;
  Timer? _poll;
  RealtimeChannel? _live;

  LatLng? get destination {
    final snap = widget.request.serviceLocation;
    if (snap != null && snap.hasCoords) {
      return LatLng(snap.latitude!, snap.longitude!);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    _live = LiveLocationRepository.subscribe(
      professionalId: widget.professional.id,
      onUpdate: (next) {
        if (!mounted) return;
        setState(() => pin = next);
        _fit();
      },
    );
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _live?.unsubscribe();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = await LiveLocationRepository.load(widget.professional.id);
    if (!mounted) return;
    setState(() => pin = next ?? pin);
    _fit();
  }

  void _fit() {
    final dest = destination;
    final pro = pin;
    if (dest == null && pro == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (dest != null && pro != null) {
        final bounds = LatLngBounds.fromPoints([
          LatLng(pro.latitude, pro.longitude),
          dest,
        ]);
        _map.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
        );
        return;
      }
      final only = pro != null
          ? LatLng(pro.latitude, pro.longitude)
          : dest!;
      _map.move(only, 14);
    });
  }

  String? get _eta {
    final dest = destination;
    final pro = pin;
    if (dest == null || pro == null) return null;
    final km = _distance.as(
      LengthUnit.Kilometer,
      LatLng(pro.latitude, pro.longitude),
      dest,
    );
    if (km < 0.05) return 'Está llegando';
    final minutes = (km / 0.35).clamp(1, 90).round();
    if (km < 1) {
      return '${(km * 1000).round()} m · $minutes min';
    }
    return '${km.toStringAsFixed(1)} km · $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final dest = destination;
    final pro = pin;
    final center = dest ??
        (pro != null
            ? LatLng(pro.latitude, pro.longitude)
            : const LatLng(-17.7833, -63.1821));
    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.6,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'nee',
        ),
        MarkerLayer(
          markers: [
            if (dest != null)
              Marker(
                point: dest,
                width: 36,
                height: 36,
                child: const Icon(Icons.place, color: Color(0xFFE23D28), size: 32),
              ),
            if (pro != null)
              Marker(
                point: LatLng(pro.latitude, pro.longitude),
                width: 40,
                height: 40,
                child: CircleAvatar(
                  backgroundColor: NeeColors.vest,
                  foregroundColor: NeeColors.soot,
                  child: Text(
                    widget.professional.initials,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_eta != null || pro != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.request.status == RequestStatus.onTheWay
                  ? (pro?.live == true
                      ? 'En camino · ${_eta ?? 'ubicación en vivo'}'
                      : 'En camino · ${_eta ?? 'última ubicación conocida'}')
                  : (pro?.live == true
                      ? 'Ubicación en vivo'
                      : 'Última ubicación conocida'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        if (widget.expanded)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: map,
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(height: 220, child: map),
          ),
      ],
    );
  }
}
