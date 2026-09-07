import 'dart:io';
import 'package:flutter/foundation.dart';

/// Available synthesized voice gender for Syllabot AI speech.
enum VoiceGender {
  female,
  male,
}

/// Configuration model for Syllabot's Text-to-Speech synthesis parameters.
///
/// Provides platform-calibrated baselines to ensure warm, natural,
/// conversational speech without robotic formant shifting or breathless pacing.
@immutable
class TtsConfig {
  const TtsConfig({
    required this.gender,
    required this.speechRateMultiplier,
    required this.baseSpeechRate,
    required this.pitch,
    required this.volume,
    this.language = 'en-US',
  });

  /// Factory creating calibrated default settings tailored to the host platform.
  factory TtsConfig.forCurrentPlatform({
    VoiceGender gender = VoiceGender.female,
    double speechRateMultiplier = 1.0,
    String language = 'en-US',
  }) {
    final isIos = !kIsWeb && Platform.isIOS;

    // Platform-calibrated baselines:
    // - iOS AVSpeechSynthesizer: 0.47 yields a relaxed, warm conversational tempo.
    // - Android TextToSpeech: 0.82 delivers calm, articulate pacing on Google Speech Services.
    final baseRate = isIos
        ? (gender == VoiceGender.female ? 0.47 : 0.46)
        : (gender == VoiceGender.female ? 0.82 : 0.80);

    // Keep pitch at 1.0 to preserve natural acoustic vocal tract formants
    // and prevent metallic/vocoder distortion.
    const naturalPitch = 1.0;
    const standardVolume = 1.0;

    return TtsConfig(
      gender: gender,
      speechRateMultiplier: speechRateMultiplier,
      baseSpeechRate: baseRate,
      pitch: naturalPitch,
      volume: standardVolume,
      language: language,
    );
  }

  final VoiceGender gender;

  /// User-configurable speed multiplier (default 1.0).
  final double speechRateMultiplier;

  /// Underlying platform-specific speech rate baseline.
  final double baseSpeechRate;

  /// Effective speech rate passed to FlutterTts (baseRate * multiplier).
  double get effectiveSpeechRate =>
      (baseSpeechRate * speechRateMultiplier).clamp(0.1, 2.0);

  /// Vocal pitch (1.0 = native natural resonance).
  final double pitch;

  /// Output volume (0.0 to 1.0).
  final double volume;

  /// Speech locale code (e.g. 'en-US').
  final String language;

  TtsConfig copyWith({
    VoiceGender? gender,
    double? speechRateMultiplier,
    double? baseSpeechRate,
    double? pitch,
    double? volume,
    String? language,
  }) {
    return TtsConfig(
      gender: gender ?? this.gender,
      speechRateMultiplier: speechRateMultiplier ?? this.speechRateMultiplier,
      baseSpeechRate: baseSpeechRate ?? this.baseSpeechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsConfig &&
          runtimeType == other.runtimeType &&
          gender == other.gender &&
          speechRateMultiplier == other.speechRateMultiplier &&
          baseSpeechRate == other.baseSpeechRate &&
          pitch == other.pitch &&
          volume == other.volume &&
          language == other.language;

  @override
  int get hashCode => Object.hash(
        gender,
        speechRateMultiplier,
        baseSpeechRate,
        pitch,
        volume,
        language,
      );
}
