import 'package:flutter/material.dart';

import '../theme.dart';

bool neeReduceMotion(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context);
}

/// Shared-axis fade for stacks. Not an entrance show.
class NeeTunePage<T> extends PageRouteBuilder<T> {
  NeeTunePage({required Widget child})
      : super(
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (context, animation, secondary) => child,
          transitionsBuilder: (context, animation, secondary, child) {
            if (MediaQuery.disableAnimationsOf(context)) {
              return child;
            }
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        );
}

class NeeSeekScrim extends StatelessWidget {
  const NeeSeekScrim({super.key, required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final t = progress.value;
          return Align(
            alignment: Alignment(0, -0.2 + (t * 0.35)),
            child: Opacity(
              opacity: (1 - t) * 0.9,
              child: Container(
                width: 12 + (t * 120),
                height: 4,
                decoration: BoxDecoration(
                  color: NeeColors.vest,
                  borderRadius: BorderRadius.circular(NeeRadii.pill),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
