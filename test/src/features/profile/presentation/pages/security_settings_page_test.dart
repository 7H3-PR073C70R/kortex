import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/profile/presentation/pages/security_settings_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends Mock implements AuthBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockAuthBloc mockAuthBloc;

  const tUser = UserEntity(
    id: 'user_123',
    email: 'scholar@kortex.ai',
    displayName: 'Neural Scholar',
  );

  const tProfile = UserProfileEntity(
    id: 'user_123',
    email: 'scholar@kortex.ai',
    displayName: 'Neural Scholar',
    targetTrack: 'WAEC',
    dailyCardTarget: 25,
    streakDays: 14,
    level: 3,
    xpPoints: 2400,
    retentionBenchmark: 0.90,
    isOnboarded: true,
  );

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(
      const AuthState(
        user: tUser,
        userProfile: tProfile,
      ),
    );
    when(() => mockAuthBloc.stream).thenAnswer(
      (_) => Stream.value(
        const AuthState(
          user: tUser,
          userProfile: tProfile,
        ),
      ),
    );
  });

  Widget createTestWidget({int initialTabIndex = 0}) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.darkTheme,
        home: BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: SecuritySettingsPage(
            initialTabIndex: initialTabIndex,
            authBloc: mockAuthBloc,
          ),
        ),
      ),
    );
  }

  group('SecuritySettingsPage Widget Tests', () {
    testWidgets('renders app bar and tabs correctly on Security tab', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Account & Security'), findsWidgets);
      expect(find.text('Security & Access'), findsOneWidget);
      expect(find.text('Account & Data'), findsOneWidget);
      expect(find.textContaining('Password'), findsWidgets);
      expect(find.text('Biometric App Lock'), findsOneWidget);
      expect(find.text('Two-Factor Auth (TOTP)'), findsOneWidget);
      expect(
        find.text('ACTIVE SESSIONS & DEVICE MANAGEMENT'),
        findsOneWidget,
      );
      expect(find.text('Danger Zone'), findsOneWidget);
    });

    testWidgets('switches to Account & Data tab and renders sections', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(initialTabIndex: 1));
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT CREDENTIALS'), findsOneWidget);
      expect(find.text('DATA PORTABILITY & EXPORT'), findsOneWidget);
      expect(find.text('STORAGE & AI CACHE MANAGEMENT'), findsOneWidget);
      expect(find.text('Neural Scholar'), findsOneWidget);
      expect(find.text('scholar@kortex.ai'), findsOneWidget);
    });

    testWidgets('allows tapping tab to switch from Security to Account & Data', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Biometric App Lock'), findsOneWidget);

      await tester.tap(find.text('Account & Data'));
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT CREDENTIALS'), findsOneWidget);
      expect(find.text('DATA PORTABILITY & EXPORT'), findsOneWidget);
    });
  });
}
