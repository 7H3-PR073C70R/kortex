import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/app/page/app.dart';
import 'package:kortex/src/di/locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(initLocator);

  group('App', () {
    testWidgets('renders App widget', (tester) async {
      await tester.pumpWidget(App());
      expect(find.byType(App), findsOneWidget);
    });
  });
}
