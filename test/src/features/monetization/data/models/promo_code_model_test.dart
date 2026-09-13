import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/monetization/data/models/promo_code_model.dart';

void main() {
  group('PromoRedemptionResultModel', () {
    test('fromJson successfully parses valid 1-year promo redemption payload', () {
      final json = {
        'success': true,
        'code': 'kotexify007',
        'duration_days': 365,
        'pro_until': '2027-09-13T03:45:00.000Z',
        'message': 'Promo code redeemed successfully! 365 days of Kortex Pro activated.',
      };

      final model = PromoRedemptionResultModel.fromJson(json);

      expect(model.success, isTrue);
      expect(model.code, equals('kotexify007'));
      expect(model.durationDays, equals(365));
      expect(model.proUntil, isNotNull);
      expect(model.errorCode, isNull);
      expect(model.message, contains('365 days'));
    });

    test('fromJson successfully parses failed promo redemption payload', () {
      final json = {
        'success': false,
        'error_code': 'INVALID_CODE',
        'message': 'Promo code not found. Please check and try again.',
      };

      final model = PromoRedemptionResultModel.fromJson(json);

      expect(model.success, isFalse);
      expect(model.errorCode, equals('INVALID_CODE'));
      expect(model.message, contains('not found'));
    });

    test('toJson serializes model correctly', () {
      final model = PromoRedemptionResultModel(
        success: true,
        code: 'kotexify007',
        durationDays: 365,
        proUntil: DateTime.parse('2027-09-13T03:45:00.000Z'),
        message: 'Success',
      );

      final json = model.toJson();

      expect(json['success'], isTrue);
      expect(json['code'], equals('kotexify007'));
      expect(json['duration_days'], equals(365));
    });
  });
}
