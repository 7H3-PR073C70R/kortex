import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/app/page/app.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    initLocator();
    if (locator.isRegistered<NotificationService>()) {
      await locator.unregister<NotificationService>();
    }
    final mockNotification = MockNotificationService();
    when(() => mockNotification.onPayloadTapped)
        .thenAnswer((_) => const Stream.empty());
    when(mockNotification.checkAndTriggerDueReminders)
        .thenAnswer((_) async {});
    locator.registerSingleton<NotificationService>(mockNotification);
  });

  group('App', () {
    testWidgets('renders App widget', (tester) async {
      await tester.pumpWidget(const App());
      expect(find.byType(App), findsOneWidget);
    });
  });
}
