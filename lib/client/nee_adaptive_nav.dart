import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

enum NeeNavGlyph { home, map, list, chat, person, bell, work, clock }

class NeeTabSpec {
  const NeeTabSpec({
    required this.label,
    required this.glyph,
    this.badge = 0,
  });

  final String label;
  final NeeNavGlyph glyph;
  final int badge;
}

class NeeAdaptiveNav extends StatelessWidget {
  const NeeAdaptiveNav({
    super.key,
    required this.index,
    required this.onChange,
    required this.tabs,
  });

  final int index;
  final ValueChanged<int> onChange;
  final List<NeeTabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: NeeColors.chalk,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0x1A3A3328), width: 1),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 6 + bottom),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    spec: tabs[i],
                    selected: i == index,
                    onTap: () => onChange(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final NeeTabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NeeColors.soot : NeeColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: NeeColors.vest.withValues(alpha: 0.18),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: const Size(24, 24),
                    painter: _GlyphPainter(glyph: spec.glyph, color: color),
                  ),
                  if (spec.badge > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE23D28),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          spec.badge > 9 ? '9+' : '${spec.badge}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 14 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: NeeColors.vest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.glyph, required this.color});

  final NeeNavGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final w = size.width;
    final h = size.height;
    switch (glyph) {
      case NeeNavGlyph.home:
        final path = Path()
          ..moveTo(w * 0.18, h * 0.52)
          ..lineTo(w * 0.5, h * 0.2)
          ..lineTo(w * 0.82, h * 0.52)
          ..moveTo(w * 0.26, h * 0.48)
          ..lineTo(w * 0.26, h * 0.82)
          ..lineTo(w * 0.74, h * 0.82)
          ..lineTo(w * 0.74, h * 0.48);
        canvas.drawPath(path, paint);
      case NeeNavGlyph.map:
        final pin = Path()
          ..moveTo(w * 0.5, h * 0.86)
          ..cubicTo(w * 0.22, h * 0.6, w * 0.18, h * 0.38, w * 0.5, h * 0.18)
          ..cubicTo(w * 0.82, h * 0.38, w * 0.78, h * 0.6, w * 0.5, h * 0.86);
        canvas.drawPath(pin, paint);
        canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.11, paint);
      case NeeNavGlyph.list:
        for (final y in [0.28, 0.5, 0.72]) {
          canvas.drawLine(Offset(w * 0.2, h * y), Offset(w * 0.8, h * y), paint);
        }
      case NeeNavGlyph.chat:
        canvas.drawRRect(
          RRect.fromLTRBR(
            w * 0.16,
            h * 0.2,
            w * 0.84,
            h * 0.68,
            const Radius.circular(6),
          ),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.36, h * 0.68),
          Offset(w * 0.28, h * 0.84),
          paint,
        );
      case NeeNavGlyph.person:
        canvas.drawCircle(Offset(w * 0.5, h * 0.32), w * 0.16, paint);
        final body = Path()
          ..moveTo(w * 0.22, h * 0.84)
          ..quadraticBezierTo(w * 0.5, h * 0.5, w * 0.78, h * 0.84);
        canvas.drawPath(body, paint);
      case NeeNavGlyph.bell:
        final bell = Path()
          ..moveTo(w * 0.28, h * 0.42)
          ..cubicTo(w * 0.28, h * 0.2, w * 0.72, h * 0.2, w * 0.72, h * 0.42)
          ..lineTo(w * 0.72, h * 0.62)
          ..lineTo(w * 0.82, h * 0.72)
          ..lineTo(w * 0.18, h * 0.72)
          ..lineTo(w * 0.28, h * 0.62)
          ..close();
        canvas.drawPath(bell, paint);
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.72),
            width: w * 0.22,
            height: h * 0.18,
          ),
          0,
          3.14,
          false,
          paint,
        );
      case NeeNavGlyph.work:
        canvas.drawRRect(
          RRect.fromLTRBR(
            w * 0.16,
            h * 0.38,
            w * 0.84,
            h * 0.82,
            const Radius.circular(3),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(
            w * 0.38,
            h * 0.18,
            w * 0.62,
            h * 0.38,
            const Radius.circular(2),
          ),
          paint,
        );
      case NeeNavGlyph.clock:
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.32, paint);
        canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5, h * 0.32), paint);
        canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.68, h * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph || oldDelegate.color != color;
  }
}
