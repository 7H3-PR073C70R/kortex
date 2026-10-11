import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/monetization/presentation/screens/paywall_screen.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_active_pro_view.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_checkout_dock.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_desktop_panel.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_plan_content.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

Widget createTestApp({
  required Widget child,
  required AuthBloc authBloc,
  Size screenSize = const Size(390, 844),
}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: child,
      ),
    ),
  );
}

void main() {
  group('PaywallScreen Widget Tests', () {
    late MockAuthBloc mockAuthBloc;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
    });

    testWidgets('renders plan options and checkout dock for free tier user', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(
        const AuthState(
          status: AuthStatus.authenticated,
          userProfile: UserProfileEntity(
            id: 'user_123',
            email: 'test@kortex.app',
            displayName: 'testuser',
          ),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          authBloc: mockAuthBloc,
          child: const PaywallScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PaywallPlanContent), findsOneWidget);
      expect(find.byType(PaywallStickyBottomDock), findsOneWidget);
      expect(find.byType(PaywallActiveProView), findsNothing);
    });

    testWidgets('renders active pro view when user has active Pro subscription', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(
        const AuthState(
          status: AuthStatus.authenticated,
          userProfile: UserProfileEntity(
            id: 'user_pro',
            email: 'pro@kortex.app',
            displayName: 'prouser',
            subscriptionTier: 'pro',
          ),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          authBloc: mockAuthBloc,
          child: const PaywallScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PaywallActiveProView), findsOneWidget);
      expect(find.byType(PaywallStickyBottomDock), findsNothing);
    });

    testWidgets('renders desktop panel on wide screens (>= 720px)', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(
        const AuthState(
          status: AuthStatus.authenticated,
          userProfile: UserProfileEntity(
            id: 'user_123',
            email: 'test@kortex.app',
            displayName: 'testuser',
          ),
        ),
      );

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          authBloc: mockAuthBloc,
          screenSize: const Size(1200, 900),
          child: const PaywallScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PaywallDesktopPanel), findsOneWidget);
      expect(find.byType(PaywallPlanContent), findsOneWidget);
    });

    testWidgets('renders embedded mode cleanly without scaffold appbar', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(
        const AuthState(
          status: AuthStatus.authenticated,
          userProfile: UserProfileEntity(
            id: 'user_123',
            email: 'test@kortex.app',
            displayName: 'testuser',
          ),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          authBloc: mockAuthBloc,
          child: const PaywallScreen(isEmbedded: true),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Scaffold), findsNothing);
      expect(find.byType(PaywallPlanContent), findsOneWidget);
    });
  });
}
