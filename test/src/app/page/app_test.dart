import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/app/page/app.dart';

void main() {
  group('App', () {
    testWidgets('renders App widget', (tester) async {
      await tester.pumpWidget(App());
      expect(find.byType(App), findsOneWidget);
    });
  });
}
