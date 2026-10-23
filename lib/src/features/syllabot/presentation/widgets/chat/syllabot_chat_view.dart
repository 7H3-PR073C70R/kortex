import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/device_capability_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_chat_action_coordinator.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_chat_app_bar_actions.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_chat_bottom_dock.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_chat_error_banner.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_empty_greeting_view.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_message_list_view.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/syllabot_deck_generation_progress_card.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

/// Presentation view for Syllabot Chat.
class SyllabotChatView extends HookWidget {
  const SyllabotChatView({
    this.initialPrompt,
    this.onCollapse,
    this.actionCoordinator,
    this.calibrationRepository,
    this.subscriptionGuard,
    this.localLlmEngineClient,
    this.deviceCapabilityService,
    this.localStorageService,
    this.communityRepository,
    super.key,
  });

  final String? initialPrompt;
  final VoidCallback? onCollapse;
  final SyllabotChatActionCoordinator? actionCoordinator;
  final CalibrationRepository? calibrationRepository;
  final SubscriptionGuard? subscriptionGuard;
  final LocalLlmEngineClient? localLlmEngineClient;
  final DeviceCapabilityService? deviceCapabilityService;
  final LocalStorageService? localStorageService;
  final CommunityRepository? communityRepository;

  SyllabotChatActionCoordinator get _coordinator =>
      actionCoordinator ??
      SyllabotChatActionCoordinator(
        subscriptionGuard: subscriptionGuard,
        localLlmEngineClient: localLlmEngineClient,
        deviceCapabilityService: deviceCapabilityService,
        localStorageService: localStorageService,
        communityRepository: communityRepository,
      );

  CalibrationRepository? get _calibration =>
      calibrationRepository ??
      (locator.isRegistered<CalibrationRepository>()
          ? locator<CalibrationRepository>()
          : null);

  SubscriptionGuard get _guard =>
      subscriptionGuard ??
      (locator.isRegistered<SubscriptionGuard>()
          ? locator<SubscriptionGuard>()
          : SubscriptionGuard());

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final textController = useTextEditingController();
    final scrollController = useScrollController();
    final ttsHandler = useMemoized(TextToSpeechHandler.new);
    final isAiSpeaking = useValueListenable(ttsHandler.isSpeakingNotifier);

    final calibrationProfileState = useState<CalibrationProfile?>(null);
    final isDownloadingModel =
        useState<bool>(LocalLlmEngineClient.isGlobalDownloadActive);
    final downloadProgress =
        useState<double>(LocalLlmEngineClient.activeDownloadProgress);
    final lastAnnouncedDeckId = useRef<String?>(null);
    final isGeneratingRef = useRef<bool>(false);

    final coordinator = useMemoized(() => _coordinator);

    useEffect(
      () {
        final cal = _calibration;
        if (cal != null) {
          unawaited(
            cal.getCalibrationProfile().then((result) {
              result.fold(
                (_) {},
                (profile) {
                  calibrationProfileState.value = profile;
                },
              );
            }),
          );
        }

        final client = coordinator.localClient;

        // 1. Initial sync of model download state & default fallback to Cloud AI
        if (LocalLlmEngineClient.isGlobalDownloadActive) {
          isDownloadingModel.value = true;
          downloadProgress.value = LocalLlmEngineClient.activeDownloadProgress;
        }

        unawaited(
          client.checkModelDownloaded().then((hasDownloaded) {
            if (context.mounted) {
              final isDownloading = LocalLlmEngineClient.isGlobalDownloadActive;
              if (!hasDownloaded || isDownloading) {
                final bloc = context.read<SyllabotChatBloc>();
                if (bloc.state.engineType == ExecutionEngineType.localOnDevice) {
                  bloc.add(
                    const ChangeEngineTypeEvent(ExecutionEngineType.cloudRemote),
                  );
                }
              }
            }
          }),
        );

        // 2. Fetch server-authoritative Syllabot quota for user
        unawaited(_guard.fetchSyllabotQuota());

        // 3. Listen to global download progress stream across all screens
        final downloadSub =
            LocalLlmEngineClient.downloadProgressStream.listen((state) {
          if (context.mounted) {
            isDownloadingModel.value = state.isDownloading;
            downloadProgress.value = state.progress;

            final bloc = context.read<SyllabotChatBloc>();
            if (state.isDownloading) {
              if (bloc.state.engineType == ExecutionEngineType.localOnDevice) {
                bloc.add(
                  const ChangeEngineTypeEvent(ExecutionEngineType.cloudRemote),
                );
              }
            } else {
              unawaited(
                client.checkModelDownloaded().then((hasDownloaded) {
                  if (context.mounted &&
                      !hasDownloaded &&
                      bloc.state.engineType ==
                          ExecutionEngineType.localOnDevice) {
                    bloc.add(
                      const ChangeEngineTypeEvent(
                        ExecutionEngineType.cloudRemote,
                      ),
                    );
                  }
                }),
              );
            }
          }
        });

        return () {
          unawaited(downloadSub.cancel());
          ttsHandler.dispose();
        };
      },
      [ttsHandler],
    );

    final lastAutoScrollTime = useRef(0);
    final userIsAtBottom = useRef(true);

    void scrollToBottom({bool animate = true, bool force = false}) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && now - lastAutoScrollTime.value < 120) {
        return;
      }
      lastAutoScrollTime.value = now;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients &&
            scrollController.position.hasContentDimensions) {
          final maxExtent = scrollController.position.maxScrollExtent;
          final currentOffset = scrollController.offset;
          final isNearBottom = (maxExtent - currentOffset) < 90;

          if (!force && !isNearBottom && !userIsAtBottom.value) {
            return;
          }

          if (animate) {
            unawaited(
              scrollController.animateTo(
                maxExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutQuad,
              ),
            );
          } else {
            scrollController.jumpTo(maxExtent);
          }
        }
      });
    }

    return BlocListener<SyllabotChatBloc, SyllabotChatState>(
      listenWhen: (previous, current) {
        return previous.messages.length != current.messages.length ||
            previous.streamingText != current.streamingText ||
            previous.status != current.status ||
            previous.generatedDeck != current.generatedDeck;
      },
      listener: (context, state) {
        if (state.status == SyllabotStatus.streaming) {
          scrollToBottom(animate: false);
        } else {
          scrollToBottom(force: true);
        }

        if (state.status == SyllabotStatus.generatingDeck) {
          isGeneratingRef.value = true;
        }

        if (state.status == SyllabotStatus.deckGenerated &&
            state.generatedDeck != null) {
          final deck = state.generatedDeck!;
          if (deck.id != lastAnnouncedDeckId.value) {
            lastAnnouncedDeckId.value = deck.id;
            isGeneratingRef.value = false;
            context.read<SyllabotChatBloc>().add(
              const AcknowledgeDeckGeneratedEvent(),
            );
            context.showSnackBar(
              message:
                  '${l10n.deckCreatedFromSyllabot(deck.title, deck.totalCards)}\n${l10n.deckTapToView}',
              type: SnackBarType.success,
              onTap: () {
                onCollapse?.call();
                if (context.router.canPop()) {
                  unawaited(context.router.maybePop());
                }
                unawaited(
                  context.router.root.navigate(
                    MainRoute(children: [DecksRoute()]),
                  ),
                );
              },
            );
          }
        } else if (state.status == SyllabotStatus.error &&
            isGeneratingRef.value &&
            state.errorMessage != null &&
            state.errorMessage!.isNotEmpty) {
          isGeneratingRef.value = false;
          context.showSnackBar(
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: colors.backgroundPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: onCollapse != null
              ? PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return AnimatedContainer(
                      duration: AppMotion.snappy,
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isHovered
                            ? colors.surfaceSecondary
                            : context.colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 28,
                        ),
                        tooltip: l10n.minimizeChatTooltip,
                        onPressed: onCollapse,
                      ),
                    );
                  },
                )
              : AppBackButton.adaptiveLeading(context),
          leadingWidth: onCollapse != null
              ? null
              : (AppBackButton.shouldShow(context) ? null : 0),
          titleSpacing:
              onCollapse == null && !AppBackButton.shouldShow(context) ? 16 : 0,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SyllabotAvatar(size: 28),
                const SizedBox(width: 8),
                Text(
                  l10n.syllabotTitle,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SyllabotChatAppBarActions(
              subscriptionGuard: _guard,
              onOpenVoiceDialogue: (ctx, st) =>
                  coordinator.openVoiceDialogue(ctx, st, ttsHandler),
              onOpenConvertToDeck: coordinator.openConvertToDeck,
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: [
                  // 1. Main Chat Area (Empty Syllabot Greeting or Message Stream)
                  Expanded(
                    child: BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
                      builder: (context, state) {
                        if (state.messages.isEmpty &&
                            state.streamingText.isEmpty &&
                            state.status != SyllabotStatus.streaming) {
                          return SyllabotEmptyGreetingView(
                            textController: textController,
                            profile: calibrationProfileState.value,
                          );
                        }

                        return SyllabotMessageListView(
                          state: state,
                          scrollController: scrollController,
                          ttsHandler: ttsHandler,
                          onUserAtBottomChanged: (atBottom) {
                            userIsAtBottom.value = atBottom;
                          },
                        );
                      },
                    ),
                  ),

                  // 1.5 Dedicated Flashcard Deck Generation Progress Card
                  BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
                    buildWhen: (p, c) => p.status != c.status,
                    builder: (context, state) {
                      if (!state.isGeneratingDeck) {
                        return const SizedBox.shrink();
                      }
                      return const SyllabotDeckGenerationProgressCard();
                    },
                  ),

                  // 2. Actionable Error Banner with 1-Tap Prompt Retry & Offline Switch
                  BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
                    buildWhen: (p, c) =>
                        p.status != c.status ||
                        p.errorMessage != c.errorMessage ||
                        p.engineType != c.engineType,
                    builder: (context, state) {
                      return SyllabotChatErrorBanner(
                        state: state,
                        onSwitchToLocalEngine: () =>
                            coordinator.handleEngineSwitch(
                          context,
                          ExecutionEngineType.localOnDevice,
                        ),
                        onRetry: () {
                          context.read<SyllabotChatBloc>().add(
                            const RetryLastMessageEvent(),
                          );
                        },
                      );
                    },
                  ),

                  // 3. Syllabot Chat Bottom Bar (Download Progress vs Input Bar)
                  BlocBuilder<SyllabotChatBloc, SyllabotChatState>(
                    builder: (context, state) {
                      final isPro = _guard.isPro;
                      final usedQueries = _guard.getTodaySyllabotQueryCount();
                      final isLocalEngine =
                          state.engineType == ExecutionEngineType.localOnDevice;

                      return SyllabotChatBottomDock(
                        controller: textController,
                        state: state,
                        isDownloadingModel: isDownloadingModel.value,
                        downloadProgress: downloadProgress.value,
                        isAiSpeaking: isAiSpeaking,
                        isPro: isPro,
                        usedQueries: usedQueries,
                        onCancelDownload: () =>
                            coordinator.cancelModelDownload(
                          context,
                          isDownloadingModel,
                        ),
                        onInterruptAi: ttsHandler.stop,
                        onVoiceDialogueTap: state.isGeneratingDeck
                            ? null
                            : () => coordinator.openVoiceDialogue(
                                  context,
                                  state,
                                  ttsHandler,
                                ),
                        onModeChanged: (mode) {
                          context.read<SyllabotChatBloc>().add(
                            ChangeSocraticModeEvent(mode),
                          );
                        },
                        onEngineChanged: (engine) =>
                            coordinator.handleEngineSwitch(context, engine),
                        onUpgradeTap: () => _guard.requirePro(
                          context,
                          featureName: isLocalEngine
                              ? 'Unlimited Cloud AI Queries'
                              : 'Unlimited Syllabot AI Queries',
                        ),
                        onSubmit: state.isGeneratingDeck
                            ? (_) {}
                            : (prompt) async {
                                unawaited(ttsHandler.stop());
                                if (!_guard.canQuerySyllabot(
                                  engineType: state.engineType,
                                )) {
                                  final isProUser = await _guard.requirePro(
                                    context,
                                    featureName:
                                        'Unlimited Syllabot Cloud AI Queries',
                                  );
                                  if (!isProUser || !context.mounted) {
                                    return;
                                  }
                                }

                                unawaited(
                                  _guard.recordSyllabotQuery(
                                    engineType: state.engineType,
                                  ),
                                );

                                final sid = UuidUtils.isValidUuid(
                                  state.sessionId,
                                )
                                    ? state.sessionId
                                    : UuidUtils.generate();

                                if (!context.mounted) return;
                                context.read<SyllabotChatBloc>().add(
                                  SubmitPromptEvent(
                                    prompt: prompt,
                                    sessionId: sid,
                                    socraticMode: state.socraticMode,
                                    engineType: state.engineType,
                                  ),
                                );
                                scrollToBottom();
                              },
                      );
                    },
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
