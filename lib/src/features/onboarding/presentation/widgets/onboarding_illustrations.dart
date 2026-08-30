import 'package:flutter/material.dart';
import 'package:kortex/src/gen/assets.gen.dart';

/// Modular SVG illustration builders loading from `assets/svgs/`.
class OnboardingIllustrations {
  const OnboardingIllustrations._();

  /// Slide 1: Document ingestion illustration.
  static Widget documentIngestion({
    BuildContext? context,
    double width = 240,
    double height = 180,
  }) {
    return AppAssets.svgs.onboardingIngestion.svg(
      width: width,
      height: height,
    );
  }

  /// Slide 2: Multimodal STEM OCR illustration.
  static Widget stemOcr({
    BuildContext? context,
    double width = 240,
    double height = 180,
  }) {
    return AppAssets.svgs.onboardingOcr.svg(
      width: width,
      height: height,
    );
  }

  /// Slide 3: Spaced repetition (SM-2) retention curve.
  static Widget spacedRepetition({
    BuildContext? context,
    double width = 240,
    double height = 180,
  }) {
    return AppAssets.svgs.onboardingRetention.svg(
      width: width,
      height: height,
    );
  }

  /// Slide 4: Socratic AI & Exam simulation gauge.
  static Widget socraticAi({
    BuildContext? context,
    double width = 240,
    double height = 180,
  }) {
    return AppAssets.svgs.onboardingSocratic.svg(
      width: width,
      height: height,
    );
  }
}
