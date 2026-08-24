import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'domain/request_lifecycle.dart';
import 'models.dart';
import 'theme.dart';

class NeeLogo extends StatelessWidget {
  const NeeLogo({
    super.key,
    this.height = 48,
    this.lockup = false,
  });

  final double height;
  final bool lockup;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      lockup
          ? 'assets/brand/nee-logo-lockup.png'
          : 'assets/brand/nee-logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Ñee!',
    );
  }
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  final ServiceCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NeeColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: NeeColors.yellow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(category.icon, color: NeeColors.ink, size: 26, weight: 200, fill: 0),
              ),
              const Spacer(),
              Text(
                category.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.hint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NeeColors.muted,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfessionalCard extends StatelessWidget {
  const ProfessionalCard({
    super.key,
    required this.professional,
    this.trailing,
    this.onTap,
  });

  final Professional professional;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(NeeRadii.tile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NeeRadii.tile),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: NeeColors.yellow,
                child: Text(
                  professional.initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: NeeColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      professional.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      professional.specialty,
                      style: const TextStyle(color: NeeColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${professional.city}  ·  ★ ${professional.rating}  ·  ${professional.jobs} servicios',
                      style: const TextStyle(
                        fontSize: 12,
                        color: NeeColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.current});

  final RequestStatus current;

  @override
  Widget build(BuildContext context) {
    final steps = RequestLifecycle.steps(current);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepRow(
            label: steps[i].label,
            done: steps[i].done,
            isCurrent: steps[i].current,
            isLast: i == steps.length - 1,
          ),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.isCurrent,
    required this.isLast,
  });

  final String label;
  final bool done;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCurrent
                    ? NeeColors.yellow
                    : done
                        ? NeeColors.yellow
                        : const Color(0xFFE8E0C8),
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: NeeColors.ink, width: 2)
                    : null,
              ),
              child: done
                  ? const Icon(Icons.check, size: 14, weight: 200, color: NeeColors.ink)
                  : isCurrent
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: NeeColors.ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 28,
                color: done ? NeeColors.yellow : const Color(0xFFE8E0C8),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
              fontSize: 15,
              color: done ? NeeColors.ink : NeeColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class NeeHeader extends StatelessWidget {
  const NeeHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: NeeColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.user,
    this.radius = 28,
  });

  final UserAccount user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = user.photoBytes;
    return CircleAvatar(
      radius: radius,
      backgroundColor: NeeColors.yellow,
      backgroundImage: photo == null ? null : MemoryImage(photo),
      child: photo == null
          ? Text(
              user.initials,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: NeeColors.ink,
                fontSize: radius * 0.55,
              ),
            )
          : null,
    );
  }
}

class PhotoCircleButton extends StatelessWidget {
  const PhotoCircleButton({
    super.key,
    required this.bytes,
    required this.initials,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: NeeColors.yellow,
            backgroundImage: bytes == null ? null : MemoryImage(bytes!),
            child: bytes == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: NeeColors.ink,
                    ),
                  )
                : null,
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: NeeColors.ink,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              color: NeeColors.yellow,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
