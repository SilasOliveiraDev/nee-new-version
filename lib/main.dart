import 'package:flutter/material.dart';

import 'app_state.dart';
import 'data/nee_supabase.dart';
import 'screens/client_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NeeSupabase.init();
  runApp(const NeeApp());
}

/// THESIS: Liberado is on-air. Home is the band, Mapa is the dial. Refuses the blue marketplace card grid.
/// OWN-WORLD: Kitchen radio on paper, vest yellow only when lit, soot ink, chalk faceplate, pills not boxes, signal by distance.
/// STORY: See who is on air nearby, tune the map, park a solicitud in the call queue.
/// FIRST VIEWPORT: City + logo, yellow sintonía with first name, oficio chips, En el aire cerca ranked by signal, five tabs with Mapa.
/// FORM: Radio de barrio, assigned, seed 540e61a6.
/// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
class NeeApp extends StatefulWidget {
  const NeeApp({super.key});

  @override
  State<NeeApp> createState() => _NeeAppState();
}

class _NeeAppState extends State<NeeApp> {
  final state = NeeAppState();

  @override
  void initState() {
    super.initState();
    state.hydrate();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ñee!',
      debugShowCheckedModeBanner: false,
      theme: NeeTheme.light(),
      themeMode: ThemeMode.light,
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (!state.hydrated) {
            return const Scaffold(
              backgroundColor: NeeColors.paper,
              body: Center(child: NeeLogo(height: 148, lockup: true)),
            );
          }
          if (state.needsOnboarding) {
            return OnboardingScreen(state: state);
          }
          return ClientShell(state: state);
        },
      ),
    );
  }
}
