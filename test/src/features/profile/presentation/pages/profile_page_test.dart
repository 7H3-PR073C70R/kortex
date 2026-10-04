import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/profile/presentation/pages/profile_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import 'package:package_info_plus/package_info_plus.dart';

class MockAuthBloc extends Mock implements AuthBloc {}
class MockAuthModeCubit extends Mock implements AuthModeCubit {}
class MockUserActivityService extends Mock implements UserActivityService {}

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockAuthModeCubit mockAuthModeCubit;
  late MockUserActivityService mockUserActivityService;

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

  setUpAll(() {
    registerFallbackValue(const AuthProfileFetchRequested());
    PackageInfo.setMockInitialValues(
      appName: 'Kortexify',
      packageName: 'com.kortex.app',
      version: '1.0.2',
      buildNumber: '3',
      buildSignature: '',
    );
  });

  setUp(() async {
    mockAuthBloc = MockAuthBloc();
    mockAuthModeCubit = MockAuthModeCubit();
    mockUserActivityService = MockUserActivityService();

    when(() => mockAuthBloc.state).thenReturn(
      const AuthState(
        status: AuthStatus.authenticated,
        sessionStatus: AuthSessionStatus.authenticatedComplete,
        user: tUser,
        userProfile: tProfile,
      ),
    );
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());

    when(() => mockUserActivityService.getCurrentStreak()).thenReturn(14);
    when(() => mockUserActivityService.getStreakFreezes()).thenReturn(2);
    when(() => mockUserActivityService.getOverallRetentionRate()).thenReturn(0.90);
    when(() => mockUserActivityService.getXpPoints()).thenReturn(2400);
    when(() => mockUserActivityService.getLevelForXp(any())).thenReturn(3);
    when(() => mockUserActivityService.getTotalCardsMastered()).thenReturn(120);

    await GetIt.I.reset();
    GetIt.I.registerSingleton<AuthBloc>(mockAuthBloc);
    GetIt.I.registerSingleton<AuthModeCubit>(mockAuthModeCubit);
    GetIt.I.registerSingleton<UserActivityService>(mockUserActivityService);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  Widget createTestApp() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: const ProfilePage(),
      ),
    );
  }

  group('ProfilePage Widget Tests', () {
    testWidgets('renders Profile & Settings title and identity card cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.text('Neural Scholar'), findsWidgets);
      expect(find.text('scholar@kortex.ai'), findsOneWidget);
      expect(find.text('Kortexify v1.0.2+3 • Neural Study AI'), findsOneWidget);
    });
  });
}
