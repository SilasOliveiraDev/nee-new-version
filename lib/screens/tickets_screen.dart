import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/engagement_repository.dart';
import '../domain/engagement.dart';
import '../theme.dart';
import '../widgets/nee_sheets.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  var tickets = <SupportTicket>[];
  var loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await EngagementRepository.loadTickets();
    if (!mounted) return;
    setState(() {
      tickets = list;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Mis tickets')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const Text(
                  'Si algo no sale como esperabas, déjalo acá. El equipo de Ñee lee cada ticket.',
                  style: TextStyle(color: NeeColors.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => NewTicketScreen(state: widget.state),
                      ),
                    );
                    if (created == true) await _reload();
                  },
                  child: const Text('Abrir un ticket'),
                ),
                const SizedBox(height: 20),
                if (tickets.isEmpty)
                  const Text(
                    'Todavía no tienes tickets.',
                    style: TextStyle(color: NeeColors.muted),
                  )
                else
                  for (final ticket in tickets) ...[
                    Material(
                      color: NeeColors.chalk,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        title: Text(
                          ticket.subject,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${ticket.categoryLabel} · ${ticket.statusLabel}',
                        ),
                        trailing: const Icon(Icons.chevron_right, weight: 200),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TicketDetailScreen(ticket: ticket),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
    );
  }
}

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key, required this.state});

  final NeeAppState state;

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final subject = TextEditingController();
  final body = TextEditingController();
  var category = 'SERVICE';
  var sending = false;

  static const categories = [
    ('SERVICE', 'Un servicio'),
    ('ACCOUNT', 'Mi cuenta'),
    ('APP', 'La aplicación'),
    ('PAY', 'Pago'),
    ('GENERAL', 'Otro'),
  ];

  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (subject.text.trim().isEmpty || body.text.trim().isEmpty) return;
    setState(() => sending = true);
    final ticket = await EngagementRepository.createTicket(
      subject: subject.text.trim(),
      category: category,
      body: body.text.trim(),
    );
    if (!mounted) return;
    setState(() => sending = false);
    if (ticket == null) {
      await showErrorSheet(
        context,
        title: 'No se pudo enviar',
        body: 'Inténtalo de nuevo en un momento.',
      );
      return;
    }
    await widget.state.completeChallenge('escribir_soporte');
    if (!mounted) return;
    await showSuccessSheet(
      context,
      title: 'Ticket enviado ✓',
      body: 'Ñee recibió tu mensaje. Te avisaremos cuando haya novedades.',
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Nuevo ticket')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            '¿De qué se trata?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in categories)
                ChoiceChip(
                  label: Text(item.$2),
                  selected: category == item.$1,
                  onSelected: (_) => setState(() => category = item.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: subject,
            decoration: const InputDecoration(labelText: 'Asunto'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: body,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Cuéntanos qué pasó',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: sending ? null : _send,
            child: Text(sending ? 'Enviando…' : 'Enviar ticket'),
          ),
        ],
      ),
    );
  }
}

class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen({super.key, required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Ticket')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            ticket.subject,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${ticket.categoryLabel} · ${ticket.statusLabel}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(ticket.body, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }
}
