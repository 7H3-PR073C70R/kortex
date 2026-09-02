import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/biometric_auth_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/tailored_biometric_lock_view.dart';

@RoutePage()
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoOpacityAnimation;
  late final Animation<double> _glowExpansionAnimation;
  late final Animation<double> _textFadeAnimation;
  Timer? _navigationTimer;
  bool _showBiometricChallenge = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();

    // Stage 1: Fast tactile entrance (0ms - 800ms)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Stage 2: Continuous ambient breathing pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.45, curve: Curves.easeIn),
      ),
    );

    _glowExpansionAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
      ),
    );

    unawaited(
      _entranceController.forward().then((_) {
        if (mounted) {
          unawaited(_pulseController.repeat(reverse: true));
        }
      }),
    );

    _navigationTimer = Timer(
      const Duration(milliseconds: 1800),
      _navigateNext,
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;

    final token = locator<UserStorageService>().getToken();
    final isAuthenticated = token != null && token.isNotEmpty;

    if (isAuthenticated) {
      locator<AuthBloc>().add(const AuthProfileFetchRequested());

      final biometricService = locator<BiometricAuthService>();
      if (biometricService.isBiometricLockEnabled()) {
        setState(() {
          _showBiometricChallenge = true;
        });
        unawaited(_triggerBiometricAuth());
        return;
      }

      await _proceedToApp();
      return;
    }

    final storage = locator<LocalStorageService>();
    final hasCompletedOnboarding = storage.getPreference(
          key: PrefKeys.hasCompletedOnboarding,
        ) ==
        'true';

    if (!mounted) return;

    if (hasCompletedOnboarding) {
      await context.router.replaceAll([const LoginRoute()]);
    } else {
      await context.router.replace(const OnboardingRoute());
    }
  }

  Future<void> _triggerBiometricAuth() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      final success = await locator<BiometricAuthService>().authenticate(
        localizedReason: 'Unlock Kortex to access your workspace',
      );
      if (success && mounted) {
        await _proceedToApp();
      }
    } on Object catch (_) {
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> _proceedToApp() async {
    final calibRepo = locator<CalibrationRepository>();
    final calibResult = await calibRepo.getCalibrationProfile();
    final isCalibrated = calibResult.fold(
      (_) => false,
      (profile) => profile?.isCalibrated ?? false,
    );

    if (!mounted) return;
    if (isCalibrated) {
      await context.router.replaceAll([const MainRoute()]);
    } else {
      await context.router.replaceAll([const OnboardingCalibrationRoute()]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showBiometricChallenge) {
      return TailoredBiometricLockView(
        onUnlock: _triggerBiometricAuth,
        onAlternativeAction: () async {
          locator<UserStorageService>().clearStorage();
          locator<AuthBloc>().add(const AuthSignOutRequested());
          await context.router.replaceAll([const LoginRoute()]);
        },
        alternativeActionLabel: 'Sign In with Password',
      );
    }
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Scaffold(
      backgroundColor: colors.surfacePrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([
                _entranceController,
                _pulseController,
              ]),
              builder: (context, child) {
                final scale =
                    disableAnimations ? 1.0 : _logoScaleAnimation.value;
                final opacity =
                    disableAnimations ? 1.0 : _logoOpacityAnimation.value;
                final glowExpand = disableAnimations
                    ? 1.0
                    : _glowExpansionAnimation.value.clamp(0.0, 1.0);
                final pulse = disableAnimations ? 0.5 : _pulseController.value;

                final glowAlpha =
                    ((isDark ? 90 : 50) * glowExpand * (0.6 + 0.4 * pulse))
                        .round()
                        .clamp(0, 255);

                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dynamic Multi-layered Ambient Glow Aura
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withAlpha(glowAlpha),
                                blurRadius: 48,
                                spreadRadius: 12,
                              ),
                              BoxShadow(
                                color: colors.syllabotAccent.withAlpha(
                                  glowAlpha ~/ 2,
                                ),
                                blurRadius: 32,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        // Sharp Vector Logo
                        AppAssets.svgs.kortexLogo.svg(
                          width: 92,
                          height: 92,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Staggered Title and Engine Subtitle
            AnimatedBuilder(
              animation: _entranceController,
              builder: (context, child) {
                final opacity =
                    disableAnimations ? 1.0 : _textFadeAnimation.value;
                final translateY = disableAnimations
                    ? 0.0
                    : (1.0 - _textFadeAnimation.value) * 16.0;

                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, translateY),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  Text(
                    l10n.appName,
                    style: typography.largeTitle.bold.copyWith(
                      letterSpacing: 4.5,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.syllabotAccent.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.syllabotAccent.withAlpha(50),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.syllabotAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.engineSubtitle,
                          style: typography.caption.medium.copyWith(
                            fontSize: 10.5,
                            letterSpacing: 1.2,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
