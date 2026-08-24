import 'package:flutter/material.dart';

import '../app_state.dart';
import '../mock_data.dart';
import '../models.dart';
import '../widgets.dart';
import 'professional_profile_screen.dart';

class MatchingScreen extends StatelessWidget {
  const MatchingScreen({
    super.key,
    required this.state,
    this.request,
    this.categoryId,
    this.title = 'Profesionales',
  });

  final NeeAppState state;
  final ServiceRequest? request;
  final String? categoryId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final id = categoryId ?? request?.category.id ?? '';
    final matches = professionalsReadyToHelp(id, catalog: state.directory);
    final ink = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const NeeHeader(
            title: 'Profesionales destacados',
            subtitle:
                'Solo personas registradas en Ñee y marcadas como destacadas.',
          ),
          const SizedBox(height: 18),
          if (matches.isEmpty)
            Text(
              'Aún no hay profesionales destacados en este oficio. Publica la solicitud y avisamos cuando alguien se sintonice.',
              style: TextStyle(color: ink.withValues(alpha: 0.62), height: 1.4),
            )
          else
            for (final professional in matches) ...[
              ProfessionalCard(
                professional: professional,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (request != null) {
                    state.attachProfessional(request!, professional);
                    Navigator.of(context).pop();
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfessionalProfileScreen(
                        state: state,
                        professional: professional,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
