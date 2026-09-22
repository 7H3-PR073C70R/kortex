import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Non-blocking sprint milestone strip.
///
/// Motivation check-ins must never seize the interaction: this banner slides
/// in under the progress bar, holds briefly, fades itself away, and is
/// dismissible — the review flow is never interrupted by a modal.
class SprintMilestoneBanner extends StatefulWidget {
  const SprintMilestoneBanner({
    required this.cardsCrushed,
    required this.onFinishSprint,
    required this.onDismiss,
    super.key,
  });

  final int cardsCrushed;
  final VoidCallback onFinishSprint;

  /// Called when the banner has fully auto-dismissed so the parent can
  /// remove it from the tree.
  final VoidCallback onDismiss;

  static const Duration _lifetime = Duration(milliseconds: 4200);

  @override
  State<SprintMilestoneBanner> createState() => _SprintMilestoneBannerState();
}

class _SprintMilestoneBannerState extends State<SprintMilestoneBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SprintMilestoneBanner._lifetime,
  )..forward();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SprintMilestoneBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardsCrushed != widget.cardsCrushed) {
      // New milestone while the previous one is still visible: re-enter
      // from the current frame, never from a blank reset.
      _controller.value = 0;
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    // Entrance occupies the first ~8% of the lifetime, exit fade the last ~12%.
    final opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutQuint)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween(1), weight: 80),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
    ]).animate(_controller);

    final slide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, -0.35),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutQuint)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 92),
    ]).animate(_controller);

    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: slide,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? colors.warning.withAlpha(38)
                : colors.warning.withAlpha(20),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.warning.withAlpha(90)),
          ),
          child: Row(
            children: [
              const _FlamePulse(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.studyMilestoneCrushed(widget.cardsCrushed),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.bold.copyWith(
                    color: colors.warning,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: l10n.studyMilestoneFinish,
                child: ShrinkableButton(
                  onTap: () {
                    widget.onFinishSprint();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      l10n.studyMilestoneFinish,
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 11.5,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gentle breathing dot behind the flame icon; frozen when the user asked
/// for reduced motion or when the banner is off-screen.
class _FlamePulse extends StatefulWidget {
  const _FlamePulse();

  @override
  State<_FlamePulse> createState() => _FlamePulseState();
}

class _FlamePulseState extends State<_FlamePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.08).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Icon(
        Icons.local_fire_department_rounded,
        size: 16,
        color: context.colors.warning,
      ),
    );
  }
}
