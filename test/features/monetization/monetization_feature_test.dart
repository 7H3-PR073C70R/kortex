import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/monetization/domain/entities/promo_code_redemption.dart';
import 'package:kortex/src/features/monetization/domain/repositories/promo_code_repository.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/monetization/domain/use_cases/redeem_promo_code_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockUserStorageService extends Mock implements UserStorageService {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockPromoCodeRepository extends Mock implements PromoCodeRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Monetization & Entitlement Guard Test Suite', () {
    late MockUserStorageService mockUserStorage;
    late MockLocalStorageService mockLocalStorage;
    late SubscriptionGuard guard;

    setUp(() {
      mockUserStorage = MockUserStorageService();
      mockLocalStorage = MockLocalStorageService();
      guard = SubscriptionGuard(
        userStorageService: mockUserStorage,
        localStorageService: mockLocalStorage,
      );
    });

    test('isPro returns false when user is not pro in storage', () {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(false);
      expect(guard.isPro, isFalse);
    });

    test('isPro returns true when user is pro in storage', () {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(true);
      expect(guard.isPro, isTrue);
    });

    test('canUploadFileSize respects 50MB free vs 200MB pro limits', () {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(false);
      expect(guard.canUploadFileSize(40 * 1024 * 1024), isTrue);
      expect(guard.canUploadFileSize(60 * 1024 * 1024), isFalse);

      when(() => mockUserStorage.isProSubscriber()).thenReturn(true);
      expect(guard.canUploadFileSize(180 * 1024 * 1024), isTrue);
      expect(guard.canUploadFileSize(250 * 1024 * 1024), isFalse);
    });

    test('canExportDeck restricts Anki and PDF to Pro users', () {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(false);
      expect(guard.canExportDeck(DeckExportFormat.csv), isTrue);
      expect(guard.canExportDeck(DeckExportFormat.anki), isFalse);
      expect(guard.canExportDeck(DeckExportFormat.pdfPrintable), isFalse);

      when(() => mockUserStorage.isProSubscriber()).thenReturn(true);
      expect(guard.canExportDeck(DeckExportFormat.csv), isTrue);
      expect(guard.canExportDeck(DeckExportFormat.anki), isTrue);
      expect(guard.canExportDeck(DeckExportFormat.pdfPrintable), isTrue);
    });

    test('isOfflineEntitlementValid grants 7-day grace period for active Pro', () {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(true);
      
      final recentDate = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
      when(() => mockLocalStorage.getPreference(key: any(named: 'key')))
          .thenReturn(recentDate);

      expect(guard.isOfflineEntitlementValid(), isTrue);
    });

    test('RedeemPromoCodeUseCase delegates code to repository', () async {
      final mockRepo = MockPromoCodeRepository();
      final useCase = RedeemPromoCodeUseCase(mockRepo);

      const params = RedeemPromoCodeParams(code: 'PROMO2026');
      
      when(() => mockRepo.redeemPromoCode(code: 'PROMO2026'))
          .thenAnswer((_) async => const Right(
                PromoRedemptionResult(
                  success: true,
                  code: 'PROMO2026',
                  durationDays: 365,
                ),
              ));

      final result = await useCase(params);
      expect(result.isRight, isTrue);
      result.fold(
        (failure) => fail('Should not return left failure'),
        (redemption) {
          expect(redemption.success, isTrue);
          expect(redemption.durationDays, equals(365));
        },
      );
      verify(() => mockRepo.redeemPromoCode(code: 'PROMO2026')).called(1);
    });
  });
}
