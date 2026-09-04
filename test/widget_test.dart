import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nee/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('Splash and value proposition appear before role choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NeeApp());
    await tester.pump();
    expect(find.text('El oficio que necesitas, cerca de ti.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 2100));

    expect(
      find.textContaining('Alguien cerca'),
      findsOneWidget,
    );
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Explorar sin cuenta'), findsOneWidget);
    expect(find.text('Empezar'), findsNothing);
    expect(find.text('Necesito un servicio'), findsNothing);
  });
}
