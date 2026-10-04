import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/force_update/domain/use_cases/check_force_update_use_case.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Responsive breakpoints ────────────────────────────────────────────────────

/// Classifies the current viewport into one of three form-factor tiers.
enum _FormFactor { phone, tablet, desktop }

extension _BreakpointX on BuildContext {
  _FormFactor get formFactor {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= 1024) return _FormFactor.desktop;
    if (width >= 600) return _FormFactor.tablet;
    return _FormFactor.phone;
  }
}

/// Per-tier layout tokens — avoids scattered ternary chains in the tree.
class _Layout {

  factory _Layout.from(_FormFactor factor) {
    switch (factor) {
      case _FormFactor.phone:
        return const _Layout._(
          contentMaxWidth: 440,
          horizontalPadding: 28,
          verticalPadding: 40,
          iconSize: 96,
          iconInnerSize: 44,
          gap1: 32,
          gap2: 14,
          gap3: 12,
          gap4: 36,
          orbPrimary: 340,
          orbSecondary: 260,
          buttonVerticalPadding: 17,
          buttonMaxWidth: double.infinity,
        );
      case _FormFactor.tablet:
        return const _Layout._(
          contentMaxWidth: 560,
          horizontalPadding: 48,
          verticalPadding: 56,
          iconSize: 120,
          iconInnerSize: 54,
          gap1: 40,
          gap2: 16,
          gap3: 14,
          gap4: 44,
          orbPrimary: 480,
          orbSecondary: 380,
          buttonVerticalPadding: 19,
          buttonMaxWidth: 400,
        );
      case _FormFactor.desktop:
        return const _Layout._(
          contentMaxWidth: 680,
          horizontalPadding: 80,
          verticalPadding: 72,
          iconSize: 140,
          iconInnerSize: 64,
          gap1: 48,
          gap2: 18,
          gap3: 16,
          gap4: 52,
          orbPrimary: 600,
          orbSecondary: 480,
          buttonVerticalPadding: 20,
          buttonMaxWidth: 360,
        );
    }
  }
  const _Layout._({
    required this.contentMaxWidth,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.iconSize,
    required this.iconInnerSize,
    required this.gap1,
    required this.gap2,
    required this.gap3,
    required this.gap4,
    required this.orbPrimary,
    required this.orbSecondary,
    required this.buttonVerticalPadding,
    required this.buttonMaxWidth,
  });

  final double contentMaxWidth;
  final double horizontalPadding;
  final double verticalPadding;
  final double iconSize;
  final double iconInnerSize;

  // Vertical gaps between chunks
  final double gap1; // after icon
  final double gap2; // after headline
  final double gap3; // after body
  final double gap4; // after pill (before CTA)

  final double orbPrimary;
  final double orbSecondary;
  final double buttonVerticalPadding;
  final double buttonMaxWidth;
}

// ── Main screen ───────────────────────────────────────────────────────────────

/// Full-screen blocking gate shown when the installed version is below the
/// minimum required version stored in Supabase.
///
/// Responsive across phone (< 600), tablet (600–1023) and desktop (≥ 1024).
///
/// Design principles applied:
/// - Three-tier adaptive layout tokens (no magic numbers inside the tree).
/// - Dark glassmorphic hero — always dark regardless of system theme so the
///   gate feels distinct and serious.
/// - Animated orb backdrop scales with viewport; respects reduce-motion.
/// - Staggered entrance with 80ms inter-chunk delay.
/// - Physics-based button press (0.97 scale).
/// - Concentric border radius throughout.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({required this.result, super.key});

  final VersionForceRequired result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final reduceMotion = context.reduceMotion;
    final layout = _Layout.from(context.formFactor);

    final message = result.updateMessage ??
        'Please update Kortex to continue. '
            'This version is no longer supported.';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor:
            isDark ? colors.backgroundPrimary : const Color(0xFF0D0D18),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Animated orb backdrop (scales with viewport) ─────────────
            if (!reduceMotion) ...[
              Positioned(
                top: -layout.orbPrimary * 0.35,
                left: -layout.orbPrimary * 0.24,
                child: _AnimatedOrb(
                  color: colors.primary.withAlpha(isDark ? 55 : 40),
                  size: layout.orbPrimary,
                  duration: const Duration(seconds: 7),
                ),
              ),
              Positioned(
                bottom: layout.orbSecondary * 0.23,
                right: -layout.orbSecondary * 0.23,
                child: _AnimatedOrb(
                  color: colors.syllabotAccent.withAlpha(isDark ? 40 : 30),
                  size: layout.orbSecondary,
                  duration: const Duration(seconds: 9),
                ),
              ),
            ],

            // ── Content ──────────────────────────────────────────────────
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.horizontalPadding,
                    vertical: layout.verticalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: layout.contentMaxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon badge — chunk 0
                        _UpdateIcon(
                          colors: colors,
                          reduceMotion: reduceMotion,
                          size: layout.iconSize,
                          innerSize: layout.iconInnerSize,
                        ),

                        SizedBox(height: layout.gap1),

                        // Headline — chunk 1
                        Text(
                          'Update Required',
                          textAlign: TextAlign.center,
                          style: typography.title1.bold.copyWith(
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        )
                            .animate(delay: reduceMotion ? 0.ms : 80.ms)
                            .fadeIn(duration: 340.ms, curve: Curves.easeOut)
                            .slideY(
                              begin: 0.06,
                              end: 0,
                              duration: 340.ms,
                              curve: Curves.easeOutQuint,
                            ),

                        SizedBox(height: layout.gap2),

                        // Body — chunk 2
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: typography.body.regular.copyWith(
                            color: Colors.white.withAlpha(180),
                            height: 1.55,
                          ),
                        )
                            .animate(delay: reduceMotion ? 0.ms : 160.ms)
                            .fadeIn(duration: 340.ms, curve: Curves.easeOut)
                            .slideY(
                              begin: 0.06,
                              end: 0,
                              duration: 340.ms,
                              curve: Curves.easeOutQuint,
                            ),

                        SizedBox(height: layout.gap3),

                        // Version info pill — chunk 3
                        _VersionPill(
                          installed: result.installedVersion,
                          minimum: result.minimumVersion,
                          colors: colors,
                          typography: typography,
                          reduceMotion: reduceMotion,
                        ),

                        SizedBox(height: layout.gap4),

                        // CTA — chunk 4 (capped width on tablet/desktop)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: layout.buttonMaxWidth,
                          ),
                          child: _UpdateButton(
                            storeUrl: result.storeUrl,
                            colors: colors,
                            typography: typography,
                            reduceMotion: reduceMotion,
                            verticalPadding: layout.buttonVerticalPadding,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Fine-print
                        Text(
                          'You cannot use this app until you update.',
                          textAlign: TextAlign.center,
                          style: typography.caption.regular.copyWith(
                            color: Colors.white.withAlpha(90),
                            fontSize: 11,
                          ),
                        )
                            .animate(delay: reduceMotion ? 0.ms : 400.ms)
                            .fadeIn(duration: 300.ms, curve: Curves.easeOut),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Icon Badge ────────────────────────────────────────────────────────────────

class _UpdateIcon extends StatelessWidget {
  const _UpdateIcon({
    required this.colors,
    required this.reduceMotion,
    required this.size,
    required this.innerSize,
  });

  final AppThemeColorsExtension colors;
  final bool reduceMotion;
  final double size;
  final double innerSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primary.withAlpha(200),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withAlpha(100),
            blurRadius: size * 0.33,
            offset: Offset(0, size * 0.083),
          ),
        ],
      ),
      child: Icon(
        Icons.system_update_rounded,
        color: Colors.white,
        size: innerSize,
      ),
    )
        .animate()
        .fadeIn(
          duration: reduceMotion ? 0.ms : 400.ms,
          curve: Curves.easeOut,
        )
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          duration: reduceMotion ? 0.ms : 400.ms,
          curve: Curves.easeOutQuint,
        );
  }
}

// ── Version Info Pill ─────────────────────────────────────────────────────────

class _VersionPill extends StatelessWidget {
  const _VersionPill({
    required this.installed,
    required this.minimum,
    required this.colors,
    required this.typography,
    required this.reduceMotion,
  });

  final String installed;
  final String minimum;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillChip(
            label: 'Installed',
            version: installed,
            color: colors.warning,
            typography: typography,
          ),
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white.withAlpha(25),
          ),
          _PillChip(
            label: 'Required',
            version: minimum,
            color: colors.recallEasy,
            typography: typography,
          ),
        ],
      ),
    )
        .animate(delay: reduceMotion ? 0.ms : 240.ms)
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOutQuint,
        );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.version,
    required this.color,
    required this.typography,
  });

  final String label;
  final String version;
  final Color color;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: typography.caption.regular.copyWith(
            color: Colors.white.withAlpha(130),
            fontSize: 10,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'v$version',
          style: typography.subhead.bold.copyWith(color: color),
        ),
      ],
    );
  }
}

// ── Update CTA Button ─────────────────────────────────────────────────────────

class _UpdateButton extends StatefulWidget {
  const _UpdateButton({
    required this.storeUrl,
    required this.colors,
    required this.typography,
    required this.reduceMotion,
    required this.verticalPadding,
  });

  final String storeUrl;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool reduceMotion;
  final double verticalPadding;

  @override
  State<_UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends State<_UpdateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _openStore() async {
    if (widget.storeUrl.isEmpty) return;

    // HapticFeedback is a no-op on desktop — safe to call on all platforms.
    await HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(widget.storeUrl);
      final canOpen = await canLaunchUrl(uri);
      if (canOpen) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on Object catch (_) {
      // Silent — user can tap again.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) async {
          await _pressController.reverse();
          await _openStore();
        },
        onTapCancel: () => unawaited(_pressController.reverse()),
        child: AnimatedContainer(
          duration: AppMotion.snappy,
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.colors.primary,
                widget.colors.primary.withAlpha(200),
              ],
            ),
            borderRadius: AppRadius.radiusPanel,
            boxShadow: [
              BoxShadow(
                color: widget.colors.primary.withAlpha(90),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: AppMotion.snappy,
            child: _isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Update Now',
                        style: widget.typography.body.bold.copyWith(
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    )
        .animate(delay: widget.reduceMotion ? 0.ms : 320.ms)
        .fadeIn(duration: 340.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: 340.ms,
          curve: Curves.easeOutQuint,
        );
  }
}

// ── Decorative animated orb ───────────────────────────────────────────────────

class _AnimatedOrb extends StatefulWidget {
  const _AnimatedOrb({
    required this.color,
    required this.size,
    required this.duration,
  });

  final Color color;
  final double size;
  final Duration duration;

  @override
  State<_AnimatedOrb> createState() => _AnimatedOrbState();
}

class _AnimatedOrbState extends State<_AnimatedOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    unawaited(_ctrl.repeat(reverse: true));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final drift = math.sin(_anim.value * math.pi) * 20;
        return Transform.translate(
          offset: Offset(drift, -drift * 0.5),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [widget.color, Colors.transparent],
              ),
            ),
          ),
        );
      },
    );
  }
}
