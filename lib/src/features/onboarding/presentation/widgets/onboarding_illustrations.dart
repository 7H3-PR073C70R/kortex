import 'package:flutter/material.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/illustration_common.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/ingestion_painter.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/ocr_painter.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/retention_painter.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/socratic_painter.dart';

export 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/illustration_common.dart';
export 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/ingestion_painter.dart';
export 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/ocr_painter.dart';
export 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/retention_painter.dart';
export 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/socratic_painter.dart';

/// Text-matched onboarding motion graphics.
///
/// Each scene is a self-contained, looping vector animation drawn with
/// [CustomPainter] so it stays crisp at any size and honors the
/// "reduce motion" accessibility setting (it settles on its final frame
/// instead of animating). There is deliberately no ambient glow, aura, or
/// gradient bloom — the artwork carries meaning through motion alone, and
/// every scene illustrates the literal promise of its slide copy:
///
///  1. Drop → Parse → Master  (document ingestion into recall cards)
///  2. A scanner resolves math/chemistry glyphs line by line (OCR)
///  3. The Ebbinghaus forgetting curve held up by timed reviews (FSRS)
///  4. A confidence gauge calibrating toward exam-ready (Socratic)
class OnboardingIllustrations {
  const OnboardingIllustrations._();

  /// Slide 1: Drop. Parse. Master.
  static Widget documentIngestion({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return AnimatedScene(
      durationMs: 4200,
      width: width,
      height: height,
      painter: (colors, t) => IngestionPainter(t, colors),
    );
  }

  /// Slide 2: Flawless Math & Science OCR.
  static Widget stemOcr({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return AnimatedScene(
      durationMs: 4000,
      width: width,
      height: height,
      painter: (colors, t) => OcrPainter(t, colors),
    );
  }

  /// Slide 3: Forget About Forgetting.
  static Widget spacedRepetition({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return AnimatedScene(
      durationMs: 5200,
      width: width,
      height: height,
      painter: (colors, t) => RetentionPainter(t, colors),
    );
  }

  /// Slide 4: Calibrate Your Confidence.
  static Widget socraticAi({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return AnimatedScene(
      durationMs: 4600,
      width: width,
      height: height,
      painter: (colors, t) => SocraticPainter(t, colors),
    );
  }
}
