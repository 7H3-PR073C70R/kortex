import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/biometric_auth_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/shared/widgets/tailored_biometric_lock_view.dart';

class BiometricLockOverlay extends StatefulWidget {
  const BiometricLockOverlay({
    required this.child,
    this.backgroundTimeout,
    this.clock,
    this.biometricService,
    this.userStorageService,
    super.key,
  });

  final Widget child;
  final Duration? backgroundTimeout;
  final DateTime Function()? clock;
  final BiometricAuthService? biometricService;
  final UserStorageService? userStorageService;

  @override
  State<BiometricLockOverlay> createState() => _BiometricLockOverlayState();
}

class _BiometricLockOverlayState extends State<BiometricLockOverlay>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;

  late final BiometricAuthService _biometricService =
      widget.biometricService ?? locator<BiometricAuthService>();
  late final UserStorageService _userStorage =
      widget.userStorageService ?? locator<UserStorageService>();

  DateTime _now() => widget.clock != null ? widget.clock!() : DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _biometricService.isEnabledListenable.addListener(_onBiometricToggle);
  }

  @override
  void dispose() {
    _biometricService.isEnabledListenable.removeListener(_onBiometricToggle);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onBiometricToggle() {
    if (!_biometricService.isBiometricLockEnabled() && _isLocked) {
      setState(() => _isLocked = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _biometricService.recordBackgroundedAt(_now());
    } else if (state == AppLifecycleState.resumed) {
      final token = _userStorage.getToken();
      final isAuthenticated = token != null && token.isNotEmpty;
      final shouldLock = isAuthenticated &&
          _biometricService.isBiometricLockEnabled() &&
          _biometricService.shouldReArmLock(
            threshold: widget.backgroundTimeout,
            now: _now(),
          ) &&
          !_isLocked;

      _biometricService.clearBackgroundedAt();

      if (shouldLock) {
        setState(() => _isLocked = true);
        unawaited(_authenticate());
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      final success = await _biometricService.authenticate(
        localizedReason: 'Unlock Kortexify to access your workspace',
      );
      if (success && mounted) {
        AppFeedback.light();
        setState(() {
          _isLocked = false;
        });
      }
    } on Object catch (_) {
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: TailoredBiometricLockView(
              onUnlock: _authenticate,
            ),
          ),
      ],
    );
  }
}
