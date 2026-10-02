import 'dart:async';
import 'dart:developer' as developer;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/app/router/app_router.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/dynamic_link_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/services/session_expired_service.dart';
import 'package:kortex/src/core/themes/theme_cubit.dart';
import 'package:kortex/src/core/themes/theme_state.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/notifications/domain/services/notification_router.dart';
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
  StreamSubscription<DynamicLinkPayload>? _dynamicLinkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appRouter = locator<AppRouter>();
    _routerConfig = _appRouter.config(
      reevaluateListenable: ReevaluateListenable.stream(
        locator<AuthBloc>()
            .stream
            .map((state) => (state.sessionStatus, state.userProfile?.isOnboarded))
            .distinct(),
      ),
      deepLinkTransformer: _transformDeepLink,
      deepLinkBuilder: _handlePlatformDeepLink,
    );

    _sessionExpiredSubscription = locator<SessionExpiredService>()
        .onSessionExpired
        .listen(_handleSessionExpired);

    if (locator.isRegistered<NotificationService>()) {
      _notificationPayloadSubscription = locator<NotificationService>()
          .onPayloadTapped
          .listen(_handleNotificationPayload);
    }

    if (locator.isRegistered<DynamicLinkService>()) {
      _dynamicLinkSubscription = locator<DynamicLinkService>()
          .onLinkReceived
          .listen(_handleDynamicLinkPayload);
    }
  }

  /// Transforms external deep-link URIs into recognized internal routes before matching.
  Future<Uri> _transformDeepLink(Uri uri) async {
    developer.log('[App] Transforming deep link: $uri');
    final isCustomScheme =
        uri.scheme == 'kortex' || uri.scheme == 'com.kortexify.app';
    final isShareHost = uri.host == 'share' || uri.path.contains('share');
    final typeStr =
        uri.queryParameters['type']?.trim().toLowerCase().replaceAll('-', '_');

    if (isCustomScheme || isShareHost || typeStr != null) {
      switch (typeStr) {
        case 'deck':
          return uri.replace(path: '/deck-detail');
        case 'study':
          return uri.replace(path: '/study-session');
        case 'forum':
          return uri.replace(path: '/community');
        case 'quiz_duel':
          return uri.replace(path: '/quiz-workspace');
        case 'study_room':
          return uri.replace(path: '/study-hub');
        case 'promo':
          return uri.replace(path: '/paywall');
        case 'course':
          return uri.replace(path: '/curate-courses');
      }

      if (isCustomScheme && uri.host.isNotEmpty) {
        final hostType = uri.host.toLowerCase();
        if (hostType == 'study-session') {
          return uri.replace(path: '/study-session');
        }
        if (hostType == 'decks' || hostType == 'deck') {
          return uri.replace(path: '/decks');
        }
        if (hostType == 'planner' || hostType == 'exam') {
          return uri.replace(path: '/exam-timetable');
        }
        if (hostType == 'community') {
          return uri.replace(path: '/community');
        }
        if (hostType == 'chat' || hostType == 'syllabot') {
          return uri.replace(path: '/syllabot-chat');
        }
      }
    }
    return uri;
  }

  /// Resolves the exact [DeepLink] for incoming platform deep links.
  FutureOr<DeepLink> _handlePlatformDeepLink(
    PlatformDeepLink platformDeepLink,
  ) async {
    final uri = platformDeepLink.uri;
    developer.log('[App] Resolving platform deep link: $uri');

    // 1. Try parsing through DynamicLinkService
    if (locator.isRegistered<DynamicLinkService>()) {
      final dynamicService = locator<DynamicLinkService>();
      final payload = dynamicService.parseUri(uri);
      if (payload != null && payload.type != DynamicLinkType.unknown) {
        dynamicService.handleRawUri(uri);
        final route = dynamicService.routeForPayload(payload);
        if (route != null) {
          return DeepLink.single(route);
        }
      }
    }

    // 2. Try parsing through NotificationRouter
    final notifRouter = locator.isRegistered<NotificationRouter>()
        ? locator<NotificationRouter>()
        : const NotificationRouter();
    final notifRoute = notifRouter.resolveRouteFromPayload(uri.toString());
    if (notifRoute != null) {
      return DeepLink.single(notifRoute);
    }

    if (platformDeepLink.isValid) {
      return platformDeepLink;
    }
    return DeepLink.defaultPath;
  }

  void _handleDynamicLinkPayload(DynamicLinkPayload payload) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        locator<DynamicLinkService>().handlePayload(
          payload: payload,
          appRouter: _appRouter,
        ),
      );
    });
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final notifRouter = locator.isRegistered<NotificationRouter>()
            ? locator<NotificationRouter>()
            : const NotificationRouter();
        final handled = await notifRouter.handlePayloadString(
          router: _appRouter,
          payload: payload,
        );
        if (!handled) {
          debugPrint('[App] Could not route notification payload: "$payload"');
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
    unawaited(_dynamicLinkSubscription?.cancel());
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
