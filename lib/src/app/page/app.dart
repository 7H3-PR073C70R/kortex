import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/app/router/app_router.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/services/session_expired_service.dart';
import 'package:kortex/src/core/themes/theme_cubit.dart';
import 'package:kortex/src/core/themes/theme_state.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:kortex/src/shared/widgets/biometric_lock_overlay.dart';
import 'package:kortex/src/shared/widgets/dismiss_keyboard.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final AppRouter _appRouter;
  late final RouterConfig<UrlState> _routerConfig;
  StreamSubscription<String>? _sessionExpiredSubscription;
  StreamSubscription<String>? _notificationPayloadSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appRouter = locator<AppRouter>();
    _routerConfig = _appRouter.config(
      reevaluateListenable: ReevaluateListenable.stream(
        locator<AuthBloc>().stream,
      ),
    );

    _sessionExpiredSubscription = locator<SessionExpiredService>()
        .onSessionExpired
        .listen(_handleSessionExpired);

    if (locator.isRegistered<NotificationService>()) {
      _notificationPayloadSubscription = locator<NotificationService>()
          .onPayloadTapped
          .listen(_handleNotificationPayload);
    }
  }

  void _handleSessionExpired(String message) {
    locator<AuthModeCubit>().resetToLogin();
    unawaited(_appRouter.replaceAll([const AuthRoute()]));
    locator<AuthBloc>().add(const AuthSignOutRequested());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = _appRouter.navigatorKey.currentContext;
      final overlay = _appRouter.navigatorKey.currentState?.overlay;
      if (navContext != null && navContext.mounted) {
        navContext.showSnackBar(
          message: message,
          type: SnackBarType.error,
          overlay: overlay,
        );
      }
    });
  }

  void _handleNotificationPayload(String payload) {
    if (payload.trim().isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clean = payload.trim();
      try {
        if (clean == '/planner' ||
            clean == 'planner' ||
            clean.startsWith('/exam') ||
            clean.startsWith('exam:')) {
          unawaited(_appRouter.push(const ExamTimetableRoute()));
          return;
        }

        if (clean == '/decks' || clean == 'decks') {
          unawaited(_appRouter.push(const DecksRoute()));
          return;
        }

        if (clean == '/past-questions' || clean == 'past-questions') {
          unawaited(_appRouter.push(PastQuestionsBoardRoute()));
          return;
        }

        if (clean == '/ingestion' ||
            clean == 'ingestion' ||
            clean.startsWith('doc:')) {
          unawaited(_appRouter.push(DocumentIngestionRoute()));
          return;
        }

        if (clean == '/chat' || clean == 'syllabot' || clean == '/syllabot') {
          unawaited(_appRouter.push(SyllabotChatRoute()));
          return;
        }

        if (clean.startsWith('deck:')) {
          final parts = clean.substring(5).split(':');
          final deckId = parts.first;
          final mode = parts.length > 1 ? parts[1] : '';
          if (mode == 'study') {
            unawaited(
              _appRouter.push(
                StudySessionRoute(deckId: deckId),
              ),
            );
          } else {
            unawaited(_appRouter.push(DeckDetailRoute(deckId: deckId)));
          }
          return;
        }

        if (clean.startsWith('study:')) {
          final deckId = clean.substring(6);
          unawaited(
            _appRouter.push(
              StudySessionRoute(deckId: deckId),
            ),
          );
          return;
        }

        // FCM data payload route keys (from trigger-notifications)
        if (clean == '/study-session' || clean.startsWith('/study-session?')) {
          // Parse optional deckId query param: /study-session?deckId=xxx
          final uri = Uri.tryParse(clean);
          final deckId = uri?.queryParameters['deckId'];
          if (deckId != null && deckId.isNotEmpty) {
            unawaited(_appRouter.push(StudySessionRoute(deckId: deckId)));
          } else {
            unawaited(_appRouter.push(const DecksRoute()));
          }
          return;
        }

        if (clean == '/quiz-duel' || clean.startsWith('/quiz-duel?')) {
          // Navigate to the Community hub where Quiz Duels are initiated.
          // The duelId can be passed via query param when deep-linking is added.
          unawaited(_appRouter.push(const CommunityHubRoute()));
          return;
        }

        if (clean == '/deck-detail' || clean.startsWith('/deck-detail?')) {
          final uri = Uri.tryParse(clean);
          final deckId = uri?.queryParameters['deckId'];
          if (deckId != null && deckId.isNotEmpty) {
            unawaited(_appRouter.push(DeckDetailRoute(deckId: deckId)));
          } else {
            unawaited(_appRouter.push(const DecksRoute()));
          }
          return;
        }

        if (clean == '/dashboard' || clean == 'dashboard') {
          // Pop to root (dashboard is the root scaffold tab).
          _appRouter.popUntilRoot();
          return;
        }

        if (clean == '/community' || clean == 'community') {
          unawaited(_appRouter.push(const CommunityHubRoute()));
          return;
        }

        // Generic named route fallback
        if (clean.startsWith('/')) {
          unawaited(_appRouter.pushPath(clean));
        }
      } on Object catch (e) {
        debugPrint('[App] Failed to route notification payload "$payload": $e');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (locator.isRegistered<AuthBloc>()) {
        locator<AuthBloc>().add(const AuthAppResumed());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sessionExpiredSubscription?.cancel());
    unawaited(_notificationPayloadSubscription?.cancel());
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
        BlocProvider<IngestionBloc>.value(
          value: locator<IngestionBloc>(),
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
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: _routerConfig,
                builder: (context, child) {
                  final mediaQueryData = MediaQuery.of(context);
                  return MediaQuery(
                    data: mediaQueryData.copyWith(
                      textScaler: mediaQueryData.textScaler.clamp(
                        minScaleFactor: 0.85,
                        maxScaleFactor: 1.25,
                      ),
                    ),
                    child: BiometricLockOverlay(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
