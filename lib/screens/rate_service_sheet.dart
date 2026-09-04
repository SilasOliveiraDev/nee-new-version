import 'package:flutter/material.dart';

import '../domain/review_criteria.dart';
import '../theme.dart';

Future<({ReviewScores scores, String comment})?> showRateServiceSheet(
  BuildContext context, {
  required String professionalName,
}) {
  return showModalBottomSheet<({ReviewScores scores, String comment})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NeeColors.chalk,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _RateServiceSheet(professionalName: professionalName),
  );
}

class _RateServiceSheet extends StatefulWidget {
  const _RateServiceSheet({required this.professionalName});

  final String professionalName;

  @override
  State<_RateServiceSheet> createState() => _RateServiceSheetState();
}

class _RateServiceSheetState extends State<_RateServiceSheet> {
  var scores = ReviewScores.empty;
  final comment = TextEditingController();

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final first = widget.professionalName.trim().split(RegExp(r'\s+')).first;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + pad.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NeeColors.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Califica a $first',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cinco estrellas en cada punto. Así otras personas saben cómo trabaja, no solo si “fue bien”.',
              style: TextStyle(height: 1.4, color: NeeColors.muted),
            ),
            const SizedBox(height: 18),
            for (final item in ReviewCriteria.items) ...[
              _CriteriaStars(
                criterion: item,
                value: scores.valueFor(item.id),
                onChanged: (stars) {
                  setState(() => scores = scores.withValue(item.id, stars));
                },
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: comment,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: scores.isComplete
                  ? () => Navigator.pop(context, (
                        scores: scores,
                        comment: comment.text,
                      ))
                  : null,
              child: Text(
                scores.isComplete
                    ? 'Enviar calificación · ${scores.overall.toStringAsFixed(1)}'
                    : 'Marca las 5 estrellas en cada punto',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CriteriaStars extends StatelessWidget {
  const _CriteriaStars({
    required this.criterion,
    required this.value,
    required this.onChanged,
  });

  final ReviewCriterion criterion;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          criterion.label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          criterion.hint,
          style: const TextStyle(color: NeeColors.muted, height: 1.3),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: () => onChanged(i),
                icon: Icon(
                  i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i <= value ? NeeColors.yellowDeep : NeeColors.muted,
                  size: 32,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
