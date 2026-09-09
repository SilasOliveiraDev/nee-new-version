class LegalMeta {
  const LegalMeta({
    required this.updatedLabel,
    required this.version,
  });

  final String updatedLabel;
  final String version;
}

class LegalBlock {
  const LegalBlock({required this.kind, required this.text});

  final LegalBlockKind kind;
  final String text;
}

enum LegalBlockKind { heading, subheading, paragraph, bullet, divider }

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.meta,
    required this.blocks,
    required this.plainText,
  });

  final String title;
  final LegalMeta meta;
  final List<LegalBlock> blocks;
  final String plainText;
}

LegalDocument parseLegalMarkdown(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  var title = 'Ñee!';
  var updated = '3 de septiembre de 2026';
  var version = '1.0';
  final blocks = <LegalBlock>[];
  final paragraph = StringBuffer();

  void flushParagraph() {
    final text = paragraph.toString().trim();
    paragraph.clear();
    if (text.isEmpty) return;
    blocks.add(LegalBlock(kind: LegalBlockKind.paragraph, text: text));
  }

  for (final original in lines) {
    final line = original.trimRight();
    final trimmed = line.trim();
    if (trimmed.startsWith('# ') && !trimmed.startsWith('##')) {
      title = trimmed.substring(2).trim();
      continue;
    }
    if (trimmed.startsWith('**Última actualización:**')) {
      updated = trimmed.replaceFirst('**Última actualización:**', '').trim();
      continue;
    }
    if (trimmed.startsWith('**Versión:**')) {
      version = trimmed.replaceFirst('**Versión:**', '').trim();
      continue;
    }
    if (trimmed == '---') {
      flushParagraph();
      blocks.add(const LegalBlock(kind: LegalBlockKind.divider, text: ''));
      continue;
    }
    if (trimmed.startsWith('### ')) {
      flushParagraph();
      blocks.add(
        LegalBlock(kind: LegalBlockKind.subheading, text: trimmed.substring(4).trim()),
      );
      continue;
    }
    if (trimmed.startsWith('## ')) {
      flushParagraph();
      blocks.add(
        LegalBlock(kind: LegalBlockKind.heading, text: trimmed.substring(3).trim()),
      );
      continue;
    }
    if (trimmed.startsWith('* ')) {
      flushParagraph();
      blocks.add(
        LegalBlock(kind: LegalBlockKind.bullet, text: trimmed.substring(2).trim()),
      );
      continue;
    }
    if (trimmed.isEmpty) {
      flushParagraph();
      continue;
    }
    if (paragraph.isNotEmpty) paragraph.write(' ');
    paragraph.write(trimmed);
  }
  flushParagraph();

  return LegalDocument(
    title: title,
    meta: LegalMeta(updatedLabel: updated, version: version),
    blocks: blocks,
    plainText: raw.trim(),
  );
}

String stripLegalMarks(String text) {
  return text.replaceAll('**', '');
}
