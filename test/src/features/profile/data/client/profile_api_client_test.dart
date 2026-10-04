import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/profile/data/client/profile_api_client.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late ProfileApiClient apiClient;

  setUp(() {
    mockDio = MockDio();
    apiClient = ProfileApiClient(mockDio);
  });

  group('ProfileApiClient.updateProfile', () {
    const testUserId = 'test-user-uuid-123';

    test('patches profiles table with only valid columns and excludes streak_freeze_count', () async {
      when(
        () => mockDio.patch<dynamic>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: AppApiEndpoint.userProfiles),
          statusCode: 204,
        ),
      );

      when(
        () => mockDio.put<dynamic>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/auth/v1/user'),
          statusCode: 200,
        ),
      );

      await apiClient.updateProfile(
        userId: testUserId,
        streakDays: 5,
        streakFreezeCount: 2,
      );

      // Verify PATCH to profiles table
      final capturedPatch = verify(
        () => mockDio.patch<dynamic>(
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.userProfiles}?id=eq.$testUserId',
          data: captureAny(named: 'data'),
        ),
      ).captured.first as Map<String, dynamic>;

      expect(capturedPatch['streak_days'], equals(5));
      expect(capturedPatch.containsKey('streak_freeze_count'), isFalse);
      expect(capturedPatch.containsKey('updated_at'), isTrue);

      // Verify PUT to auth user endpoint includes streak_freeze_count in auth metadata
      final capturedPut = verify(
        () => mockDio.put<dynamic>(
          '${AppApiEndpoint.baseUri}/auth/v1/user',
          data: captureAny(named: 'data'),
        ),
      ).captured.first as Map<String, dynamic>;

      final authData = capturedPut['data'] as Map<String, dynamic>;
      expect(authData['streak_freeze_count'], equals(2));
    });

    test('does not patch profiles table if no profile-specific field is provided', () async {
      when(
        () => mockDio.put<dynamic>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/auth/v1/user'),
          statusCode: 200,
        ),
      );

      await apiClient.updateProfile(
        userId: testUserId,
        streakFreezeCount: 1,
      );

      verifyNever(
        () => mockDio.patch<dynamic>(
          any(),
          data: any(named: 'data'),
        ),
      );

      verify(
        () => mockDio.put<dynamic>(
          '${AppApiEndpoint.baseUri}/auth/v1/user',
          data: any(named: 'data'),
        ),
      ).called(1);
    });
  });
}
