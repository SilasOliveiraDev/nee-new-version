// THESIS: un solo cuaderno legal, no dos pantallas de muro de texto.
// OWN-WORLD: papel Ñee, pestaña activa en tiza, CTA vest, cuerpo en chalk.
// STORY: el cliente lee términos o privacidad y confirma que entendió.
// FIRST VIEWPORT: título, Ñee Cliente, badge de fecha, tabs, primer artículo.
// FORM: operate / superficie existente Ñee / mockup de Términos y Privacidad.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/account_repository.dart';
import '../legal/legal_document.dart';
import '../theme.dart';

enum LegalTab { terms, privacy }

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, this.slug, this.initialTab});

  final String? slug;
  final LegalTab? initialTab;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late LegalTab _tab;
  LegalDocument? _terms;
  LegalDocument? _privacy;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab ??
        (widget.slug == 'privacy' ? LegalTab.privacy : LegalTab.terms);
    _load();
  }

  Future<void> _load() async {
    final bundledTerms = await rootBundle.loadString('assets/legal/terms.md');
    final bundledPrivacy =
        await rootBundle.loadString('assets/legal/privacy.md');
    var termsText = bundledTerms;
    var privacyText = bundledPrivacy;
    try {
      final remoteTerms = await AccountRepository.loadLegal('terms');
      final remotePrivacy = await AccountRepository.loadLegal('privacy');
      if (remoteTerms != null &&
          remoteTerms.body.trim().length > termsText.trim().length) {
        termsText = remoteTerms.body;
      }
      if (remotePrivacy != null &&
          remotePrivacy.body.trim().length > privacyText.trim().length) {
        privacyText = remotePrivacy.body;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _terms = parseLegalMarkdown(termsText);
      _privacy = parseLegalMarkdown(privacyText);
      _loading = false;
    });
  }

  LegalDocument? get _current =>
      _tab == LegalTab.terms ? _terms : _privacy;

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nee_legal_version', '1.0');
    await prefs.setString(
      'nee_legal_accepted_at',
      DateTime.now().toUtc().toIso8601String(),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _shareCopy() async {
    final doc = _current;
    if (doc == null) return;
    await Clipboard.setData(ClipboardData(text: doc.plainText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copia lista. Pegala en un documento o enviala por correo.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = _current;
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(
        title: const Text('Términos y Privacidad'),
      ),
      body: _loading || doc == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      Text(
                        'Ñee Cliente',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Términos de Servicio y Política de Privacidad',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: NeeColors.muted,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3EBD0),
                            borderRadius: BorderRadius.circular(NeeRadii.pill),
                          ),
                          child: Text(
                            'Última actualización: ${doc.meta.updatedLabel}',
                            style: const TextStyle(
                              color: NeeColors.soot,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LegalTabs(
                        tab: _tab,
                        onChanged: (tab) => setState(() => _tab = tab),
                      ),
                      const SizedBox(height: 14),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8EC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < doc.blocks.length; i++) ...[
                                _LegalBlockView(block: doc.blocks[i]),
                                if (i != doc.blocks.length - 1 &&
                                    doc.blocks[i].kind == LegalBlockKind.heading)
                                  const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _accept,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Entendido y Aceptar'),
                                SizedBox(width: 8),
                                Icon(Icons.check_circle, size: 20),
                              ],
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _shareCopy,
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Descargar copia en PDF'),
                          style: TextButton.styleFrom(
                            foregroundColor: NeeColors.soot,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LegalTabs extends StatelessWidget {
  const _LegalTabs({required this.tab, required this.onChanged});

  final LegalTab tab;
  final ValueChanged<LegalTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NeeColors.chalk,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeeColors.soot.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'Términos de Uso',
              selected: tab == LegalTab.terms,
              onTap: () => onChanged(LegalTab.terms),
            ),
          ),
          Expanded(
            child: _TabChip(
              label: 'Política de Privacidad',
              selected: tab == LegalTab.privacy,
              onTap: () => onChanged(LegalTab.privacy),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF3EBD0) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? NeeColors.soot : NeeColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalBlockView extends StatelessWidget {
  const _LegalBlockView({required this.block});

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    switch (block.kind) {
      case LegalBlockKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.text.isNotEmpty)
                Text(
                  stripLegalMarks(block.text),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.25,
                    color: NeeColors.soot,
                  ),
                ),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: NeeColors.soot.withValues(alpha: 0.08),
              ),
            ],
          ),
        );
      case LegalBlockKind.subheading:
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(
            stripLegalMarks(block.text),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: NeeColors.soot,
            ),
          ),
        );
      case LegalBlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(height: 1.45)),
              Expanded(
                child: Text(
                  stripLegalMarks(block.text),
                  style: const TextStyle(
                    height: 1.45,
                    color: NeeColors.soot,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
        );
      case LegalBlockKind.divider:
        return const SizedBox(height: 12);
      case LegalBlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            stripLegalMarks(block.text),
            style: const TextStyle(
              height: 1.45,
              fontSize: 14.5,
              color: NeeColors.soot,
            ),
          ),
        );
    }
  }
}
