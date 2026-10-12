import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/device_capability_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/convert_to_deck_action_sheet.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/local_llm_capacity_prompt_modal_sheet.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue_modal.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Coordinator decoupling actions, modal launches, and engine switching for Syllabot Chat.
class SyllabotChatActionCoordinator {
  const SyllabotChatActionCoordinator({
    this.subscriptionGuard,
    this.localLlmEngineClient,
    this.deviceCapabilityService,
    this.localStorageService,
    this.communityRepository,
  });

  final SubscriptionGuard? subscriptionGuard;
  final LocalLlmEngineClient? localLlmEngineClient;
  final DeviceCapabilityService? deviceCapabilityService;
  final LocalStorageService? localStorageService;
  final CommunityRepository? communityRepository;

  SubscriptionGuard get guard =>
      subscriptionGuard ??
      (locator.isRegistered<SubscriptionGuard>()
          ? locator<SubscriptionGuard>()
          : SubscriptionGuard());

  LocalLlmEngineClient get localClient =>
      localLlmEngineClient ??
      (locator.isRegistered<LocalLlmEngineClient>()
          ? locator<LocalLlmEngineClient>()
          : LocalLlmEngineClient());

  DeviceCapabilityService get capabilityService =>
      deviceCapabilityService ?? DeviceCapabilityService();

  LocalStorageService? get storage =>
      localStorageService ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null);

  CommunityRepository? get community =>
      communityRepository ??
      (locator.isRegistered<CommunityRepository>()
          ? locator<CommunityRepository>()
          : null);

  Future<void> handleEngineSwitch(
    BuildContext pageContext,
    ExecutionEngineType targetEngine,
  ) async {
    final l10n = pageContext.l10n;

    if (targetEngine == ExecutionEngineType.cloudRemote) {
      if (!pageContext.mounted) return;
      pageContext.read<SyllabotChatBloc>().add(
        const ChangeEngineTypeEvent(ExecutionEngineType.cloudRemote),
      );
      pageContext.showSnackBar(
        message: l10n.engineSwitched(l10n.engineCloudSupabase),
      );
      return;
    }

    // If download is currently active, prevent switching to local engine
    if (LocalLlmEngineClient.isGlobalDownloadActive) {
      if (pageContext.mounted) {
        pageContext.showSnackBar(
          message:
              'Model download is in progress. Using Cloud AI until download completes.',
        );
        pageContext.read<SyllabotChatBloc>().add(
          const ChangeEngineTypeEvent(ExecutionEngineType.cloudRemote),
        );
      }
      return;
    }

    // Check device capacity (CPU cores, available memory, storage)
    final report = await capabilityService.auditDeviceCapacity();

    if (!report.isSupported) {
      if (pageContext.mounted) {
        pageContext.showSnackBar(
          message: report.unsupportedReason ??
              'Your device does not meet the hardware requirements for On-Device AI.',
          type: SnackBarType.error,
        );
      }
      return;
    }

    // Check if model weights are already downloaded
    final isDownloaded = await localClient.checkModelDownloaded();

    if (!isDownloaded) {
      if (pageContext.mounted) {
        // Default to Cloud AI while prompt modal is open or downloading
        pageContext.read<SyllabotChatBloc>().add(
          const ChangeEngineTypeEvent(ExecutionEngineType.cloudRemote),
        );

        final downloaded = await LocalLlmCapacityPromptModalSheet.show(
          pageContext,
          onDownloadComplete: () {
            if (pageContext.mounted) {
              pageContext.read<SyllabotChatBloc>().add(
                const ChangeEngineTypeEvent(
                  ExecutionEngineType.localOnDevice,
                ),
              );
            }
          },
        );
        if (downloaded == true && pageContext.mounted) {
          pageContext.read<SyllabotChatBloc>().add(
            const ChangeEngineTypeEvent(ExecutionEngineType.localOnDevice),
          );
        }
      }
      return;
    }

    // Already downloaded & hardware supported -> switch to on-device AI
    if (pageContext.mounted) {
      pageContext.read<SyllabotChatBloc>().add(
        const ChangeEngineTypeEvent(ExecutionEngineType.localOnDevice),
      );
      pageContext.showSnackBar(
        message: l10n.engineSwitched(l10n.engineLocalOnDevice),
        type: SnackBarType.success,
      );
    }
  }

  void cancelModelDownload(
    BuildContext pageContext,
    ValueNotifier<bool> isDownloadingModel,
  ) {
    isDownloadingModel.value = false;
    pageContext.showSnackBar(
      message: 'On-Device Engine download cancelled.',
    );
  }

  Future<void> openVoiceDialogue(
    BuildContext dialogContext,
    SyllabotChatState state,
    TextToSpeechHandler ttsHandler,
  ) async {
    if (!guard.canAccessVoiceDialogue()) {
      final isPro = await guard.requirePro(
        dialogContext,
        featureName: 'Syllabot Voice Dialogue',
      );
      if (!isPro || !dialogContext.mounted) return;
    }

    final persistentSessionId = UuidUtils.isValidUuid(state.sessionId)
        ? state.sessionId
        : UuidUtils.generate();

    if (!dialogContext.mounted) return;
    unawaited(
      VoiceDialogueModal.show(
        context: dialogContext,
        ttsHandler: ttsHandler,
        initialMode: state.socraticMode,
        engineType: state.engineType,
        onStreamPrompt: (voicePrompt) {
          final bloc = dialogContext.read<SyllabotChatBloc>();
          final latestState = bloc.state;
          final sid = UuidUtils.isValidUuid(latestState.sessionId)
              ? latestState.sessionId
              : persistentSessionId;

          final controller = StreamController<String>();
          late final StreamSubscription<String> tokenSub;
          late final StreamSubscription<SyllabotChatState> stateSub;

          void cleanup() {
            unawaited(tokenSub.cancel());
            unawaited(stateSub.cancel());
            if (!controller.isClosed) {
              unawaited(controller.close());
            }
          }

          tokenSub = bloc.streamTokens.listen(
            (token) {
              if (!controller.isClosed) {
                controller.add(token);
              }
            },
            onError: (Object err) {
              if (!controller.isClosed) {
                controller.addError(err);
                cleanup();
              }
            },
          );

          stateSub = bloc.stream.listen((state) {
            if (state.status == SyllabotStatus.idle ||
                state.status == SyllabotStatus.error) {
              if (state.status == SyllabotStatus.error &&
                  !controller.isClosed) {
                final errorMsg =
                    state.messages.where((m) => m.isError).lastOrNull?.text;
                controller.addError(
                  errorMsg ?? 'Failed to stream Syllabot response',
                );
              }
              cleanup();
            }
          });

          bloc.add(
            SubmitPromptEvent(
              prompt: voicePrompt,
              sessionId: sid,
              socraticMode: latestState.socraticMode,
              engineType: latestState.engineType,
            ),
          );

          return controller.stream;
        },
      ),
    );
  }

  Future<void> openConvertToDeck(
    BuildContext sheetContext,
    SyllabotChatState state,
  ) async {
    final l10n = sheetContext.l10n;

    if (!guard.canConvertChatToDeck()) {
      final isPro = await guard.requirePro(
        sheetContext,
        featureName: 'Chat to Deck AI Synthesis',
      );
      if (!isPro || !sheetContext.mounted) return;
    }

    if (state.isGeneratingDeck) {
      sheetContext.showSnackBar(
        message: l10n.generatingDeckProgress,
      );
      return;
    }

    if (state.messages.isEmpty) {
      sheetContext.showSnackBar(
        message: 'Start a conversation with Syllabot to generate cards',
      );
      return;
    }

    final targetSessionId = state.sessionId;
    final isAlreadyConverted = state.isConvertedToDeck ||
        (storage?.getPreference(key: 'syllabot_converted_$targetSessionId') !=
            null);
    if (isAlreadyConverted) {
      sheetContext.showSnackBar(
        message: l10n.deckAlreadyGeneratedFromChat,
      );
      return;
    }

    final userPrompts = state.messages
        .where((m) => m.sender == MessageSender.user)
        .map((m) => m.text.trim())
        .toList();

    final fullConversationText =
        state.messages.map((m) => m.text.toLowerCase()).join(' ');

    var derivedTitle = 'Study Notes';
    var derivedCourseCode = 'GEN 101';

    if (userPrompts.isNotEmpty) {
      if (userPrompts.length == 1) {
        final clean =
            userPrompts.first.replaceAll(RegExp(r'[?!.]+$'), '').trim();
        derivedTitle =
            clean.length > 38 ? '${clean.substring(0, 35)}...' : clean;
      } else {
        final clean1 =
            userPrompts.first.replaceAll(RegExp(r'[?!.]+$'), '').trim();
        final cleanLast =
            userPrompts.last.replaceAll(RegExp(r'[?!.]+$'), '').trim();
        if (clean1.toLowerCase() == cleanLast.toLowerCase()) {
          derivedTitle =
              clean1.length > 38 ? '${clean1.substring(0, 35)}...' : clean1;
        } else {
          final combined = '$clean1 & $cleanLast';
          derivedTitle = combined.length > 42
              ? '${combined.substring(0, 39)}...'
              : combined;
        }
      }

      final lower = fullConversationText;
      if (lower.contains('part of speech') ||
          lower.contains('parts of speech') ||
          lower.contains('grammar') ||
          lower.contains('noun') ||
          lower.contains('verb') ||
          lower.contains('adjective') ||
          lower.contains('preposition')) {
        derivedCourseCode = 'ENG 101';
        if (lower.contains('part of speech') ||
            lower.contains('parts of speech')) {
          derivedTitle = 'Parts of Speech & Grammar';
        }
      } else if (lower.contains('circle') ||
          lower.contains('theorem') ||
          lower.contains('geometry') ||
          lower.contains('angle') ||
          lower.contains('math')) {
        derivedCourseCode = 'MATH 101';
      } else if (lower.contains('physics') ||
          lower.contains('euler') ||
          lower.contains('lagrange') ||
          lower.contains('force') ||
          lower.contains('mechanic')) {
        derivedCourseCode = 'PHYS 201';
      } else if (lower.contains('bio') ||
          lower.contains('cell') ||
          lower.contains('mitosis') ||
          lower.contains('dna')) {
        derivedCourseCode = 'BIO 101';
      } else if (lower.contains('chem') || lower.contains('reaction')) {
        derivedCourseCode = 'CHEM 101';
      } else if (lower.contains('algo') ||
          lower.contains('code') ||
          lower.contains('binary')) {
        derivedCourseCode = 'CS 101';
      }
    }

    unawaited(
      ConvertToDeckActionSheet.show(
        sheetContext,
        initialTitle: derivedTitle,
        initialCourseCode: derivedCourseCode,
        onGenerateDeck: (title, courseCode, {createForum = false}) {
          sheetContext.read<SyllabotChatBloc>().add(
            ConvertToDeckEvent(
              sessionId: state.sessionId,
              deckTitle: title,
              courseCode: courseCode,
            ),
          );
          if (createForum) {
            final repo = community;
            if (repo != null) {
              unawaited(
                repo.createForumPost(
                  title: 'Study Forum: $title ($courseCode)',
                  content:
                      'Official campus discussion and question forum for study deck: $title.',
                  track: courseCode.isNotEmpty ? courseCode : 'General',
                ),
              );
            }
          }
        },
      ),
    );
  }
}
