import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/monetization/domain/entities/promo_code_redemption.dart';
import 'package:kortex/src/features/monetization/domain/use_cases/redeem_promo_code_use_case.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/promo_code_modal_sheet.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockRedeemPromoCodeUseCase extends Mock
    implements RedeemPromoCodeUseCase {}

Widget createTestApp(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  late MockRedeemPromoCodeUseCase mockRedeemUseCase;

  setUp(() async {
    mockRedeemUseCase = MockRedeemPromoCodeUseCase();
    if (locator.isRegistered<RedeemPromoCodeUseCase>()) {
      await locator.unregister<RedeemPromoCodeUseCase>();
    }
    locator.registerLazySingleton<RedeemPromoCodeUseCase>(
      () => mockRedeemUseCase,
    );
  });

  tearDown(() async {
    if (locator.isRegistered<RedeemPromoCodeUseCase>()) {
      await locator.unregister<RedeemPromoCodeUseCase>();
    }
  });

  group('PromoCodeModalSheet Widget Tests', () {
    testWidgets('renders input field, title, and apply button', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const PromoCodeModalSheet(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Redeem Promo Code'), findsOneWidget);
      expect(find.text('Promo Code'), findsOneWidget);
      expect(find.text('Apply Promo Code'), findsOneWidget);
    });

    testWidgets('successful redemption shows Kortex Pro Activated state', (
      tester,
    ) async {
      when(
        () => mockRedeemUseCase(
          const RedeemPromoCodeParams(code: 'kotexify007'),
        ),
      ).thenAnswer(
        (_) async => const Right(
          PromoRedemptionResult(
            success: true,
            code: 'kotexify007',
            durationDays: 365,
            message: 'Promo code redeemed successfully!',
          ),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          const PromoCodeModalSheet(initialCode: 'kotexify007'),
        ),
      );

      await tester.tap(find.text('Apply Promo Code'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Kortex Pro Activated!'), findsOneWidget);
      expect(
        find.textContaining('365 days of Kortex Pro access'),
        findsOneWidget,
      );
      expect(find.text('Get Started with Pro'), findsOneWidget);
    });

    testWidgets('failed redemption shows error message inline', (tester) async {
      when(
        () => mockRedeemUseCase(
          const RedeemPromoCodeParams(code: 'invalid_code'),
        ),
      ).thenAnswer(
        (_) async => const Right(
          PromoRedemptionResult(
            success: false,
            errorCode: 'INVALID_CODE',
            message: 'Promo code not found. Please check and try again.',
          ),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          const PromoCodeModalSheet(initialCode: 'invalid_code'),
        ),
      );

      await tester.tap(find.text('Apply Promo Code'));
      await tester.pumpAndSettle();

      expect(
        find.text('Promo code not found. Please check and try again.'),
        findsOneWidget,
      );
    });
  });
}
