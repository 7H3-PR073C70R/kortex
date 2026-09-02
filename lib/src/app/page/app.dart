import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/app/router/app_router.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/session_expired_service.dart';
import 'package:kortex/src/core/themes/theme_cubit.dart';
import 'package:kortex/src/core/themes/theme_state.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:kortex/src/shared/widgets/biometric_lock_overlay.dart';
import 'package:kortex/src/shared/widgets/dismiss_keyboard.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AppRouter _appRouter;
  StreamSubscription<String>? _sessionExpiredSubscription;

  @override
  void initState() {
    super.initState();
    _appRouter = locator<AppRouter>();

    _sessionExpiredSubscription = locator<SessionExpiredService>()
        .onSessionExpired
        .listen(_handleSessionExpired);
  }

  void _handleSessionExpired(String message) {
    unawaited(_appRouter.replaceAll([const LoginRoute()]));
    locator<AuthBloc>().add(const AuthSignOutRequested());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = _appRouter.navigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        navContext.showSnackBar(
          message: message,
          type: SnackBarType.error,
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_sessionExpiredSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(
          value: locator<ThemeCubit>(),
        ),
        BlocProvider<AuthBloc>.value(
          value: locator<AuthBloc>(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return DismissKeyboard(
            child: ScreenUtilInit(
              designSize: const Size(375, 812),
              builder: (context, _) => MaterialApp.router(
                theme: state.lightTheme,
                darkTheme: state.darkTheme,
                themeMode: state.themeMode,
                themeAnimationDuration: const Duration(milliseconds: 300),
                themeAnimationCurve: Curves.easeInOut,
                debugShowCheckedModeBanner: false,
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: _appRouter.config(),
                builder: (context, child) => BiometricLockOverlay(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
