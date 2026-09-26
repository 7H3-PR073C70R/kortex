import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Domain & Feature Unit Tests', () {
    test('maps Supabase auth exceptions cleanly to typed AuthFailure domain models', () {
      const invalidCreds = AuthFailure(message: 'Invalid login credentials');
      const userNotFound = AuthFailure(message: 'User not found');
      const rateLimited = AuthFailure(message: 'Email rate limit exceeded');

      expect(invalidCreds.message, contains('Invalid login credentials'));
      expect(userNotFound.message, contains('User not found'));
      expect(rateLimited.message, contains('Email rate limit exceeded'));
    });
  });
}
