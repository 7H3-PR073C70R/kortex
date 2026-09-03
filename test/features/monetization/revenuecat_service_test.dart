import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/monetization/data/datasources/revenuecat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RevenueCatService In-App Purchase Test Suite', () {
    late RevenueCatService service;

    setUp(() {
      service = RevenueCatService.instance;
    });

    test(
      'Initial uninitialized state returns false for isProSubscriber',
      () async {
        expect(service.isInitialized, isFalse);
        final isPro = await service.isProSubscriber();
        expect(isPro, isFalse);
      },
    );

    test('fetchOfferings returns null when not initialized', () async {
      final offerings = await service.fetchOfferings();
      expect(offerings, isNull);
    });

    test('restorePurchases returns false when not initialized', () async {
      final restored = await service.restorePurchases();
      expect(restored, isFalse);
    });
  });
}
