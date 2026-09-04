import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class NeeCategoryStrip extends StatelessWidget {
  const NeeCategoryStrip({
    super.key,
    required this.categories,
    required this.onTap,
    this.onSeeAll,
  });

  final List<ServiceCategory> categories;
  final ValueChanged<ServiceCategory> onTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final face = Theme.of(context).colorScheme.surface;
    final extra = onSeeAll == null ? 0 : 1;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: categories.length + extra,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (onSeeAll != null && i == categories.length) {
            return SizedBox(
              width: 76,
              child: InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(NeeRadii.tile),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: face,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: ink.withValues(alpha: 0.12)),
                      ),
                      child: Icon(Icons.more_horiz, color: ink, weight: 200),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Más',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final category = categories[i];
          return SizedBox(
            width: 76,
            child: InkWell(
              onTap: () => onTap(category),
              borderRadius: BorderRadius.circular(NeeRadii.tile),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: face,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(category.icon, color: ink, weight: 200, fill: 0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
