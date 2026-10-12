import 'dart:async';
import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/on_device_neural_models_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/socratic_reasoning_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/syllabot_settings_section_container.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/voice_dialogue_audio_tuning_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/voice_dialogue_persona_section.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Subpage for Syllabot AI settings, consolidated Socratic reasoning preferences,
/// and voice dialogue controls.
@RoutePage()
class SyllabotAiSettingsPage extends HookWidget {
  const SyllabotAiSettingsPage({
    this.localStorageService,
    this.localLlmEngineClient,
    this.ttsHandler,
    super.key,
  });

  final LocalStorageService? localStorageService;
  final LocalLlmEngineClient? localLlmEngineClient;
  final TextToSpeechHandler? ttsHandler;

  LocalStorageService? get _localStorageService =>
      localStorageService ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null);

  LocalLlmEngineClient get _localLlmEngineClient =>
      localLlmEngineClient ??
      (locator.isRegistered<LocalLlmEngineClient>()
          ? locator<LocalLlmEngineClient>()
          : LocalLlmEngineClient());

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final storage = _localStorageService;

    final initialMode = () {
      final raw = storage?.getPreference(key: PrefKeys.syllabotSocraticMode);
      if (raw != null) {
        return SocraticMode.values.firstWhere(
          (m) => m.name == raw,
          orElse: () => SocraticMode.stepByStep,
        );
      }
      return SocraticMode.stepByStep;
    }();

    final initialGender = () {
      final raw = storage?.getPreference(key: PrefKeys.syllabotVoiceGender);
      if (raw != null) {
        return VoiceGender.values.firstWhere(
          (g) => g.name == raw,
          orElse: () => VoiceGender.female,
        );
      }
      return VoiceGender.female;
    }();

    final initialRate = () {
      final raw = storage?.getPreference(key: PrefKeys.syllabotSpeechRate);
      if (raw != null) {
        final parsed = double.tryParse(raw);
        if (parsed != null && parsed > 0) return parsed;
      }
      return 1.0;
    }();

    final initialPitch = () {
      final raw = storage?.getPreference(key: PrefKeys.syllabotVoicePitch);
      if (raw != null) {
        final parsed = double.tryParse(raw);
        if (parsed != null && parsed > 0) return parsed;
      }
      return 1.0;
    }();

    final initialVoiceName = () {
      final raw =
          storage?.getPreference(key: PrefKeys.kokoroVoiceName) ??
          storage?.getPreference(key: PrefKeys.syllabotVoiceName);
      return (raw != null && raw.isNotEmpty) ? raw : 'Bella';
    }();

    final initialPersona = () {
      final raw = storage?.getPreference(key: '__syllabot_tutor_persona');
      return raw ?? 'Socratic Tutor';
    }();

    final socraticMode = useState<SocraticMode>(initialMode);
    final voiceGender = useState<VoiceGender>(initialGender);
    final speechRate = useState<double>(initialRate);
    final speechPitch = useState<double>(initialPitch);
    final selectedVoiceName = useState<String?>(initialVoiceName);
    final tutorPersona = useState<String>(initialPersona);
    final isPlayingPreview = useState<bool>(false);
    final availableVoices = useState<List<Map<String, dynamic>>>([]);
    final isLoadingVoices = useState<bool>(true);

    final localModels = useState<List<LocalLlmModelInfo>>([]);
    final isLoadingLocalModels = useState<bool>(true);
    final isGlobalDownloadActive = useState<bool>(
      LocalLlmEngineClient.isGlobalDownloadActive,
    );
    final activeDownloadingModelId = useState<String?>(
      LocalLlmEngineClient.activeDownloadingModelId,
    );

    final localClient = useMemoized(() => _localLlmEngineClient, const []);

    final refreshLocalModels = useCallback(() async {
      final models = await localClient.getAvailableModels();
      localModels.value = models;
      isLoadingLocalModels.value = false;
    }, [localClient]);

    useEffect(() {
      var isMounted = true;
      unawaited(refreshLocalModels());

      final sub = LocalLlmEngineClient.downloadProgressStream.listen((state) {
        if (isMounted) {
          if (isGlobalDownloadActive.value != state.isDownloading ||
              activeDownloadingModelId.value != state.modelId) {
            isGlobalDownloadActive.value = state.isDownloading;
            activeDownloadingModelId.value = state.isDownloading
                ? state.modelId
                : null;
          }
          if (!state.isDownloading) {
            unawaited(refreshLocalModels());
          }
        }
      });

      return () {
        isMounted = false;
        unawaited(sub.cancel());
      };
    }, const []);

    final resolvedTtsHandler = useMemoized(
      () =>
          ttsHandler ??
          TextToSpeechHandler(
            localStorageService: storage,
            onSpeakingChanged: (speaking) {
              isPlayingPreview.value = speaking;
            },
          ),
      [ttsHandler],
    );

    useEffect(() {
      var isMounted = true;
      unawaited(
        resolvedTtsHandler.getAvailableVoices().then((voices) {
          if (isMounted) {
            availableVoices.value = voices;
            isLoadingVoices.value = false;
          }
        }),
      );
      return () {
        isMounted = false;
        unawaited(resolvedTtsHandler.stop());
        if (ttsHandler == null) {
          resolvedTtsHandler.dispose();
        }
      };
    }, [resolvedTtsHandler]);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppAdaptiveAppBar(
        backgroundColor: colors.backgroundPrimary,
        titleText: 'Syllabot AI & Neural Engine',
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Profile & Settings',
            onTap: () => unawaited(context.router.maybePop()),
          ),
          const AppBreadcrumbItem(label: 'Syllabot AI & Neural Engine'),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Socratic Reasoning Preference
                  SocraticReasoningSection(
                    socraticMode: socraticMode,
                    localStorageService: storage,
                  ),
                  const SizedBox(height: 20),

                  // Section 2: On-Device Local LLM Models & Engine Management
                  if (!kIsWeb) ...[
                    OnDeviceNeuralModelsSection(
                      localModels: localModels.value,
                      isLoadingLocalModels: isLoadingLocalModels.value,
                      activeDownloadingModelId: activeDownloadingModelId.value,
                      localClient: localClient,
                      onRefreshModels: refreshLocalModels,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Section 3: Voice Dialogue Persona & AI Character
                  SyllabotSettingsSectionContainer(
                    title: 'VOICE DIALOGUE & TUTOR PERSONA',
                    subtitle:
                        'Select personality archetype and audio characteristics',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VoiceDialoguePersonaSection(
                          tutorPersona: tutorPersona,
                          ttsHandler: resolvedTtsHandler,
                          isPlayingPreview: isPlayingPreview,
                          speechRate: speechRate,
                          voiceGender: voiceGender,
                          localStorageService: storage,
                        ),
                        VoiceDialogueAudioTuningSection(
                          voiceGender: voiceGender,
                          speechRate: speechRate,
                          speechPitch: speechPitch,
                          selectedVoiceName: selectedVoiceName,
                          ttsHandler: resolvedTtsHandler,
                          isPlayingPreview: isPlayingPreview,
                          localStorageService: storage,
                        ),
                      ],
                    ),
                  ),
                  if (!kIsWeb && Platform.isIOS) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(18),
                        borderRadius: AppRadius.radiusPanel,
                        border: Border.all(
                          color: colors.primary.withAlpha(50),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.tips_and_updates_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'For the most natural voice quality, navigate to Settings → '
                              'Accessibility → Spoken Content → Voices → English '
                              'and download an Enhanced or Premium voice.',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Apply Preferences Primary Action Button
                  PlatformHoverBuilder(
                    builder: (context, isHovered, child) {
                      return AnimatedScale(
                        scale: isHovered ? 1.01 : 1.0,
                        duration: AppMotion.snappy,
                        curve: Curves.easeOutCubic,
                        child: child,
                      );
                    },
                    child: ShrinkableButton(
                      onTap: () async {
                        AppFeedback.light();
                        if (storage != null) {
                          await storage.savePreference(
                            key: PrefKeys.syllabotSocraticMode,
                            data: socraticMode.value.name,
                          );
                          await storage.savePreference(
                            key: PrefKeys.syllabotVoiceGender,
                            data: voiceGender.value.name,
                          );
                          await storage.savePreference(
                            key: PrefKeys.syllabotSpeechRate,
                            data: speechRate.value.toString(),
                          );
                          await storage.savePreference(
                            key: PrefKeys.syllabotVoicePitch,
                            data: speechPitch.value.toString(),
                          );
                          await storage.savePreference(
                            key: PrefKeys.syllabotVoiceName,
                            data: selectedVoiceName.value ?? '',
                          );
                          await storage.savePreference(
                            key: '__syllabot_tutor_persona',
                            data: tutorPersona.value,
                          );
                        }
                        if (context.mounted) {
                          context.showSnackBar(
                            message:
                                'Syllabot AI neural voice preferences updated successfully!',
                            type: SnackBarType.success,
                          );
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: AppRadius.radiusPanel,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(50),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Save Neural Preferences',
                            style: typography.body.bold.copyWith(
                              color: colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
