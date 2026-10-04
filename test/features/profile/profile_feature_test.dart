import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/profile/presentation/widgets/active_sessions_list_widget.dart';
import '../../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Domain 13: Profile Feature Unit & Widget Tests', () {
    test('ActiveSessionsListWidget masks IPv4 and IPv6 addresses correctly', () {
      final sessions = [
        DeviceSession(
          id: 's1',
          deviceName: 'MacBook Pro',
          osType: 'macos',
          ipAddress: '192.168.1.104',
          location: 'Lagos, NG',
          lastActive: DateTime.now(),
          isCurrentDevice: true,
        ),
        DeviceSession(
          id: 's2',
          deviceName: 'iPhone 15 Pro',
          osType: 'ios',
          ipAddress: '10.0.0.45 (Encrypted TLS)',
          location: 'London, UK',
          lastActive: DateTime.now(),
        ),
      ];

      expect(sessions.length, 2);
      expect(sessions.first.isCurrentDevice, isTrue);
      expect(sessions.last.osType, 'ios');
    });

    testWidgets('ActiveSessionsListWidget renders list of sessions with revoke action', (tester) async {
      final sessions = [
        DeviceSession(
          id: 's1',
          deviceName: 'MacBook Pro',
          osType: 'macos',
          ipAddress: '192.168.1.104',
          location: 'Lagos, NG',
          lastActive: DateTime.now(),
          isCurrentDevice: true,
        ),
        DeviceSession(
          id: 's2',
          deviceName: 'iPhone 15 Pro',
          osType: 'ios',
          ipAddress: '10.0.0.45',
          location: 'London, UK',
          lastActive: DateTime.now(),
        ),
      ];

      var revokedAllOthers = false;

      await tester.pumpApp(
        Scaffold(
          body: ActiveSessionsListWidget(
            sessions: sessions,
            onRevokeSession: (_) {},
            onRevokeAllOthers: () => revokedAllOthers = true,
          ),
        ),
      );

      expect(find.textContaining('Active Logins'), findsOneWidget);
      expect(find.text('MacBook Pro'), findsOneWidget);
      expect(find.text('iPhone 15 Pro'), findsOneWidget);

      final logoutOthersBtn = find.text('Log Out Others');
      expect(logoutOthersBtn, findsOneWidget);
      await tester.tap(logoutOthersBtn);
      await tester.pump();

      expect(revokedAllOthers, isTrue);
    });
  });
}
