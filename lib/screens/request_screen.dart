import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/nee_sheets.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({
    super.key,
    required this.state,
    required this.category,
  });

  final NeeAppState state;
  final ServiceCategory category;

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final description = TextEditingController();
  final location = TextEditingController();

  @override
  void initState() {
    super.initState();
    description.text = widget.category.hint;
    final saved = widget.state.user.fullAddress;
    location.text = saved.isEmpty ? 'Sopocachi, La Paz' : saved;
  }

  @override
  void dispose() {
    description.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedir servicio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          NeeHeader(
            title: widget.category.name,
            subtitle: 'Cuéntanos el problema en palabras simples.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NeeColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: NeeColors.yellow,
                  child: Icon(widget.category.icon, color: NeeColors.ink),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¿Qué está pasando?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: description,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ej: Se está filtrando agua debajo del lavaplatos.',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¿Dónde estás?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: location,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.place_outlined),
              hintText: 'Barrio y ciudad',
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () async {
              final text = description.text.trim();
              final loc = location.text.trim();
              if (text.isEmpty || loc.isEmpty) return;
              if (widget.state.blocksNewSolicitud &&
                  widget.state.createBlock != null) {
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
              final request = widget.state.createRequest(
                category: widget.category,
                description: text,
                location: loc,
              );
              if (!context.mounted) return;
              Navigator.of(context).pop(request);
            },
            child: const Text('Enviar pedido'),
          ),
        ],
      ),
    );
  }
}
