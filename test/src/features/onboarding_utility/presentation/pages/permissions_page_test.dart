import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/bloc/permissions_cubit.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/pages/permissions_page.dart';
import 'package:kortex/src/l10n/l10n.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AuthModeCubit>(
      create: (_) => AuthModeCubit()..setMode(AuthMode.form),
      child: child,
    ),
  );
}

void main() {
  setUp(() async {
    final locator = GetIt.instance;
    if (locator.isRegistered<AuthModeCubit>()) {
      await locator.unregister<AuthModeCubit>();
    }
    locator.registerFactory<AuthModeCubit>(
      () => AuthModeCubit()..setMode(AuthMode.form),
    );
    if (locator.isRegistered<PermissionsCubit>()) {
      await locator.unregister<PermissionsCubit>();
    }
    locator.registerFactory<PermissionsCubit>(
      PermissionsCubit.new,
    );
  });

  group('PermissionsPage Test Suite', () {
    testWidgets('renders top bar logo, title, and skip button', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const PermissionsPage()),
      );
      await tester.pump();

      expect(find.text('KORTEXIFY'), findsOneWidget);
      expect(find.text('Skip for now'), findsNWidgets(2));
      expect(find.text('Supercharge Your Focus'), findsOneWidget);
    });

    testWidgets('renders permission cards with allow buttons', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const PermissionsPage()),
      );
      await tester.pump();

      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Camera & Storage Access'), findsOneWidget);
      expect(find.text('Allow'), findsNWidgets(2));
    });

    testWidgets('PermissionsCubit skip and finish transition state correctly',
        (tester) async {
      final cubit = PermissionsCubit()
        ..skipPermissions();
      expect(cubit.state.isDone, isTrue);

      final cubit2 = PermissionsCubit()
        ..finishPermissions();
      expect(cubit2.state.isDone, isTrue);
    });
  });
}
