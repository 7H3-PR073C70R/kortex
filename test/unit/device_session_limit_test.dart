import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/shared/widgets/device_limit_modal_sheet.dart';

void main() {
  group('P2-03 Device Session Limit & Auto-Expiration Tests', () {
    test('DeviceLimitExceededException is converted to DeviceLimitExceededFailure by makeRequest', () async {
      final activeDevicesData = [
        {
          'id': 'sess-1',
          'device_id': 'dev-1',
          'device_name': 'iPhone 15 Pro',
          'platform': 'ios',
          'last_active_at': '2026-10-10T12:00:00Z',
        },
        {
          'id': 'sess-2',
          'device_id': 'dev-2',
          'device_name': 'MacBook Pro',
          'platform': 'macos',
          'last_active_at': '2026-10-11T08:00:00Z',
        },
        {
          'id': 'sess-3',
          'device_id': 'dev-3',
          'device_name': 'Pixel 8',
          'platform': 'android',
          'last_active_at': '2026-10-11T14:00:00Z',
        },
      ];

      Future<void> failingAction() async {
        throw DeviceLimitExceededException(
          message: 'Maximum active device limit (3) reached for this profile.',
          activeDevices: activeDevicesData,
        );
      }

      final result = await failingAction().makeRequest();

      expect(result.isLeft, isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<DeviceLimitExceededFailure>());
          final devFailure = failure as DeviceLimitExceededFailure;
          expect(devFailure.message, contains('Maximum active device limit (3) reached'));
          expect(devFailure.activeDevices.length, equals(3));
          expect(devFailure.activeDevices.first['device_id'], equals('dev-1'));
        },
        (_) => fail('Expected Left(DeviceLimitExceededFailure)'),
      );
    });

    test('ActiveDeviceInfo.fromJson accurately parses session payload', () {
      final json = {
        'id': 'session-uuid-1',
        'device_id': 'device-fingerprint-abc',
        'device_name': 'Study iPad Air',
        'platform': 'ios',
        'last_active_at': '2026-10-11T16:00:00Z',
      };

      final info = ActiveDeviceInfo.fromJson(json);

      expect(info.deviceId, equals('device-fingerprint-abc'));
      expect(info.deviceName, equals('Study iPad Air'));
      expect(info.platform, equals('ios'));
      expect(info.lastActiveAt, equals('2026-10-11T16:00:00Z'));
    });

    test('AuthState retains activeDevices in copyWith and equality', () {
      const state = AuthState();
      expect(state.activeDevices, isEmpty);

      final updatedState = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Device limit exceeded.',
        activeDevices: [
          {'device_id': 'dev-1', 'device_name': 'Device 1'},
        ],
      );

      expect(updatedState.status, equals(AuthStatus.error));
      expect(updatedState.errorMessage, equals('Device limit exceeded.'));
      expect(updatedState.activeDevices.length, equals(1));
      expect(updatedState.activeDevices.first['device_name'], equals('Device 1'));
    });
  });
}
