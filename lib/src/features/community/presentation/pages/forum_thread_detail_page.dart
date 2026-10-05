import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/audio_recording_service.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';
import 'package:kortex/src/core/services/media_upload_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/services/content_moderation_service.dart';
import 'package:kortex/src/features/community/domain/services/forum_socratic_hint_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_flashcard_sheets.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_media_attachment_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/moderation_feedback_dialog.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/subject_master_badge.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder_widget.dart';
import 'package:kortex/src/features/decks/presentation/widgets/audio_pronounce_button.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_audio_reader_button.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Available sorting modes for forum replies
enum ForumSortFilter {
  topVoted('Top voted', Icons.swap_vert_rounded),
  mostRecent('Latest', Icons.schedule_rounded),
  aiFirst('AI First', Icons.auto_awesome_rounded),
  unanswered('Unanswered', Icons.help_outline_rounded)
  ;

  const ForumSortFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}

@RoutePage()
class ForumThreadDetailPage extends HookWidget {
  const ForumThreadDetailPage({
    required this.post,
    this.highlightReplyId,
    this.onClosePanel,
    super.key,
  });

  final ForumPostEntity post;
  final String? highlightReplyId;
  final VoidCallback? onClosePanel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final replyController = useTextEditingController();
    final focusNode = useFocusNode();
    final scrollController = useScrollController();
    final isSubmitting = useState<bool>(false);
    final isGeneratingAiHint = useState<bool>(false);
    final isSubscribed = useState<bool>(false);
    final isBookmarked = useState<bool>(false);
    final sortFilter = useState<ForumSortFilter>(ForumSortFilter.mostRecent);
    final currentPost = useState<ForumPostEntity>(post);
    final localReplies = useState<List<ForumReplyEntity>>(post.replies);
    final replyingToReply = useState<ForumReplyEntity?>(null);

    // On-demand sub-replies state & pagination
    final expandedParentReplyIds = useState<Set<String>>({});
    final loadingParentReplyIds = useState<Set<String>>({});
    final hasMoreSubRepliesMap = useState<Map<String, bool>>({});
    final subReplyOffsets = useState<Map<String, int>>({});

    // Top-level replies pagination & initial loading state
    final topLevelOffset = useState<int>(0);
    final isInitialLoadingReplies = useState<bool>(post.replies.isEmpty);
    final isLoadingMoreTopLevel = useState<bool>(false);
    final hasMoreTopLevel = useState<bool>(true);

    // Reply Media attachments state
    final replyImages = useState<List<String>>([]);
    final replyVoiceNoteUrl = useState<String?>(null);
    final replyVoiceNoteDuration = useState<int>(0);
    final isRecordingReplyVoice = useState<bool>(false);
    final isReplyVoiceLocked = useState<bool>(false);
    final replyVoiceTranscript = useState<String>('');
    final showFormattingTools = useState<bool>(false);
    final isAnonymousReply = useState<bool>(false);
    final replyRecorderController = useMemoized(
      VoiceNoteRecorderController.new,
    );

    final repo = locator<CommunityRepository>();

    Future<void> fetchTopLevelReplies({bool isLoadMore = false}) async {
      if (isLoadMore) {
        if (isLoadingMoreTopLevel.value || !hasMoreTopLevel.value) return;
        isLoadingMoreTopLevel.value = true;
      } else {
        if (localReplies.value.isEmpty) {
          isInitialLoadingReplies.value = true;
        }
      }
      final currentOffset = isLoadMore ? topLevelOffset.value : 0;
      const fetchLimit = 15;

      final res = await repo.fetchForumReplies(
        postId: post.id,
        topLevelOnly: true,
        offset: currentOffset,
        sortFilter: sortFilter.value.name,
      );

      if (isLoadMore) {
        isLoadingMoreTopLevel.value = false;
      } else {
        isInitialLoadingReplies.value = false;
      }

      res.fold(
        (_) {},
        (fetched) {
          if (isLoadMore) {
            final existingIds = localReplies.value.map((r) => r.id).toSet();
            final unique = fetched
                .where((r) => !existingIds.contains(r.id))
                .toList();
            localReplies.value = [...localReplies.value, ...unique];
            topLevelOffset.value = currentOffset + fetched.length;
            hasMoreTopLevel.value = fetched.length >= fetchLimit;
          } else {
            final existingMap = {for (final r in localReplies.value) r.id: r};
            for (final r in fetched) {
              existingMap[r.id] = r;
            }
            localReplies.value = existingMap.values.toList();
            topLevelOffset.value = math.max(
              topLevelOffset.value,
              fetched.length,
            );
            hasMoreTopLevel.value = fetched.length >= fetchLimit;
          }
        },
      );
    }

    // Intelligent Syllabot Socratic Hint generator
    Future<void> generateSyllabotHint() async {
      if (isGeneratingAiHint.value) return;
      isGeneratingAiHint.value = true;
      unawaited(HapticFeedback.mediumImpact());
      try {
        final streamUseCase =
            locator.isRegistered<StreamSyllabotResponseUseCase>()
            ? locator<StreamSyllabotResponseUseCase>()
            : null;
        final localLlmClient = locator.isRegistered<LocalLlmEngineClient>()
            ? locator<LocalLlmEngineClient>()
            : null;

        final finalHintContent = await ForumSocraticHintService.generateHint(
          post: currentPost.value,
          streamUseCase: streamUseCase,
          localLlmClient: localLlmClient,
          onHintGenerated: (hint) =>
              repo.saveForumSocraticHint(postId: post.id, hint: hint),
        );

        final res = await repo.replyToForumPost(
          postId: post.id,
          content: finalHintContent,
        );
        res.fold(
          (failure) {
            if (context.mounted) {
              context.showSnackBar(
                message: failure.message ?? 'Could not post AI hint.',
                type: SnackBarType.error,
              );
            }
          },
          (reply) {
            if (!localReplies.value.any((r) => r.id == reply.id)) {
              localReplies.value = [...localReplies.value, reply];
            }
            if (locator.isRegistered<CommunityHubBloc>()) {
              locator<CommunityHubBloc>().add(
                ForumPostRepliesIncrementedEvent(
                  postId: post.id,
                  reply: reply,
                ),
              );
            }
          },
        );
      } on Object catch (e) {
        if (context.mounted) {
          context.showSnackBar(
            message: e.toString().replaceFirst('Exception: ', ''),
            type: SnackBarType.error,
          );
        }
      } finally {
        isGeneratingAiHint.value = false;
      }
    }

    // Initial check for thread subscription and bookmark state
    useEffect(() {
      Future<void> checkSubscriptionAndBookmark() async {
        final subRes = await repo.isForumPostSubscribed(post.id);
        subRes.fold((_) {}, (sub) => isSubscribed.value = sub);

        final bookRes = await repo.getBookmarkedForumPostIds();
        bookRes.fold(
          (_) {},
          (ids) => isBookmarked.value = ids.contains(post.id),
        );
      }

      Future<void> initialLoadThreadTree() async {
        final treeRes = await repo.fetchForumThreadTree(postId: post.id);
        treeRes.fold(
          (_) => unawaited(fetchTopLevelReplies()),
          (treeData) {
            currentPost.value = treeData.post;
            final existingMap = {for (final r in localReplies.value) r.id: r};
            for (final r in treeData.replies) {
              existingMap[r.id] = r;
            }
            localReplies.value = existingMap.values.toList();
            isInitialLoadingReplies.value = false;
            topLevelOffset.value = math.max(
              topLevelOffset.value,
              treeData.replies.where((r) => !r.isNested).length,
            );

            // Auto-Socratic Guardian: Auto-trigger hint if question thread has 0 replies
            if (treeData.post.isQuestion &&
                treeData.replies.isEmpty &&
                treeData.post.socraticHint == null &&
                !isGeneratingAiHint.value) {
              unawaited(
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (localReplies.value.isEmpty && !isGeneratingAiHint.value) {
                    unawaited(generateSyllabotHint());
                  }
                }),
              );
            }
          },
        );
      }

      // WebSocket Realtime Stream for live thread replies
      final wsSubscription = repo.watchForumReplies(post.id).listen((
        incomingReplies,
      ) {
        if (incomingReplies.isNotEmpty) {
          final existingMap = {for (final r in localReplies.value) r.id: r};
          var updated = false;
          for (final reply in incomingReplies) {
            if (!existingMap.containsKey(reply.id) ||
                existingMap[reply.id] != reply) {
              existingMap[reply.id] = reply;
              updated = true;
            }
          }
          if (updated) {
            localReplies.value = existingMap.values.toList();
          }
        }
      });

      unawaited(checkSubscriptionAndBookmark());
      unawaited(initialLoadThreadTree());
      return () {
        unawaited(wsSubscription.cancel());
      };
    }, [post.id]);

    Future<void> loadSubRepliesForParent(
      String parentReplyId, {
      bool isLoadMore = false,
    }) async {
      if (loadingParentReplyIds.value.contains(parentReplyId)) return;
      loadingParentReplyIds.value = {
        ...loadingParentReplyIds.value,
        parentReplyId,
      };

      final currentOffset = isLoadMore
          ? (subReplyOffsets.value[parentReplyId] ?? 0)
          : 0;
      const limit = 10;

      final res = await repo.fetchForumReplies(
        postId: post.id,
        parentReplyId: parentReplyId,
        limit: limit,
        offset: currentOffset,
      );

      loadingParentReplyIds.value = loadingParentReplyIds.value
          .where((id) => id != parentReplyId)
          .toSet();

      res.fold(
        (failure) {
          if (context.mounted) {
            context.showSnackBar(
              message: failure.message ?? 'Failed to load replies',
              type: SnackBarType.error,
            );
          }
        },
        (fetched) {
          final existingIds = localReplies.value.map((r) => r.id).toSet();
          final newOnes = fetched
              .where((r) => !existingIds.contains(r.id))
              .toList();
          if (newOnes.isNotEmpty) {
            localReplies.value = [...localReplies.value, ...newOnes];
          }
          expandedParentReplyIds.value = {
            ...expandedParentReplyIds.value,
            parentReplyId,
          };
          subReplyOffsets.value = {
            ...subReplyOffsets.value,
            parentReplyId: currentOffset + fetched.length,
          };
          hasMoreSubRepliesMap.value = {
            ...hasMoreSubRepliesMap.value,
            parentReplyId: fetched.length >= limit,
          };
        },
      );
    }

    void toggleSubRepliesExpansion(String parentReplyId) {
      if (expandedParentReplyIds.value.contains(parentReplyId)) {
        expandedParentReplyIds.value = expandedParentReplyIds.value
            .where((id) => id != parentReplyId)
            .toSet();
      } else {
        final existingChildren = localReplies.value
            .where((r) => r.parentReplyId == parentReplyId)
            .toList();
        if (existingChildren.isEmpty) {
          unawaited(loadSubRepliesForParent(parentReplyId));
        } else {
          expandedParentReplyIds.value = {
            ...expandedParentReplyIds.value,
            parentReplyId,
          };
        }
      }
    }

    useEffect(() {
      unawaited(fetchTopLevelReplies());
      return null;
    }, [post.id, sortFilter.value]);

    useEffect(() {
      if (highlightReplyId != null && highlightReplyId!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            unawaited(
              scrollController.animateTo(
                320,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              ),
            );
          }
        });
        for (final reply in localReplies.value) {
          if (reply.repliesCount > 0) {
            expandedParentReplyIds.value = {
              ...expandedParentReplyIds.value,
              reply.id,
            };
          }
        }
      }
      return null;
    }, [highlightReplyId, localReplies.value.length]);

    void votePost(int direction) {
      final p = currentPost.value;
      final prevVote = p.userVote;
      final newVote = (prevVote == direction) ? 0 : direction;
      var newUpvotes = p.upvotes;
      var newDownvotes = p.downvotes;
      if (prevVote == 1) newUpvotes -= 1;
      if (prevVote == -1) newDownvotes -= 1;
      if (newVote == 1) newUpvotes += 1;
      if (newVote == -1) newDownvotes += 1;
      if (newUpvotes < 0) newUpvotes = 0;
      if (newDownvotes < 0) newDownvotes = 0;

      final updated = p.copyWith(
        upvotes: newUpvotes,
        downvotes: newDownvotes,
        userVote: newVote,
      );
      currentPost.value = updated;
      unawaited(HapticFeedback.selectionClick());

      if (locator.isRegistered<CommunityHubBloc>()) {
        locator<CommunityHubBloc>().add(
          VoteForumPostEvent(postId: post.id, direction: direction),
        );
      } else {
        unawaited(
          repo.voteForumPost(postId: post.id, voteDirection: direction),
        );
      }
    }

    void voteReply(ForumReplyEntity targetReply, int direction) {
      final prevVote = targetReply.userVote;
      final newVote = (prevVote == direction) ? 0 : direction;
      var newUpvotes = targetReply.upvotes;
      var newDownvotes = targetReply.downvotes;
      if (prevVote == 1) newUpvotes -= 1;
      if (prevVote == -1) newDownvotes -= 1;
      if (newVote == 1) newUpvotes += 1;
      if (newVote == -1) newDownvotes += 1;
      if (newUpvotes < 0) newUpvotes = 0;
      if (newDownvotes < 0) newDownvotes = 0;

      final updated = targetReply.copyWith(
        upvotes: newUpvotes,
        downvotes: newDownvotes,
        userVote: newVote,
      );

      localReplies.value = localReplies.value
          .map((r) => r.id == targetReply.id ? updated : r)
          .toList();
      unawaited(HapticFeedback.selectionClick());

      if (locator.isRegistered<CommunityHubBloc>()) {
        locator<CommunityHubBloc>().add(
          VoteForumReplyEvent(
            postId: post.id,
            replyId: targetReply.id,
            direction: direction,
          ),
        );
      } else {
        unawaited(
          repo.voteForumReply(
            postId: post.id,
            replyId: targetReply.id,
            voteDirection: direction,
          ),
        );
      }
    }

    Future<void> toggleSubscription() async {
      unawaited(HapticFeedback.lightImpact());
      final newVal = !isSubscribed.value;
      isSubscribed.value = newVal;
      context.showSnackBar(
        message: newVal
            ? 'Notifications turned ON for this discussion'
            : 'Notifications turned OFF for this discussion',
      );
      final res = await repo.toggleForumPostSubscription(post.id);
      res.fold((_) {}, (serverVal) {
        if (isSubscribed.value != serverVal) {
          isSubscribed.value = serverVal;
        }
      });
    }

    Future<void> toggleBookmark() async {
      unawaited(HapticFeedback.selectionClick());
      final newVal = !isBookmarked.value;
      isBookmarked.value = newVal;
      context.showSnackBar(
        message: newVal
            ? 'Thread saved to bookmarks'
            : 'Thread removed from bookmarks',
      );
      try {
        final hubBloc = context.read<CommunityHubBloc?>();
        if (hubBloc != null) {
          hubBloc.add(ToggleBookmarkForumPostEvent(post.id));
        }
      } on Object catch (_) {}
      await repo.toggleBookmarkForumPost(post.id);
    }

    Future<void> saveSolutionToFlashcard(ForumReplyEntity reply) async {
      await ForumSaveFlashcardSheet.show(
        context,
        post: currentPost.value,
        reply: reply,
      );
    }

    Future<void> confirmDeletePost(BuildContext context) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: isDark
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Discussion?',
            style: typography.title3.bold.copyWith(color: colors.textPrimary),
          ),
          content: Text(
            'This action cannot be undone. Are you sure you want to permanently delete this discussion?',
            style: typography.body.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                'Cancel',
                style: typography.body.medium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        final res = await repo.deleteForumPost(post.id);
        res.fold(
          (failure) {
            if (context.mounted) {
              context.showSnackBar(
                message: failure.message ?? 'Failed to delete discussion',
                type: SnackBarType.error,
              );
            }
          },
          (_) {
            if (locator.isRegistered<CommunityHubBloc>()) {
              locator<CommunityHubBloc>().add(DeleteForumPostEvent(post.id));
            }
            if (context.mounted) {
              context.showSnackBar(message: 'Discussion deleted');
              unawaited(context.router.maybePop());
            }
          },
        );
      }
    }

    void shareThread() {
      unawaited(HapticFeedback.lightImpact());
      unawaited(
        locator<LinkSharingService>().shareForumPost(
          postId: post.id,
          title: currentPost.value.title,
          authorName: currentPost.value.authorName,
          subjectTrack: currentPost.value.track,
        ),
      );
    }

    Future<void> showEditPostSheet(BuildContext context) async {
      final titleEditController = TextEditingController(
        text: currentPost.value.title,
      );
      final contentEditController = TextEditingController(
        text: currentPost.value.content,
      );
      final isSubmittingEdit = ValueNotifier<bool>(false);

      await AppAdaptiveSheet.showModal<void>(
        context: context,
        builder: (sheetCtx) {
          final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(sheetCtx);
          return Container(
            decoration: isDesktop
                ? BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppRadius.dialog),
                    border: Border.all(
                      color: colors.surfaceBorder.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  )
                : null,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: isDesktop
                  ? 20
                  : (MediaQuery.of(sheetCtx).viewInsets.bottom + 16),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: isSubmittingEdit,
              builder: (ctx, isSaving, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Discussion',
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleEditController,
                      enabled: !isSaving,
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentEditController,
                      enabled: !isSaving,
                      maxLines: 5,
                      style: typography.body.regular.copyWith(
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Content',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newTitle = titleEditController.text.trim();
                              final newContent = contentEditController.text
                                  .trim();
                              if (newTitle.isEmpty || newContent.isEmpty) {
                                return;
                              }

                              const mod = ContentModerationService();
                              final modRes = mod.validatePost(
                                title: newTitle,
                                content: newContent,
                              );
                              if (!modRes.isValid) {
                                unawaited(
                                  ModerationFeedbackDialog.show(
                                    context,
                                    result: modRes,
                                    contentTarget: 'discussion',
                                  ),
                                );
                                return;
                              }

                              isSubmittingEdit.value = true;
                              final res = await repo.updateForumPost(
                                postId: currentPost.value.id,
                                title: newTitle,
                                content: newContent,
                              );
                              isSubmittingEdit.value = false;

                              res.fold(
                                (failure) {
                                  if (context.mounted) {
                                    context.showSnackBar(
                                      message:
                                          failure.message ??
                                          'Failed to update discussion',
                                      type: SnackBarType.error,
                                    );
                                  }
                                },
                                (updated) {
                                  currentPost.value = currentPost.value
                                      .copyWith(
                                        title: updated.title,
                                        content: updated.content,
                                      );
                                  if (context.mounted) {
                                    Navigator.of(sheetCtx).pop();
                                    context.showSnackBar(
                                      message: 'Discussion updated',
                                    );
                                  }
                                },
                              );
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    }

    Future<void> showEditReplySheet(
      BuildContext context,
      ForumReplyEntity reply,
    ) async {
      final editController = TextEditingController(text: reply.content);
      final isSubmitting = ValueNotifier<bool>(false);

      await AppAdaptiveSheet.showModal<void>(
        context: context,
        builder: (sheetCtx) {
          final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(sheetCtx);
          return Container(
            decoration: isDesktop
                ? BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppRadius.dialog),
                    border: Border.all(
                      color: colors.surfaceBorder.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  )
                : null,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: isDesktop
                  ? 20
                  : (MediaQuery.of(sheetCtx).viewInsets.bottom + 16),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: isSubmitting,
              builder: (ctx, isSaving, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Reply',
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editController,
                      enabled: !isSaving,
                      maxLines: 4,
                      style: typography.body.regular.copyWith(
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Reply',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newText = editController.text.trim();
                              if (newText.isEmpty) return;

                              const mod = ContentModerationService();
                              final modRes = mod.validateReply(
                                content: newText,
                              );
                              if (!modRes.isValid) {
                                unawaited(
                                  ModerationFeedbackDialog.show(
                                    context,
                                    result: modRes,
                                    contentTarget: 'reply',
                                  ),
                                );
                                return;
                              }

                              isSubmitting.value = true;
                              final res = await repo.updateForumReply(
                                replyId: reply.id,
                                content: newText,
                              );
                              isSubmitting.value = false;

                              res.fold(
                                (failure) {
                                  if (context.mounted) {
                                    context.showSnackBar(
                                      message:
                                          failure.message ??
                                          'Failed to update reply',
                                      type: SnackBarType.error,
                                    );
                                  }
                                },
                                (updated) {
                                  localReplies.value = localReplies.value
                                      .map<ForumReplyEntity>((r) {
                                        if (r.id == reply.id) {
                                          return r.copyWith(
                                            content: updated.content,
                                          );
                                        }
                                        return r;
                                      })
                                      .toList();
                                  if (context.mounted) {
                                    Navigator.of(sheetCtx).pop();
                                    context.showSnackBar(
                                      message: 'Reply updated',
                                    );
                                  }
                                },
                              );
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    }

    Future<void> confirmDeleteReply(
      BuildContext context,
      ForumReplyEntity reply,
    ) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: isDark
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Reply?',
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete this reply?',
            style: typography.body.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                'Cancel',
                style: typography.body.medium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        final res = await repo.deleteForumReply(
          postId: post.id,
          replyId: reply.id,
        );
        res.fold(
          (failure) {
            if (context.mounted) {
              context.showSnackBar(
                message: failure.message ?? 'Failed to delete reply',
                type: SnackBarType.error,
              );
            }
          },
          (_) {
            localReplies.value = localReplies.value
                .where((r) => r.id != reply.id)
                .toList();
            currentPost.value = currentPost.value.copyWith(
              repliesCount: math.max(0, currentPost.value.repliesCount - 1),
            );
            if (context.mounted) {
              context.showSnackBar(message: 'Reply deleted');
            }
          },
        );
      }
    }

    void showPostOptionsMenu() {
      unawaited(HapticFeedback.lightImpact());
      final userStorage = locator<UserStorageService>();
      final currentUserId = userStorage.getUserId();
      final currentUserName = userStorage.getUserDisplayName() ?? '';
      final isAuthor =
          (currentUserId != null &&
              currentUserId == currentPost.value.authorId) ||
          (currentUserName.isNotEmpty &&
              currentUserName.toLowerCase() ==
                  currentPost.value.authorName.toLowerCase());

      unawaited(
        AppAdaptiveSheet.showActionMenu<void>(
          context: context,
          maxWidth: 420,
          builder: (ctx) {
            final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
            return SafeArea(
              child: Container(
                decoration: isDesktop
                    ? BoxDecoration(
                        color: isDark
                            ? colors.surfaceSecondary
                            : colors.surfacePrimary,
                        borderRadius: BorderRadius.circular(AppRadius.dialog),
                        border: Border.all(
                          color: colors.surfaceBorder.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      )
                    : null,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isDesktop)
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withAlpha(60),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ListTile(
                      leading: Icon(
                        isBookmarked.value
                            ? Icons.bookmark_remove_outlined
                            : Icons.bookmark_add_outlined,
                        color: colors.textPrimary,
                      ),
                      title: Text(
                        isBookmarked.value
                            ? 'Remove from bookmarks'
                            : 'Save to bookmarks',
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        unawaited(toggleBookmark());
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        isSubscribed.value
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_active_outlined,
                        color: colors.textPrimary,
                      ),
                      title: Text(
                        isSubscribed.value
                            ? 'Mute thread notifications'
                            : 'Get thread notifications',
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        unawaited(toggleSubscription());
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.ios_share_rounded,
                        color: colors.textPrimary,
                      ),
                      title: Text(
                        'Share Thread',
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        shareThread();
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.groups_rounded,
                        color: colors.primary,
                      ),
                      title: Text(
                        'Launch Live Focus Room for Thread',
                        style: typography.body.medium.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        final room = StudyRoomEntity(
                          id: 'room-forum-${post.id}',
                          title: 'Focus Room: ${post.title}',
                          subject: post.track,
                          description:
                              'Live focus room created for thread: ${post.title}',
                          category: post.syllabusTag,
                        );
                        unawaited(
                          context.router.push(LiveStudyRoomRoute(room: room)),
                        );
                        context.showSnackBar(
                          message:
                              'Live Focus Room launched for this thread 🎧',
                          type: SnackBarType.success,
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.link_rounded,
                        color: colors.textPrimary,
                      ),
                      title: Text(
                        'Copy Link',
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final result = await locator<LinkSharingService>()
                            .shareForumPost(
                              postId: post.id,
                              title: currentPost.value.title,
                              authorName: currentPost.value.authorName,
                              subjectTrack: currentPost.value.track,
                            );
                        final copied = await locator<LinkSharingService>()
                            .copyLinkToClipboard(result.linkUri);
                        if (copied && context.mounted) {
                          context.showSnackBar(
                            message: 'Post link copied to clipboard',
                          );
                        }
                      },
                    ),
                    if (isAuthor) ...[
                      ListTile(
                        leading: Icon(
                          Icons.edit_outlined,
                          color: colors.textPrimary,
                        ),
                        title: Text(
                          'Edit Discussion',
                          style: typography.body.medium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          unawaited(showEditPostSheet(context));
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: colors.error,
                        ),
                        title: Text(
                          'Delete Discussion',
                          style: typography.body.medium.copyWith(
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          unawaited(confirmDeletePost(context));
                        },
                      ),
                    ] else
                      ListTile(
                        leading: Icon(
                          Icons.flag_outlined,
                          color: colors.error,
                        ),
                        title: Text(
                          'Report Thread',
                          style: typography.body.medium.copyWith(
                            color: colors.error,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          unawaited(
                            ReportContentModalSheet.show(
                              context,
                              contentType: 'forum_post',
                              contentId: post.id,
                              postId: post.id,
                              contentTitle: post.title,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // Quick text insertion helper for the composer
    void insertIntoComposer(String snippet) {
      final text = replyController.text;
      final selection = replyController.selection;
      if (selection.isValid && selection.start >= 0) {
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          snippet,
        );
        replyController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: selection.start + snippet.length,
          ),
        );
      } else {
        replyController
          ..text = '$text$snippet'
          ..selection = TextSelection.collapsed(
            offset: replyController.text.length,
          );
      }
      focusNode.requestFocus();
    }

    // Rich text formatting helper (Bold, Italic, Strikethrough, Code, Quote, etc.)
    void applyFormat(String prefix, String suffix, [String placeholder = '']) {
      final text = replyController.text;
      final selection = replyController.selection;
      var effectivePrefix = prefix;

      final start = selection.isValid && selection.start >= 0
          ? selection.start
          : text.length;

      if (effectivePrefix.startsWith('\n')) {
        if (start == 0 || (start > 0 && text[start - 1] == '\n')) {
          effectivePrefix = effectivePrefix.substring(1);
        }
      }

      if (selection.isValid &&
          selection.start >= 0 &&
          selection.end > selection.start) {
        final selectedText = text.substring(selection.start, selection.end);
        final replacement = '$effectivePrefix$selectedText$suffix';
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          replacement,
        );
        replyController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: selection.start + effectivePrefix.length,
            extentOffset:
                selection.start + effectivePrefix.length + selectedText.length,
          ),
        );
      } else {
        final insertIndex = start;
        final snippet = '$effectivePrefix$placeholder$suffix';
        final newText = text.replaceRange(insertIndex, insertIndex, snippet);
        final cursorOffset =
            insertIndex +
            effectivePrefix.length +
            (placeholder.isNotEmpty ? placeholder.length : 0);
        replyController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursorOffset),
        );
      }
      focusNode.requestFocus();
    }

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppAdaptiveAppBar(
        backgroundColor:
            (isDark ? colors.surfaceSecondary : colors.surfacePrimary)
                .withAlpha(230),
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Community',
            onTap: () {
              if (context.router.canPop()) {
                context.router.pop();
              }
            },
          ),
          AppBreadcrumbItem(
            label: post.title,
          ),
        ],
        title: Text(
          'Thread Detail',
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          // // Live Focus Room Button (Pulsing live audio quick join)
          // IconButton(
          //   icon: Icon(
          //     Icons.headphones_rounded,
          //     color: colors.primary,
          //     size: 21,
          //   ),
          //   tooltip: 'Live Focus Room for Thread',
          //   onPressed: () {
          //     unawaited(HapticFeedback.lightImpact());
          //     final room = StudyRoomEntity(
          //       id: 'room-forum-${post.id}',
          //       title: 'Focus Room: ${post.title}',
          //       subject: post.track,
          //       description:
          //           'Live focus room created for thread: ${post.title}',
          //       category: post.syllabusTag,
          //     );
          //     unawaited(context.router.push(LiveStudyRoomRoute(room: room)));
          //   },
          // ),

          // 1. Notification Toggle Button (Bell with real-time active status dot)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  isSubscribed.value
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: isSubscribed.value
                      ? colors.primary
                      : colors.textSecondary,
                  size: 22,
                ),
                tooltip: isSubscribed.value
                    ? 'Mute Notifications'
                    : 'Turn on Notifications',
                onPressed: () => unawaited(toggleSubscription()),
              ),
              if (isSubscribed.value)
                Positioned(
                  top: 11,
                  right: 12,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary,
                      border: Border.all(
                        color: isDark
                            ? colors.surfaceSecondary
                            : colors.surfacePrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // 2. Report / Flag Button
          IconButton(
            icon: Icon(
              Icons.flag_outlined,
              color: colors.textSecondary,
              size: 20,
            ),
            tooltip: l10n.tooltipReportThread,
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              unawaited(
                ReportContentModalSheet.show(
                  context,
                  contentType: 'forum_post',
                  contentId: post.id,
                  postId: post.id,
                  contentTitle: post.title,
                ),
              );
            },
          ),

          // 3. Share Button
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: colors.textSecondary,
              size: 20,
            ),
            tooltip: l10n.tooltipShareThread,
            onPressed: shareThread,
          ),

          // 4. Close Panel Button (when presented inside 3-panel layout)
          if (onClosePanel != null) ...[
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: colors.textSecondary,
                size: 20,
              ),
              tooltip: 'Close Forum Detail (Esc)',
              onPressed: onClosePanel,
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: RefreshIndicator(
                    color: colors.primary,
                    backgroundColor: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    onRefresh: () async {
                      await Future.wait<void>([
                        fetchTopLevelReplies(),
                        () async {
                          final subRes = await repo.isForumPostSubscribed(
                            post.id,
                          );
                          subRes.fold(
                            (_) {},
                            (sub) => isSubscribed.value = sub,
                          );
                          final bookRes = await repo
                              .getBookmarkedForumPostIds();
                          bookRes.fold(
                            (_) {},
                            (ids) => isBookmarked.value = ids.contains(post.id),
                          );
                        }(),
                      ]);
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      controller: scrollController,
                      slivers: [
                        // Breadcrumb Return Bar & Original Post Card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Original Post Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? colors.surfaceSecondary
                                        : colors.surfacePrimary,
                                    borderRadius: BorderRadius.circular(16),
                                    // Removed border
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.black.withAlpha(
                                          isDark ? 30 : 10,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Channel Pill & Meta Bar
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 3.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? colors.surfacePrimary
                                                        .withAlpha(
                                                          180,
                                                        )
                                                  : colors.primary.withAlpha(
                                                      isDark ? 50 : 25,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    10,
                                                  ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.widgets_outlined,
                                                  size: 12,
                                                  color: colors.primary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'c/${currentPost.value.track}',
                                                  style: typography.caption.bold
                                                      .copyWith(
                                                        color: colors.primary,
                                                        fontSize: 11,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 3.5,
                                            height: 3.5,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: colors.textSecondary
                                                  .withAlpha(
                                                    120,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Posted ${_formatTime(currentPost.value.createdAt, l10n)}',
                                            style: typography.caption.regular
                                                .copyWith(
                                                  color: colors.textSecondary,
                                                  fontSize: 11.5,
                                                ),
                                          ),
                                          const Spacer(),
                                          ShrinkableButton(
                                            onTap: showPostOptionsMenu,
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(
                                                Icons.more_horiz_rounded,
                                                size: 20,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Author Profile Row
                                      Row(
                                        children: [
                                          if (currentPost.value.isAnonymous)
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isDark
                                                    ? colors.surfaceSecondary
                                                    : colors.surfaceBorder
                                                          .withAlpha(40),
                                                border: Border.all(
                                                  color: colors.textSecondary
                                                      .withAlpha(
                                                        isDark ? 60 : 35,
                                                      ),
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.visibility_off_rounded,
                                                size: 20,
                                                color: colors.textSecondary,
                                              ),
                                            )
                                          else
                                            AppAvatar(
                                              customDimension: 40,
                                              name:
                                                  currentPost.value.authorName,
                                              backgroundColor: colors.primary
                                                  .withAlpha(isDark ? 50 : 35),
                                              foregroundColor: colors.primary,
                                              badgeColor: colors.success,
                                              badgeBorderColor: isDark
                                                  ? colors.surfaceSecondary
                                                  : colors.surfacePrimary,
                                            ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        currentPost
                                                                .value
                                                                .isAnonymous
                                                            ? currentPost
                                                                  .value
                                                                  .authorName
                                                            : '@${currentPost.value.authorName}',
                                                        style: typography
                                                            .subhead
                                                            .bold
                                                            .copyWith(
                                                              color:
                                                                  currentPost
                                                                      .value
                                                                      .isAnonymous
                                                                  ? colors
                                                                        .textSecondary
                                                                  : colors
                                                                        .textPrimary,
                                                              fontSize: 14.5,
                                                              fontStyle:
                                                                  currentPost
                                                                      .value
                                                                      .isAnonymous
                                                                  ? FontStyle
                                                                        .italic
                                                                  : FontStyle
                                                                        .normal,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    if (currentPost
                                                        .value
                                                        .isAnonymous)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 1.5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: colors
                                                              .textSecondary
                                                              .withAlpha(
                                                                isDark
                                                                    ? 40
                                                                    : 25,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          border: Border.all(
                                                            color: colors
                                                                .textSecondary
                                                                .withAlpha(
                                                                  isDark
                                                                      ? 70
                                                                      : 40,
                                                                ),
                                                            width: 0.8,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .shield_outlined,
                                                              size: 10,
                                                              color: colors
                                                                  .textSecondary,
                                                            ),
                                                            const SizedBox(
                                                              width: 3,
                                                            ),
                                                            Text(
                                                              'Incognito OP',
                                                              style: typography
                                                                  .caption
                                                                  .bold
                                                                  .copyWith(
                                                                    color: colors
                                                                        .textSecondary,
                                                                    fontSize:
                                                                        9.5,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    else ...[
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 5,
                                                              vertical: 1,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: colors.primary,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          'OP',
                                                          style: typography
                                                              .caption
                                                              .bold
                                                              .copyWith(
                                                                color: colors
                                                                    .white,
                                                                fontSize: 9.5,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      SubjectMasterBadge(
                                                        track: currentPost
                                                            .value
                                                            .track,
                                                        compact: true,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  currentPost.value.isAnonymous
                                                      ? 'Incognito Mode • Identities are protected'
                                                      : (currentPost
                                                                .value
                                                                .syllabusTag
                                                                .isNotEmpty
                                                            ? 'Staff Level Scholar • ${currentPost.value.syllabusTag}'
                                                            : 'Staff Level Scholar'),
                                                  style: typography
                                                      .caption
                                                      .regular
                                                      .copyWith(
                                                        color: colors
                                                            .textSecondary,
                                                        fontSize: 11.5,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      // Title
                                      Text(
                                        _cleanTitle(
                                          currentPost.value.title,
                                          currentPost.value.syllabusTag,
                                          currentPost.value.track,
                                        ),
                                        style: typography.title2.bold.copyWith(
                                          color: colors.textPrimary,
                                          fontSize: 18,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Structured Content Body Card
                                      _ForumThreadStructuredBody(
                                        post: currentPost.value,
                                      ),

                                      // LaTeX Formula block
                                      if (currentPost.value.latexContent !=
                                              null &&
                                          currentPost
                                              .value
                                              .latexContent!
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? colors.surfacePrimary
                                                : colors.surfaceSecondary
                                                      .withAlpha(
                                                        140,
                                                      ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: colors.primary.withAlpha(
                                                40,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.formulaEquation,
                                                style: typography.caption.bold
                                                    .copyWith(
                                                      color: colors.primary,
                                                      letterSpacing: 1.1,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              LatexFormulaBlock(
                                                formula: currentPost
                                                    .value
                                                    .latexContent!,
                                                backgroundColor:
                                                    Colors.transparent,
                                                borderColor: colors.primary
                                                    .withAlpha(
                                                      isDark ? 50 : 30,
                                                    ),
                                                textStyle: typography.body.bold
                                                    .copyWith(
                                                      color: colors.primary,
                                                      fontSize: 16,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      // Voice note player preview if present
                                      if (currentPost.value.voiceNoteUrl !=
                                              null &&
                                          currentPost.value.voiceNoteUrl!
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        VoiceNotePlayerWidget(
                                          audioUrl:
                                              currentPost.value.voiceNoteUrl!,
                                          postId: currentPost.value.id,
                                          durationSeconds: currentPost
                                              .value
                                              .voiceNoteDurationSeconds,
                                          transcript: currentPost
                                              .value
                                              .voiceNoteTranscript,
                                          onTranscriptLoaded: (newTranscript) {
                                            currentPost.value = currentPost
                                                .value
                                                .copyWith(
                                                  voiceNoteTranscript:
                                                      newTranscript,
                                                );
                                          },
                                        ),
                                      ],

                                      // Media Images preview if present
                                      if (currentPost
                                          .value
                                          .mediaUrls
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        ForumPostMediaPreview(
                                          mediaUrls:
                                              currentPost.value.mediaUrls,
                                          heroHeight: 165,
                                        ),
                                      ],

                                      // Semantic Tags Wrap
                                      if (currentPost
                                          .value
                                          .tags
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: currentPost.value.tags.map((
                                            tag,
                                          ) {
                                            final displayTag =
                                                tag.startsWith('#')
                                                ? tag
                                                : '#$tag';
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? colors.surfacePrimary
                                                          .withAlpha(
                                                            160,
                                                          )
                                                    : colors.primary.withAlpha(
                                                        isDark ? 40 : 20,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                              ),
                                              child: Text(
                                                displayTag,
                                                style: typography.caption.bold
                                                    .copyWith(
                                                      color: colors.primary,
                                                      fontSize: 11,
                                                    ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],

                                      const SizedBox(height: 16),

                                      // OP Interactive Action Bar (Vote Group Pill, Replies Count, Bookmark, Share)
                                      Row(
                                        children: [
                                          // Vote Group Pill
                                          _ForumPostVotePill(
                                            netVotes:
                                                currentPost.value.netVotes,
                                            userVote:
                                                currentPost.value.userVote,
                                            onUpvote: () => votePost(1),
                                            onDownvote: () => votePost(-1),
                                          ),
                                          const SizedBox(width: 8),

                                          // Replies Count Indicator
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? colors.surfacePrimary
                                                        .withAlpha(
                                                          160,
                                                        )
                                                  : colors.surfaceSecondary
                                                        .withAlpha(
                                                          120,
                                                        ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    16,
                                                  ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .chat_bubble_outline_rounded,
                                                  size: 15,
                                                  color: colors.textSecondary,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '${localReplies.value.length}',
                                                  style: typography.caption.bold
                                                      .copyWith(
                                                        color: colors
                                                            .textSecondary,
                                                        fontSize: 12,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),

                                          // Bookmark Button
                                          ShrinkableButton(
                                            onTap: () =>
                                                unawaited(toggleBookmark()),
                                            child: Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isBookmarked.value
                                                    ? colors.primary.withAlpha(
                                                        isDark ? 35 : 20,
                                                      )
                                                    : colors.transparent,
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                isBookmarked.value
                                                    ? Icons.bookmark_rounded
                                                    : Icons
                                                          .bookmark_border_rounded,
                                                size: 19,
                                                color: isBookmarked.value
                                                    ? colors.primary
                                                    : colors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),

                                          // Generate Deck Button
                                          ShrinkableButton(
                                            onTap: () => unawaited(
                                              ForumGenerateDeckSheet.show(
                                                context,
                                                post: currentPost.value,
                                                replies: localReplies.value,
                                              ),
                                            ),
                                            child: Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: colors.primary
                                                    .withValues(alpha: 0.1),
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.auto_awesome_rounded,
                                                size: 17,
                                                color: colors.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),

                                          // Share Button
                                          ShrinkableButton(
                                            onTap: shareThread,
                                            child: Container(
                                              width: 34,
                                              height: 34,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.share_outlined,
                                                size: 19,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Discussion River Section Header (Replies + Count + Sort Filter Pill)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                            child: Row(
                              children: [
                                Text(
                                  'Replies',
                                  style: typography.title3.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? colors.surfaceSecondary
                                        : colors.surfaceTertiary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${localReplies.value.length}',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),

                                PopupMenuButton<ForumSortFilter>(
                                  initialValue: sortFilter.value,
                                  tooltip: l10n.tooltipSortReplies,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: colors.surfaceBorder.withAlpha(
                                        isDark ? 60 : 30,
                                      ),
                                    ),
                                  ),
                                  color: isDark
                                      ? colors.surfaceSecondary
                                      : colors.surfacePrimary,
                                  onSelected: (filter) {
                                    unawaited(HapticFeedback.selectionClick());
                                    sortFilter.value = filter;
                                  },
                                  itemBuilder: (context) =>
                                      ForumSortFilter.values.map((f) {
                                        final isSelected =
                                            f == sortFilter.value;
                                        return PopupMenuItem<ForumSortFilter>(
                                          value: f,
                                          child: Row(
                                            children: [
                                              Icon(
                                                f.icon,
                                                size: 16,
                                                color: isSelected
                                                    ? colors.primary
                                                    : colors.textSecondary,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                f.label,
                                                style: typography
                                                    .footnote
                                                    .medium
                                                    .copyWith(
                                                      color: isSelected
                                                          ? colors.primary
                                                          : colors.textPrimary,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? colors.surfaceSecondary.withAlpha(
                                              160,
                                            )
                                          : colors.surfaceSecondary.withAlpha(
                                              110,
                                            ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          sortFilter.value.icon,
                                          size: 14,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          sortFilter.value.label,
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: colors.textPrimary,
                                                fontSize: 11.5,
                                              ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.expand_more_rounded,
                                          size: 15,
                                          color: colors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Replies List
                        Builder(
                          builder: (context) {
                            final allReplies = localReplies.value;

                            // Filter & sort top-level replies
                            final topLevelReplies =
                                (allReplies
                                      .where(
                                        (r) =>
                                            r.parentReplyId == null ||
                                            r.parentReplyId!.isEmpty,
                                      )
                                      .toList())
                                  ..sort((a, b) {
                                    if (a.isVerifiedSolution !=
                                        b.isVerifiedSolution) {
                                      return a.isVerifiedSolution ? -1 : 1;
                                    }

                                    switch (sortFilter.value) {
                                      case ForumSortFilter.mostRecent:
                                        return b.createdAt.compareTo(
                                          a.createdAt,
                                        );
                                      case ForumSortFilter.topVoted:
                                        final voteComp = b.netVotes.compareTo(
                                          a.netVotes,
                                        );
                                        if (voteComp != 0) return voteComp;
                                        return b.createdAt.compareTo(
                                          a.createdAt,
                                        );
                                      case ForumSortFilter.aiFirst:
                                        final aIsAi =
                                            a.authorName.toLowerCase().contains(
                                              'syllabot',
                                            ) ||
                                            a.content.contains('🤖');
                                        final bIsAi =
                                            b.authorName.toLowerCase().contains(
                                              'syllabot',
                                            ) ||
                                            b.content.contains('🤖');
                                        if (aIsAi != bIsAi) {
                                          return aIsAi ? -1 : 1;
                                        }
                                        return b.netVotes.compareTo(a.netVotes);
                                      case ForumSortFilter.unanswered:
                                        final aHasChildren = allReplies.any(
                                          (r) => r.parentReplyId == a.id,
                                        );
                                        final bHasChildren = allReplies.any(
                                          (r) => r.parentReplyId == b.id,
                                        );
                                        if (aHasChildren != bHasChildren) {
                                          return aHasChildren ? 1 : -1;
                                        }
                                        return b.createdAt.compareTo(
                                          a.createdAt,
                                        );
                                    }
                                  });

                            // Group nested replies recursively by root top-level parent ID
                            final replyById = {
                              for (final r in allReplies) r.id: r,
                            };
                            String getRootParentId(ForumReplyEntity r) {
                              var current = r;
                              final visited = <String>{current.id};
                              while (current.parentReplyId != null &&
                                  current.parentReplyId!.isNotEmpty &&
                                  replyById.containsKey(
                                    current.parentReplyId,
                                  )) {
                                final parent =
                                    replyById[current.parentReplyId!]!;
                                if (visited.contains(parent.id)) break;
                                visited.add(parent.id);
                                current = parent;
                              }
                              return current.id;
                            }

                            final nestedRepliesMap =
                                <String, List<ForumReplyEntity>>{};
                            for (final reply in allReplies) {
                              if (reply.parentReplyId != null &&
                                  reply.parentReplyId!.isNotEmpty) {
                                final rootId = getRootParentId(reply);
                                nestedRepliesMap
                                    .putIfAbsent(rootId, () => [])
                                    .add(reply);
                              }
                            }
                            for (final list in nestedRepliesMap.values) {
                              list.sort(
                                (a, b) => a.createdAt.compareTo(b.createdAt),
                              );
                            }

                            final hasAiHintInEmpty = allReplies.any(
                              (r) =>
                                  r.authorName.toLowerCase().contains(
                                    'syllabot',
                                  ) ||
                                  r.content.contains('Syllabot') ||
                                  r.content.contains('🤖') ||
                                  r.content.contains('Socratic Hint'),
                            );

                            if (isInitialLoadingReplies.value &&
                                topLevelReplies.isEmpty) {
                              return SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 36,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  colors.primary,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Loading replies...',
                                          style: typography.caption.medium
                                              .copyWith(
                                                color: colors.textSecondary,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            if (topLevelReplies.isEmpty) {
                              return SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 36,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: colors.primary.withAlpha(
                                            isDark ? 25 : 15,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 36,
                                          color: colors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        l10n.noRepliesYet,
                                        style: typography.subhead.bold.copyWith(
                                          color: colors.textPrimary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Be the first to share an answer or solution.',
                                        style: typography.caption.regular
                                            .copyWith(
                                              color: colors.textSecondary,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (!hasAiHintInEmpty) ...[
                                        const SizedBox(height: 18),
                                        ShrinkableButton(
                                          onTap: isGeneratingAiHint.value
                                              ? null
                                              : generateSyllabotHint,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 11,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.syllabotAccent,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    12,
                                                  ),
                                            ),
                                            child: AnimatedSwitcher(
                                              duration: AppMotion.snappy,
                                              switchInCurve:
                                                  AppMotion.easeOutCubic,
                                              child: Row(
                                                key: ValueKey(
                                                  isGeneratingAiHint.value,
                                                ),
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isGeneratingAiHint.value)
                                                    SizedBox(
                                                      width: 15,
                                                      height: 15,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(colors.white),
                                                      ),
                                                    )
                                                  else
                                                    Icon(
                                                      Icons
                                                          .auto_awesome_rounded,
                                                      size: 16,
                                                      color: colors.white,
                                                    ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    isGeneratingAiHint.value
                                                        ? 'Consulting Syllabot...'
                                                        : 'Ask Syllabot for Socratic Hint 🤖',
                                                    style: typography
                                                        .caption
                                                        .bold
                                                        .copyWith(
                                                          color: colors.white,
                                                          letterSpacing: 0.2,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }

                            return SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final reply = topLevelReplies[index];
                                  final children =
                                      nestedRepliesMap[reply.id] ?? const [];
                                  final hasVerifiedSolution = allReplies.any(
                                    (r) => r.isVerifiedSolution,
                                  );
                                  final userStorage =
                                      locator<UserStorageService>();
                                  final currentUserId = userStorage.getUserId();
                                  final isAuthor =
                                      currentUserId == null ||
                                      currentUserId ==
                                          currentPost.value.authorId;

                                  return Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          12,
                                        ),
                                        child: _DiscussionThreadGroupCard(
                                          parentReply: reply,
                                          children: children,
                                          highlightReplyId: highlightReplyId,
                                          opAuthorName:
                                              currentPost.value.authorName,
                                          isQuestion:
                                              currentPost.value.isQuestion,
                                          isAuthor: isAuthor,
                                          hasVerifiedSolution:
                                              hasVerifiedSolution,
                                          isExpanded: expandedParentReplyIds
                                              .value
                                              .contains(reply.id),
                                          isLoadingChildren:
                                              loadingParentReplyIds.value
                                                  .contains(reply.id),
                                          hasMoreChildren:
                                              hasMoreSubRepliesMap.value[reply
                                                  .id] ??
                                              false,
                                          onToggleExpand: () =>
                                              toggleSubRepliesExpansion(
                                                reply.id,
                                              ),
                                          onLoadMoreChildren: () =>
                                              loadSubRepliesForParent(
                                                reply.id,
                                                isLoadMore: true,
                                              ),
                                          onVote: (direction) =>
                                              voteReply(reply, direction),
                                          onChildVote: voteReply,
                                          onReplyTap: () {
                                            replyingToReply.value = reply;
                                            focusNode.requestFocus();
                                          },
                                          onChildReplyTap: (target) {
                                            replyingToReply.value = target;
                                            focusNode.requestFocus();
                                          },
                                          onSaveFlashcard: (target) =>
                                              unawaited(
                                                saveSolutionToFlashcard(target),
                                              ),
                                          onEditReply: () => unawaited(
                                            showEditReplySheet(context, reply),
                                          ),
                                          onDeleteReply: () => unawaited(
                                            confirmDeleteReply(context, reply),
                                          ),
                                          onEditChildReply: (child) =>
                                              unawaited(
                                                showEditReplySheet(
                                                  context,
                                                  child,
                                                ),
                                              ),
                                          onDeleteChildReply: (child) =>
                                              unawaited(
                                                confirmDeleteReply(
                                                  context,
                                                  child,
                                                ),
                                              ),
                                          onTranscriptUpdated:
                                              (targetReplyId, newTranscript) {
                                                localReplies.value =
                                                    localReplies.value.map((r) {
                                                      if (r.id ==
                                                          targetReplyId) {
                                                        return r.copyWith(
                                                          voiceNoteTranscript:
                                                              newTranscript,
                                                        );
                                                      }
                                                      return r;
                                                    }).toList();
                                              },
                                          onVerifySolution: () async {
                                            final res = await repo
                                                .verifyForumReply(
                                                  postId: currentPost.value.id,
                                                  replyId: reply.id,
                                                );
                                            res.fold(
                                              (failure) {
                                                if (context.mounted) {
                                                  context.showSnackBar(
                                                    message:
                                                        failure.message ??
                                                        'Failed to verify solution',
                                                    type: SnackBarType.error,
                                                  );
                                                }
                                              },
                                              (_) {
                                                unawaited(
                                                  HapticFeedback.heavyImpact(),
                                                );
                                                currentPost.value = currentPost
                                                    .value
                                                    .copyWith(
                                                      isVerifiedSolution: true,
                                                    );
                                                if (locator
                                                    .isRegistered<
                                                      CommunityHubBloc
                                                    >()) {
                                                  locator<CommunityHubBloc>()
                                                      .add(
                                                        VerifyForumReplyEvent(
                                                          postId: currentPost
                                                              .value
                                                              .id,
                                                          replyId: reply.id,
                                                        ),
                                                      );
                                                }
                                                localReplies
                                                    .value = localReplies.value
                                                    .map(
                                                      (r) => r.id == reply.id
                                                          ? r.copyWith(
                                                              isVerifiedSolution:
                                                                  true,
                                                            )
                                                          : r,
                                                    )
                                                    .toList();
                                                if (context.mounted) {
                                                  context.showSnackBar(
                                                    message:
                                                        'Marked as verified solution! ${currentPost.value.karmaBounty > 0 ? currentPost.value.karmaBounty : 100} XP Karma bounty awarded to ${reply.authorName}! 🏆',
                                                    type: SnackBarType.success,
                                                  );
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      )
                                      .animate(
                                        delay: (index.clamp(0, 5) * 80).ms,
                                      )
                                      .fadeIn(
                                        duration: 300.ms,
                                        curve: Curves.easeOutCubic,
                                      )
                                      .slideY(
                                        begin: 0.05,
                                        end: 0,
                                        duration: 300.ms,
                                        curve: Curves.easeOutCubic,
                                      );
                                },
                                childCount: topLevelReplies.length,
                              ),
                            );
                          },
                        ),

                        // Top-Level Pagination trigger
                        if (hasMoreTopLevel.value) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              child: Center(
                                child: ShrinkableButton(
                                  onTap: isLoadingMoreTopLevel.value
                                      ? null
                                      : () => fetchTopLevelReplies(
                                          isLoadMore: true,
                                        ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? colors.surfaceSecondary
                                          : colors.surfacePrimary,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? colors.surfaceBorder.withAlpha(40)
                                            : colors.surfaceBorder,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.black.withAlpha(
                                            isDark ? 20 : 6,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isLoadingMoreTopLevel.value) ...[
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    colors.primary,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Loading more discussions...',
                                            style: typography.footnote.bold
                                                .copyWith(
                                                  color: colors.primary,
                                                ),
                                          ),
                                        ] else ...[
                                          Icon(
                                            Icons.expand_circle_down_outlined,
                                            size: 16,
                                            color: colors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Load more discussions',
                                            style: typography.footnote.bold
                                                .copyWith(
                                                  color: colors.primary,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Sticky Bottom Quick Reply Bar (Transparent container, compact styling tools, mic button)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.transparent,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Active Target Context Banner (Replying to @username)
                        if (replyingToReply.value != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfaceSecondary
                                  : colors.surfacePrimary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.primary.withAlpha(50),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.subdirectory_arrow_right_rounded,
                                  size: 15,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Replying to @${replyingToReply.value!.authorName}',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ShrinkableButton(
                                  onTap: () => replyingToReply.value = null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Quick Formatting Tools Strip (Compact: only shows when toggled on)
                        AnimatedCrossFade(
                          crossFadeState: showFormattingTools.value
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 200),
                          secondChild: const SizedBox.shrink(),
                          firstChild: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  // 1. Math / Formula Tool Chip (Σ √x Math)
                                  _QuickToolChip(
                                    label: 'Math',
                                    prefix: 'Σ √x',
                                    isHighlighted: true,
                                    onTap: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      _showLatexSnippetDialog(
                                        context,
                                        insertIntoComposer,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6),

                                  // 2. Syllabot AI Hint Tool Chip (✨ AI Hint)
                                  _QuickToolChip(
                                    label: 'AI Hint',
                                    icon: Icons.auto_awesome_rounded,
                                    isHighlighted: true,
                                    onTap: isGeneratingAiHint.value
                                        ? null
                                        : generateSyllabotHint,
                                  ),
                                  const SizedBox(width: 6),

                                  // 3. Code Chip (</> Code)
                                  _QuickToolChip(
                                    label: 'Code',
                                    prefix: '</>',
                                    isHighlighted: true,
                                    onTap: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      applyFormat('`', '`', 'code');
                                    },
                                  ),
                                  const SizedBox(width: 6),

                                  // 4. Symbols Tool Chip (π / θ Symbols)
                                  _QuickToolChip(
                                    label: 'Symbols',
                                    prefix: 'π / θ',
                                    isHighlighted: true,
                                    onTap: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      _showMathSymbolDialog(
                                        context,
                                        insertIntoComposer,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6),

                                  // 5. Bold Formatting Chip
                                  _QuickToolChip(
                                    label: 'Bold',
                                    prefix: 'B',
                                    isCodeStyle: true,
                                    onTap: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      applyFormat('**', '**', 'bold text');
                                    },
                                  ),
                                  const SizedBox(width: 6),

                                  // 6. Italic Formatting Chip
                                  _QuickToolChip(
                                    label: 'Italic',
                                    prefix: 'I',
                                    isCodeStyle: true,
                                    onTap: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      applyFormat('*', '*', 'italic text');
                                    },
                                  ),
                                  const SizedBox(width: 6),

                                  // 7. Strikethrough Chip
                                  _QuickToolChip(
                                    label: 'Strike',
                                    prefix: '~S~',
                                    isCodeStyle: true,
                                    onTap: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      applyFormat('~~', '~~', 'strikethrough');
                                    },
                                  ),
                                  const SizedBox(width: 6),

                                  // 8. Quote Tool Chip
                                  _QuickToolChip(
                                    label: 'Quote',
                                    prefix: '”',
                                    isCodeStyle: true,
                                    onTap: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      applyFormat('\n> ', '\n', 'quoted text');
                                    },
                                  ),
                                  const SizedBox(width: 6),

                                  // 9. Bullet List Chip
                                  _QuickToolChip(
                                    label: 'List',
                                    prefix: '•',
                                    isCodeStyle: true,
                                    onTap: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      insertIntoComposer('\n- ');
                                    },
                                  ),
                                  const SizedBox(width: 6),

                                  // 10. Code Block Tool Chip
                                  _QuickToolChip(
                                    label: 'Block',
                                    prefix: '</>',
                                    isCodeStyle: true,
                                    onTap: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      insertIntoComposer(
                                        '\n```\n// Code or equation here\n```\n',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Recording indicator banner
                        if (isRecordingReplyVoice.value) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: VoiceRecordingBannerWidget(
                              isLocked: isReplyVoiceLocked.value,
                              durationSeconds: replyVoiceNoteDuration.value,
                              transcriptText: replyVoiceTranscript.value,
                              amplitudeStream:
                                  locator.isRegistered<AudioRecordingService>()
                                  ? locator<AudioRecordingService>()
                                        .amplitudeStream
                                  : null,
                              onCancel: () {
                                unawaited(replyRecorderController.cancel());
                              },
                              onDone: () {
                                unawaited(replyRecorderController.finish());
                              },
                            ),
                          ),
                        ],

                        // Reply Voice Note Preview if attached
                        if (replyVoiceNoteUrl.value != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: VoiceNotePlayerWidget(
                              audioUrl: replyVoiceNoteUrl.value!,
                              durationSeconds: replyVoiceNoteDuration.value > 0
                                  ? replyVoiceNoteDuration.value
                                  : null,
                              transcript:
                                  replyVoiceTranscript.value.trim().isNotEmpty
                                  ? replyVoiceTranscript.value.trim()
                                  : (replyController.text.trim().isNotEmpty
                                        ? replyController.text.trim()
                                        : null),
                              compact: true,
                              showTranscript: false,
                              onDelete: () {
                                replyVoiceNoteUrl.value = null;
                                replyVoiceNoteDuration.value = 0;
                                replyVoiceTranscript.value = '';
                              },
                            ),
                          ),
                        ],

                        // Reply Image Thumbnails Preview if attached
                        if (replyImages.value.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: SizedBox(
                              height: 52,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: replyImages.value.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (ctx, idx) {
                                  final path = replyImages.value[idx];
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(path),
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          onTap: () {
                                            replyImages.value = replyImages
                                                .value
                                                .where((p) => p != path)
                                                .toList();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: colors.black.withAlpha(
                                                160,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 10,
                                              color: colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],

                        // Input Row & Send Button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 12, 10),
                          child: Row(
                            children: [
                              // 1. Attach Button -> opens image attachment directly
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 34,
                                  minHeight: 34,
                                ),
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.attach_file_rounded,
                                  size: 20,
                                  color: replyImages.value.isNotEmpty
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                                tooltip: l10n.tooltipAttachImage,
                                onPressed: () async {
                                  unawaited(HapticFeedback.lightImpact());
                                  try {
                                    final photo = await ImagePicker().pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 1920,
                                      maxHeight: 1920,
                                      imageQuality: 85,
                                    );
                                    if (photo != null &&
                                        photo.path.isNotEmpty) {
                                      replyImages.value = [
                                        ...replyImages.value,
                                        photo.path,
                                      ];
                                    }
                                  } on Object catch (_) {}
                                },
                              ),

                              // 2. Voice Note Recorder (Hold to record, drag up to lock, STT accompanied)
                              VoiceNoteRecorderWidget(
                                compact: true,
                                controller: replyController,
                                recorderController: replyRecorderController,
                                onRecordingStateChanged:
                                    ({
                                      required isRecording,
                                      required isLocked,
                                      required durationSeconds,
                                      required transcript,
                                    }) {
                                      isRecordingReplyVoice.value = isRecording;
                                      isReplyVoiceLocked.value = isLocked;
                                      replyVoiceNoteDuration.value =
                                          durationSeconds;
                                      replyVoiceTranscript.value = transcript;
                                    },
                                onRecordingComplete:
                                    ({
                                      required audioUrl,
                                      required durationSeconds,
                                      required transcript,
                                    }) {
                                      replyVoiceNoteUrl.value = audioUrl;
                                      replyVoiceNoteDuration.value =
                                          durationSeconds;
                                      if (transcript.trim().isNotEmpty) {
                                        replyVoiceTranscript.value = transcript
                                            .trim();
                                      }
                                    },
                                onCancel: () {
                                  replyVoiceNoteUrl.value = null;
                                  replyVoiceNoteDuration.value = 0;
                                  replyVoiceTranscript.value = '';
                                },
                              ),

                              // 3. Compact Styling Tools Toggle Button
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 34,
                                  minHeight: 34,
                                ),
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  showFormattingTools.value
                                      ? Icons.text_format_rounded
                                      : Icons.text_fields_rounded,
                                  size: 19,
                                  color: showFormattingTools.value
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                                tooltip: showFormattingTools.value
                                    ? 'Hide tools'
                                    : 'Writing & Math Tools',
                                onPressed: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  showFormattingTools.value =
                                      !showFormattingTools.value;
                                },
                              ),
                              const SizedBox(width: 2),

                              // 3b. Anonymous Reply Mode Toggle
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 34,
                                  minHeight: 34,
                                ),
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  isAnonymousReply.value
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 19,
                                  color: isAnonymousReply.value
                                      ? colors.warning
                                      : colors.textSecondary,
                                ),
                                tooltip: isAnonymousReply.value
                                    ? 'Replying Anonymously (Tap to switch)'
                                    : 'Reply Anonymously',
                                onPressed: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  isAnonymousReply.value =
                                      !isAnonymousReply.value;
                                },
                              ),
                              const SizedBox(width: 4),

                              // 4. Text Field
                              Expanded(
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: isRecordingReplyVoice.value
                                        ? [
                                            BoxShadow(
                                              color: colors.error.withAlpha(
                                                isDark ? 80 : 50,
                                              ),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: TextField(
                                    controller: replyController,
                                    focusNode: focusNode,
                                    maxLines: 4,
                                    minLines: 1,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      hintText: isRecordingReplyVoice.value
                                          ? 'Transcribing speech live…'
                                          : isAnonymousReply.value
                                          ? (replyingToReply.value != null
                                                ? 'Reply anonymously to @${replyingToReply.value!.authorName}…'
                                                : 'Reply anonymously as Anonymous Scholar…')
                                          : replyingToReply.value != null
                                          ? 'Reply to @${replyingToReply.value!.authorName}…'
                                          : 'Add a reply…',
                                      hintStyle: typography.body.regular
                                          .copyWith(
                                            color: isRecordingReplyVoice.value
                                                ? colors.error.withAlpha(180)
                                                : colors.textSecondary,
                                            fontSize: 14,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      filled: true,
                                      fillColor: isRecordingReplyVoice.value
                                          ? colors.error.withAlpha(
                                              isDark ? 30 : 16,
                                            )
                                          : isDark
                                          ? colors.surfaceSecondary.withAlpha(
                                              160,
                                            )
                                          : colors.surfaceSecondary.withAlpha(
                                              130,
                                            ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(22),
                                        borderSide: BorderSide(
                                          color: isRecordingReplyVoice.value
                                              ? colors.error.withAlpha(180)
                                              : colors.surfaceBorder.withAlpha(
                                                  isDark ? 60 : 35,
                                                ),
                                          width: isRecordingReplyVoice.value
                                              ? 1.5
                                              : 1,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(22),
                                        borderSide: BorderSide(
                                          color: isRecordingReplyVoice.value
                                              ? colors.error.withAlpha(180)
                                              : colors.surfaceBorder.withAlpha(
                                                  isDark ? 60 : 35,
                                                ),
                                          width: isRecordingReplyVoice.value
                                              ? 1.5
                                              : 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(22),
                                        borderSide: BorderSide(
                                          color: isRecordingReplyVoice.value
                                              ? colors.error
                                              : colors.primary.withAlpha(160),
                                          width: 1.8,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 5. Send Button
                              PlatformHoverBuilder(
                                builder: (context, isHovered, child) {
                                  return AnimatedScale(
                                    scale: isHovered ? 1.06 : 1,
                                    duration: AppMotion.snappy,
                                    curve: AppMotion.easeOutCubic,
                                    child: child,
                                  );
                                },
                                child: ShrinkableButton(
                                  onTap: isSubmitting.value
                                      ? null
                                      : () async {
                                          final text = replyController.text
                                              .trim();
                                          if (text.isEmpty &&
                                              replyImages.value.isEmpty &&
                                              replyVoiceNoteUrl.value == null) {
                                            return;
                                          }

                                          // Content safety & anti-abuse moderation check for replies
                                          if (text.isNotEmpty) {
                                            const moderation =
                                                ContentModerationService();
                                            final modResult = moderation
                                                .validateReply(content: text);
                                            if (!modResult.isValid) {
                                              unawaited(
                                                ModerationFeedbackDialog.show(
                                                  context,
                                                  result: modResult,
                                                  contentTarget: 'reply',
                                                ),
                                              );
                                              return;
                                            }
                                          }

                                          final sanitizedText =
                                              ContentModerationService.sanitizeText(
                                                text,
                                              );

                                          final targetParentId =
                                              replyingToReply.value?.id;
                                          isSubmitting.value = true;

                                          var finalReplyImages = <String>[];
                                          if (replyImages.value.isNotEmpty &&
                                              locator
                                                  .isRegistered<
                                                    MediaUploadService
                                                  >()) {
                                            final uploadService =
                                                locator<MediaUploadService>();
                                            for (final imgPath
                                                in replyImages.value) {
                                              if (imgPath.startsWith(
                                                    'http://',
                                                  ) ||
                                                  imgPath.startsWith(
                                                    'https://',
                                                  )) {
                                                finalReplyImages.add(imgPath);
                                              } else if (File(
                                                imgPath,
                                              ).existsSync()) {
                                                try {
                                                  final r2Url =
                                                      await uploadService
                                                          .uploadMedia(
                                                            file: File(imgPath),
                                                            mediaType:
                                                                ForumMediaType
                                                                    .image,
                                                          );
                                                  finalReplyImages.add(r2Url);
                                                } on Object catch (_) {
                                                  finalReplyImages.add(imgPath);
                                                }
                                              }
                                            }
                                          } else {
                                            finalReplyImages =
                                                replyImages.value;
                                          }

                                          var finalReplyVoiceNoteUrl =
                                              replyVoiceNoteUrl.value;
                                          if (finalReplyVoiceNoteUrl != null &&
                                              !finalReplyVoiceNoteUrl
                                                  .startsWith('http://') &&
                                              !finalReplyVoiceNoteUrl
                                                  .startsWith('https://') &&
                                              locator
                                                  .isRegistered<
                                                    MediaUploadService
                                                  >()) {
                                            final uploadService =
                                                locator<MediaUploadService>();
                                            if (File(
                                              finalReplyVoiceNoteUrl,
                                            ).existsSync()) {
                                              try {
                                                final r2Url = await uploadService
                                                    .uploadMedia(
                                                      file: File(
                                                        finalReplyVoiceNoteUrl,
                                                      ),
                                                      mediaType:
                                                          ForumMediaType.voice,
                                                    );
                                                finalReplyVoiceNoteUrl = r2Url;
                                              } on Object catch (_) {}
                                            }
                                          }

                                          final res = await repo
                                              .replyToForumPost(
                                                postId: currentPost.value.id,
                                                content:
                                                    sanitizedText.isNotEmpty
                                                    ? sanitizedText
                                                    : 'Shared media attachment',
                                                parentReplyId: targetParentId,
                                                mediaUrls: finalReplyImages,
                                                voiceNoteUrl:
                                                    finalReplyVoiceNoteUrl,
                                                voiceNoteDurationSeconds:
                                                    replyVoiceNoteDuration
                                                            .value >
                                                        0
                                                    ? replyVoiceNoteDuration
                                                          .value
                                                    : null,
                                                voiceNoteTranscript:
                                                    replyVoiceTranscript.value
                                                        .trim()
                                                        .isNotEmpty
                                                    ? replyVoiceTranscript.value
                                                          .trim()
                                                    : null,
                                                isAnonymous:
                                                    isAnonymousReply.value,
                                              );
                                          isSubmitting.value = false;
                                          res.fold(
                                            (failure) {
                                              if (context.mounted) {
                                                context.showSnackBar(
                                                  message:
                                                      failure.message ??
                                                      failure.toString(),
                                                  type: SnackBarType.error,
                                                );
                                              }
                                            },
                                            (createdReply) {
                                              replyController.clear();
                                              replyImages.value = [];
                                              replyVoiceNoteUrl.value = null;
                                              replyVoiceNoteDuration.value = 0;
                                              replyingToReply.value = null;
                                              isAnonymousReply.value = false;
                                              if (!localReplies.value.any(
                                                (r) => r.id == createdReply.id,
                                              )) {
                                                localReplies.value = [
                                                  ...localReplies.value,
                                                  createdReply,
                                                ];
                                              }

                                              // Fire-and-forget server-side Groq transcription via Supabase Edge Function.
                                              // The edge function calls Groq Whisper on the R2 audio URL and patches
                                              // voice_note_transcript in the DB — transcripts are viewer-only, never
                                              // shown to the person who recorded the voice note.
                                              final vnUrl =
                                                  createdReply.voiceNoteUrl;
                                              if (vnUrl != null &&
                                                  vnUrl.trim().isNotEmpty &&
                                                  locator
                                                      .isRegistered<
                                                        MediaUploadService
                                                      >()) {
                                                unawaited(
                                                  locator<MediaUploadService>()
                                                      .triggerVoiceNoteTranscription(
                                                        audioUrl: vnUrl,
                                                        replyId:
                                                            createdReply.id,
                                                      ),
                                                );
                                              }
                                              if (targetParentId != null) {
                                                localReplies.value =
                                                    localReplies.value.map((r) {
                                                      if (r.id ==
                                                          targetParentId) {
                                                        return r.copyWith(
                                                          repliesCount:
                                                              r.repliesCount +
                                                              1,
                                                        );
                                                      }
                                                      return r;
                                                    }).toList();
                                                expandedParentReplyIds.value = {
                                                  ...expandedParentReplyIds
                                                      .value,
                                                  targetParentId,
                                                };
                                              }
                                              if (locator
                                                  .isRegistered<
                                                    CommunityHubBloc
                                                  >()) {
                                                locator<CommunityHubBloc>().add(
                                                  ForumPostRepliesIncrementedEvent(
                                                    postId:
                                                        currentPost.value.id,
                                                    reply: createdReply,
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        },
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors.primary,
                                    ),
                                    alignment: Alignment.center,
                                    child: AnimatedSwitcher(
                                      duration: AppMotion.snappy,
                                      switchInCurve: AppMotion.easeOutCubic,
                                      child: isSubmitting.value
                                          ? AppLogoLoader(
                                              key: const ValueKey(
                                                'submitting_loader',
                                              ),
                                              size: 16,
                                              color: colors.white,
                                              showMessage: false,
                                            )
                                          : Icon(
                                              Icons.send_rounded,
                                              key: const ValueKey(
                                                'send_icon',
                                              ),
                                              color: colors.white,
                                              size: 18,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  void _showLatexSnippetDialog(
    BuildContext context,
    void Function(String snippet) onInsert,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final snippets = [
      {'label': 'Fraction', 'snippet': r'$\frac{a}{b}$'},
      {'label': 'Square Root', 'snippet': r'$\sqrt{x}$'},
      {'label': 'Exponent', 'snippet': r'$x^{2}$'},
      {'label': 'Integral', 'snippet': r'$\int_{a}^{b} f(x) dx$'},
      {'label': 'Summation', 'snippet': r'$\sum_{i=1}^{n} x_i$'},
      {'label': 'Limit', 'snippet': r'$\lim_{x \to \infty}$'},
      {
        'label': 'Matrix 2x2',
        'snippet': r'$$\begin{pmatrix} a & b \\ c & d \end{pmatrix}$$',
      },
    ];

    unawaited(
      AppAdaptiveSheet.showModal<void>(
        context: context,
        maxWidth: 480,
        builder: (ctx) {
          final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
          return SafeArea(
            child: Container(
              decoration: isDesktop
                  ? BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(AppRadius.dialog),
                      border: Border.all(
                        color: colors.surfaceBorder.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    )
                  : null,
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insert LaTeX Formula',
                    style: typography.headline.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: snippets.map((s) {
                      return ShrinkableButton(
                        onTap: () {
                          Navigator.pop(ctx);
                          onInsert(s['snippet']!);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 30 : 15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.primary.withAlpha(50),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s['label']!,
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s['snippet']!,
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMathSymbolDialog(
    BuildContext context,
    void Function(String symbol) onInsert,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final symbols = [
      'π',
      'θ',
      'Δ',
      'α',
      'β',
      'γ',
      'λ',
      'μ',
      'σ',
      'ω',
      '≈',
      '≠',
      '≤',
      '≥',
      '±',
      '×',
      '÷',
      '∞',
      '√',
      '∫',
    ];

    unawaited(
      AppAdaptiveSheet.showModal<void>(
        context: context,
        maxWidth: 480,
        builder: (ctx) {
          final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
          return SafeArea(
            child: Container(
              decoration: isDesktop
                  ? BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(AppRadius.dialog),
                      border: Border.all(
                        color: colors.surfaceBorder.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    )
                  : null,
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insert Math & Greek Symbol',
                    style: typography.headline.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: symbols.length,
                    itemBuilder: (ctx, idx) {
                      final sym = symbols[idx];
                      return ShrinkableButton(
                        onTap: () {
                          Navigator.pop(ctx);
                          onInsert(sym);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 25 : 12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.primary.withAlpha(40),
                            ),
                          ),
                          child: Text(
                            sym,
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

String _cleanTitle(String title, String syllabusTag, String track) {
  var cleaned = title.replaceAll(RegExp(r'\*\*|__'), '').trim();
  if (cleaned.toLowerCase().startsWith('question discussion:')) {
    cleaned = cleaned.substring('question discussion:'.length).trim();
  } else if (cleaned.toLowerCase().startsWith('question:')) {
    cleaned = cleaned.substring('question:'.length).trim();
  }
  return cleaned.isEmpty ? '$syllabusTag ($track) Discussion' : cleaned;
}

/// Bidirectional vote pill for the original post card
class _ForumPostVotePill extends StatelessWidget {
  const _ForumPostVotePill({
    required this.netVotes,
    required this.userVote,
    required this.onUpvote,
    required this.onDownvote,
  });

  final int netVotes;
  final int userVote;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isUpvoted = userVote == 1;
    final isDownvoted = userVote == -1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: isUpvoted
            ? colors.recallEasy.withAlpha(isDark ? 50 : 30)
            : (isDownvoted
                  ? colors.error.withAlpha(isDark ? 50 : 30)
                  : (isDark
                        ? colors.surfacePrimary.withAlpha(160)
                        : colors.surfaceSecondary.withAlpha(120))),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShrinkableButton(
            onTap: onUpvote,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUpvoted ? colors.recallEasy : colors.transparent,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: isUpvoted ? colors.white : colors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$netVotes',
              style: typography.caption.bold.copyWith(
                color: isUpvoted
                    ? colors.recallEasy
                    : (isDownvoted ? colors.error : colors.textPrimary),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ShrinkableButton(
            onTap: onDownvote,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDownvoted ? colors.error : colors.transparent,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: isDownvoted ? colors.white : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick tool chip in bottom sticky reply bar
class _QuickToolChip extends StatelessWidget {
  const _QuickToolChip({
    required this.label,
    this.icon,
    this.prefix,
    this.isCodeStyle = false,
    this.isHighlighted = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final String? prefix;
  final bool isCodeStyle;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final tint = isHighlighted ? colors.primary : colors.textSecondary;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedScale(
          scale: isHovered ? 1.04 : 1.0,
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          child: child,
        );
      },
      child: ShrinkableButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isHighlighted
                ? colors.primary.withAlpha(isDark ? 40 : 25)
                : (isDark
                      ? colors.surfacePrimary.withAlpha(180)
                      : colors.surfaceSecondary.withAlpha(120)),
            borderRadius: AppRadius.radiusBadge,
            border: Border.all(
              color: isHighlighted
                  ? colors.primary.withAlpha(80)
                  : colors.surfaceBorder.withAlpha(isDark ? 40 : 25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prefix != null) ...[
                Text(
                  prefix!,
                  style: isCodeStyle
                      ? typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        )
                      : typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11,
                        ),
                ),
                const SizedBox(width: 4),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: tint,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: isHighlighted ? colors.primary : colors.textPrimary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Discussion Thread Group Card (Level 1 Parent + Level 2 Child Replies with Continuous Spine & Anchor Curves)
class _DiscussionThreadGroupCard extends HookWidget {
  const _DiscussionThreadGroupCard({
    required this.parentReply,
    required this.children,
    required this.opAuthorName,
    required this.isQuestion,
    required this.isAuthor,
    required this.hasVerifiedSolution,
    required this.isExpanded,
    required this.isLoadingChildren,
    required this.hasMoreChildren,
    required this.onToggleExpand,
    required this.onLoadMoreChildren,
    required this.onVote,
    required this.onChildVote,
    required this.onReplyTap,
    required this.onChildReplyTap,
    required this.onVerifySolution,
    this.highlightReplyId,
    this.onSaveFlashcard,
    this.onEditReply,
    this.onDeleteReply,
    this.onEditChildReply,
    this.onDeleteChildReply,
    this.onTranscriptUpdated,
  });

  final ForumReplyEntity parentReply;
  final List<ForumReplyEntity> children;
  final String? highlightReplyId;
  final String opAuthorName;
  final bool isQuestion;
  final bool isAuthor;
  final bool hasVerifiedSolution;
  final bool isExpanded;
  final bool isLoadingChildren;
  final bool hasMoreChildren;
  final VoidCallback onToggleExpand;
  final VoidCallback onLoadMoreChildren;
  final void Function(int direction) onVote;
  final void Function(ForumReplyEntity child, int direction) onChildVote;
  final VoidCallback onReplyTap;
  final void Function(String replyId, String newTranscript)?
  onTranscriptUpdated;
  final void Function(ForumReplyEntity child) onChildReplyTap;
  final VoidCallback onVerifySolution;
  final void Function(ForumReplyEntity target)? onSaveFlashcard;
  final VoidCallback? onEditReply;
  final VoidCallback? onDeleteReply;
  final void Function(ForumReplyEntity child)? onEditChildReply;
  final void Function(ForumReplyEntity child)? onDeleteChildReply;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isHighlighted = parentReply.id == highlightReplyId;
    final isUpvoted = parentReply.userVote == 1;
    final isDownvoted = parentReply.userVote == -1;

    final isAiReply =
        parentReply.authorName.toLowerCase().contains('syllabot') ||
        parentReply.content.contains('🤖') ||
        parentReply.content.contains('Syllabot Socratic Hint');

    final isOp =
        parentReply.authorName.toLowerCase() == opAuthorName.toLowerCase();
    final totalChildCount = math.max(
      parentReply.repliesCount,
      children.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEVEL 1 REPLY CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: isHighlighted
                ? Border.all(color: colors.primary, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? colors.primary.withAlpha(isDark ? 65 : 40)
                    : colors.black.withAlpha(isDark ? 25 : 8),
                blurRadius: isHighlighted ? 12 : 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isHighlighted)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.push_pin_rounded,
                        size: 13,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Highlighted Reply',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              // Author Info & Options
              Row(
                children: [
                  if (isAiReply)
                    ClipOval(
                      child: Image(
                        image: AppAssets.images.syllabotAvatar.provider(),
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.syllabotAccent.withAlpha(
                              isDark ? 40 : 25,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.smart_toy_rounded,
                            size: 16,
                            color: colors.syllabotAccent,
                          ),
                        ),
                      ),
                    )
                  else if (parentReply.isAnonymous)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? colors.surfaceSecondary
                            : colors.surfaceBorder.withAlpha(40),
                        border: Border.all(
                          color: colors.textSecondary.withAlpha(
                            isDark ? 60 : 35,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        Icons.visibility_off_rounded,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                    )
                  else
                    AppAvatar(
                      customDimension: 28,
                      name: parentReply.authorName,
                      backgroundColor: colors.primary.withAlpha(
                        isDark ? 40 : 25,
                      ),
                      foregroundColor: colors.primary,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                parentReply.isAnonymous
                                    ? parentReply.authorName
                                    : '@${parentReply.authorName}',
                                style: typography.subhead.bold.copyWith(
                                  color: isAiReply
                                      ? colors.syllabotAccent
                                      : (parentReply.isAnonymous
                                            ? colors.textSecondary
                                            : colors.textPrimary),
                                  fontSize: 13.5,
                                  fontStyle: parentReply.isAnonymous
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (parentReply.isAnonymous)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.textSecondary.withAlpha(
                                    isDark ? 35 : 20,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: colors.textSecondary.withAlpha(
                                      isDark ? 60 : 35,
                                    ),
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 8.5,
                                      color: colors.textSecondary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Incognito',
                                      style: typography.caption.medium.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 8.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isAiReply)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.syllabotAccent.withAlpha(
                                    isDark ? 35 : 20,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'AI TUTOR',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.syllabotAccent,
                                    fontSize: 9,
                                  ),
                                ),
                              )
                            else if (isOp)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'OP',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 9,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? colors.surfacePrimary.withAlpha(180)
                                      : colors.surfaceSecondary,
                                ),
                                child: Text(
                                  'Scholar',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _formatTime(parentReply.createdAt, l10n),
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ShrinkableButton(
                    onTap: () => _showForumReplyOptionsMenu(
                      context,
                      parentReply,
                      onEdit: onEditReply,
                      onDelete: onDeleteReply,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Body Text
              _CleanFormattedText(
                text: parentReply.content,
                baseStyle: typography.body.regular.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),

              if (parentReply.latexContent != null &&
                  parentReply.latexContent!.isNotEmpty) ...[
                const SizedBox(height: 6),
                LatexFormulaBlock(
                  formula: parentReply.latexContent!,
                  backgroundColor: isDark
                      ? colors.surfacePrimary
                      : colors.surfaceSecondary.withAlpha(120),
                  borderColor: colors.surfaceBorder.withAlpha(isDark ? 30 : 20),
                  textStyle: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 13,
                  ),
                ),
              ],

              // Voice note if attached
              if (parentReply.voiceNoteUrl != null &&
                  parentReply.voiceNoteUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                VoiceNotePlayerWidget(
                  audioUrl: parentReply.voiceNoteUrl!,
                  replyId: parentReply.id,
                  durationSeconds: parentReply.voiceNoteDurationSeconds,
                  transcript: parentReply.voiceNoteTranscript,
                  compact: true,
                  onTranscriptLoaded: (newTranscript) {
                    onTranscriptUpdated?.call(parentReply.id, newTranscript);
                  },
                ),
              ],

              // Media images if attached
              if (parentReply.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...parentReply.mediaUrls.asMap().entries.map(
                  (entry) => ForumReplyAttachmentCard(
                    imageUrl: entry.value,
                    customFileName: extractAttachmentFileName(
                      entry.value,
                      index: entry.key,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Interaction Row (Vote Pill + Reply Button + Verify Solution if Bounty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Vote Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfacePrimary.withAlpha(160)
                            : colors.surfaceSecondary.withAlpha(120),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShrinkableButton(
                            onTap: () => onVote(1),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 16,
                                color: isUpvoted
                                    ? colors.recallEasy
                                    : colors.textPrimary,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              parentReply.netVotes > 0
                                  ? '+${parentReply.netVotes}'
                                  : '${parentReply.netVotes}',
                              style: typography.caption.bold.copyWith(
                                color: isUpvoted
                                    ? colors.recallEasy
                                    : (isDownvoted
                                          ? colors.error
                                          : colors.recallEasy),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          ShrinkableButton(
                            onTap: () => onVote(-1),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: isDownvoted
                                    ? colors.error
                                    : colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Reply Button
                    ShrinkableButton(
                      onTap: onReplyTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfacePrimary.withAlpha(120)
                              : colors.surfaceSecondary.withAlpha(80),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              size: 14,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              totalChildCount > 0
                                  ? 'Reply ($totalChildCount)'
                                  : 'Reply',
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Solution Verification Button if Bounty
                    if (isQuestion &&
                        !parentReply.isVerifiedSolution &&
                        (!hasVerifiedSolution || isAuthor)) ...[
                      const SizedBox(width: 8),
                      ShrinkableButton(
                        onTap: onVerifySolution,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.warning.withAlpha(isDark ? 30 : 18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.warning.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 12,
                                color: colors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Mark Solved',
                                style: typography.caption.bold.copyWith(
                                  color: colors.warning,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Save Solution to Flashcard Button
                    const SizedBox(width: 8),
                    ShrinkableButton(
                      onTap: () => onSaveFlashcard?.call(parentReply),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 30 : 18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.primary.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.style_outlined,
                              size: 12,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Save Flashcard',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // SUB-REPLIES SECTION (Only shown if totalChildCount > 0 or children.isNotEmpty)
        if (totalChildCount > 0 || children.isNotEmpty) ...[
          if (!isExpanded) ...[
            // Collapsed Comment / View Replies Trigger
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 8),
              child: Stack(
                children: [
                  // Connecting spine guide leading down
                  Positioned(
                    left: 7,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceBorder.withAlpha(70)
                            : colors.primary.withAlpha(isDark ? 70 : 40),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: ShrinkableButton(
                      onTap: onToggleExpand,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? colors.surfaceBorder.withAlpha(40)
                                : colors.surfaceBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 15,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            if (isLoadingChildren) ...[
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Loading replies...',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ] else ...[
                              Text(
                                children.isNotEmpty
                                    ? '@${children.first.authorName}'
                                    : 'Replies ($totalChildCount)',
                                style: typography.caption.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• View $totalChildCount ${totalChildCount == 1 ? 'reply' : 'replies'}',
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 16,
                              color: colors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Expanded Sub-replies List with continuous vertical guide line
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 8),
              child: Stack(
                children: [
                  // Continuous Connecting Spine Line (vertical guide rod)
                  Positioned(
                    left: 7,
                    top: 0,
                    bottom: 12,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceBorder.withAlpha(70)
                            : colors.primary.withAlpha(isDark ? 70 : 40),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // List of Child Replies
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      children: [
                        ...children.map((child) {
                          return _Level2ChildReplyCard(
                            childReply: child,
                            opAuthorName: opAuthorName,
                            isHighlighted: child.id == highlightReplyId,
                            onVote: (direction) =>
                                onChildVote(child, direction),
                            onReplyTap: () => onChildReplyTap(child),
                            onEdit: onEditChildReply != null
                                ? () => onEditChildReply!(child)
                                : null,
                            onDelete: onDeleteChildReply != null
                                ? () => onDeleteChildReply!(child)
                                : null,
                            onTranscriptUpdated: onTranscriptUpdated,
                          );
                        }),

                        // Sub-replies Pagination Trigger
                        if (hasMoreChildren) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: ShrinkableButton(
                              onTap: isLoadingChildren
                                  ? null
                                  : onLoadMoreChildren,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? colors.surfaceSecondary
                                      : colors.surfacePrimary,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colors.primary.withAlpha(
                                      isDark ? 40 : 25,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isLoadingChildren)
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                colors.primary,
                                              ),
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 14,
                                        color: colors.primary,
                                      ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isLoadingChildren
                                          ? 'Loading more...'
                                          : 'Load more replies',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.primary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Collapse whole sub-thread
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ShrinkableButton(
                            onTap: onToggleExpand,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.expand_less_rounded,
                                    size: 14,
                                    color: colors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Collapse replies',
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _formatTime(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Displays an author action menu (Edit, Delete) or Report menu for any forum reply.
void _showForumReplyOptionsMenu(
  BuildContext context,
  ForumReplyEntity reply, {
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  unawaited(HapticFeedback.lightImpact());
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;
  final userStorage = locator<UserStorageService>();
  final currentUserId = userStorage.getUserId();
  final currentUserName = userStorage.getUserDisplayName() ?? '';
  final isReplyAuthor =
      (currentUserId != null && currentUserId == reply.authorId) ||
      (!reply.isAnonymous &&
          currentUserName.isNotEmpty &&
          currentUserName.toLowerCase() == reply.authorName.toLowerCase());

  unawaited(
    AppAdaptiveSheet.showActionMenu<void>(
      context: context,
      maxWidth: 420,
      builder: (sheetCtx) {
        final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(sheetCtx);
        return SafeArea(
          child: Container(
            decoration: isDesktop
                ? BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppRadius.dialog),
                    border: Border.all(
                      color: colors.surfaceBorder.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  )
                : null,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDesktop)
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (isReplyAuthor) ...[
                  ListTile(
                    leading: Icon(
                      Icons.edit_outlined,
                      color: colors.textPrimary,
                    ),
                    title: Text(
                      'Edit Reply',
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      onEdit?.call();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                    title: Text(
                      'Delete Reply',
                      style: typography.body.medium.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      onDelete?.call();
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: Icon(
                      Icons.flag_outlined,
                      color: colors.error,
                    ),
                    title: Text(
                      'Report Reply',
                      style: typography.body.medium.copyWith(
                        color: colors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      unawaited(
                        ReportContentModalSheet.show(
                          context,
                          contentType: 'forum_reply',
                          contentId: reply.id,
                          contentTitle: reply.content,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Level 2 Child Reply Node with Horizontal Anchor Indicator and Collapsible state
class _Level2ChildReplyCard extends HookWidget {
  const _Level2ChildReplyCard({
    required this.childReply,
    required this.opAuthorName,
    required this.onVote,
    required this.onReplyTap,
    this.isHighlighted = false,
    this.onEdit,
    this.onDelete,
    this.onTranscriptUpdated,
  });

  final ForumReplyEntity childReply;
  final String opAuthorName;
  final void Function(int direction) onVote;
  final VoidCallback onReplyTap;
  final bool isHighlighted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final void Function(String replyId, String newTranscript)?
  onTranscriptUpdated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isCollapsed = useState<bool>(false);
    final isUpvoted = childReply.userVote == 1;
    final isDownvoted = childReply.userVote == -1;

    final isOp =
        childReply.authorName.toLowerCase() == opAuthorName.toLowerCase();
    final isAiReply =
        childReply.authorName.toLowerCase().contains('syllabot') ||
        childReply.content.contains('🤖');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Child Anchor curve / horizontal indicator connecting to vertical spine
          Positioned(
            left: -16,
            top: 18,
            child: Container(
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceBorder.withAlpha(80)
                    : colors.surfaceBorder.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Main Child Card / Collapsed banner
          if (isCollapsed.value)
            ShrinkableButton(
              onTap: () => isCollapsed.value = false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: (isDark
                      ? colors.surfaceSecondary
                      : colors.surfaceSecondary.withAlpha(120)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(isDark ? 30 : 20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 15,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      childReply.isAnonymous
                          ? childReply.authorName
                          : '@${childReply.authorName}',
                      style: typography.caption.bold.copyWith(
                        color: childReply.isAnonymous
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontSize: 12,
                        fontStyle: childReply.isAnonymous
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• Collapsed comment',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(180)
                    : colors.surfaceSecondary.withAlpha(90),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isHighlighted
                      ? colors.primary
                      : colors.surfaceBorder.withAlpha(isDark ? 30 : 20),
                  width: isHighlighted ? 1.8 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isHighlighted)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 50 : 25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin_rounded,
                            size: 11,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Highlighted Reply',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Author Info & Collapse Toggle
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (childReply.isAnonymous)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? colors.surfaceSecondary
                                      : colors.surfaceBorder.withAlpha(40),
                                  border: Border.all(
                                    color: colors.textSecondary.withAlpha(
                                      isDark ? 60 : 35,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Icon(
                                  Icons.visibility_off_rounded,
                                  size: 12,
                                  color: colors.textSecondary,
                                ),
                              )
                            else
                              AppAvatar(
                                customDimension: 22,
                                name: childReply.authorName,
                                backgroundColor: colors.primary.withAlpha(
                                  isDark ? 40 : 25,
                                ),
                                foregroundColor: colors.primary,
                              ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                childReply.isAnonymous
                                    ? childReply.authorName
                                    : '@${childReply.authorName}',
                                style: typography.caption.bold.copyWith(
                                  color: isAiReply
                                      ? colors.syllabotAccent
                                      : (childReply.isAnonymous
                                            ? colors.textSecondary
                                            : colors.textPrimary),
                                  fontSize: 12.5,
                                  fontStyle: childReply.isAnonymous
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (childReply.isAnonymous) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0.8,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.textSecondary.withAlpha(
                                    isDark ? 35 : 20,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: colors.textSecondary.withAlpha(
                                      isDark ? 60 : 35,
                                    ),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 7.5,
                                      color: colors.textSecondary,
                                    ),
                                    const SizedBox(width: 2.5),
                                    Text(
                                      'Incognito',
                                      style: typography.caption.medium.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 7.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isOp) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'OP',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 8.5,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(childReply.createdAt, l10n),
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      ShrinkableButton(
                        onTap: () => _showForumReplyOptionsMenu(
                          context,
                          childReply,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ShrinkableButton(
                        onTap: () => isCollapsed.value = true,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.unfold_less_rounded,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Body Text
                  _CleanFormattedText(
                    text: childReply.content,
                    baseStyle: typography.footnote.regular.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  if (childReply.latexContent != null &&
                      childReply.latexContent!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    LatexFormulaBlock(
                      formula: childReply.latexContent!,
                      backgroundColor: isDark
                          ? colors.surfacePrimary
                          : colors.surfaceSecondary.withAlpha(120),
                      borderColor: colors.surfaceBorder.withAlpha(
                        isDark ? 30 : 20,
                      ),
                      textStyle: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  // Voice note if attached
                  if (childReply.voiceNoteUrl != null &&
                      childReply.voiceNoteUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    VoiceNotePlayerWidget(
                      audioUrl: childReply.voiceNoteUrl!,
                      replyId: childReply.id,
                      durationSeconds: childReply.voiceNoteDurationSeconds,
                      transcript: childReply.voiceNoteTranscript,
                      compact: true,
                      onTranscriptLoaded: (newTranscript) {
                        onTranscriptUpdated?.call(childReply.id, newTranscript);
                      },
                    ),
                  ],

                  // Media images if attached
                  if (childReply.mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...childReply.mediaUrls.asMap().entries.map(
                      (entry) => ForumReplyAttachmentCard(
                        imageUrl: entry.value,
                        customFileName: extractAttachmentFileName(
                          entry.value,
                          index: entry.key,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Interaction Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfacePrimary.withAlpha(140)
                              : colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShrinkableButton(
                              onTap: () => onVote(1),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 14,
                                  color: isUpvoted
                                      ? colors.recallEasy
                                      : colors.textPrimary,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Text(
                                childReply.netVotes > 0
                                    ? '+${childReply.netVotes}'
                                    : '${childReply.netVotes}',
                                style: typography.caption.bold.copyWith(
                                  color: isUpvoted
                                      ? colors.recallEasy
                                      : (isDownvoted
                                            ? colors.error
                                            : colors.recallEasy),
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                            ShrinkableButton(
                              onTap: () => onVote(-1),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 14,
                                  color: isDownvoted
                                      ? colors.error
                                      : colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShrinkableButton(
                        onTap: onReplyTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              size: 13,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Reply',
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ForumThreadStructuredBody extends StatelessWidget {
  const _ForumThreadStructuredBody({
    required this.post,
  });

  final ForumPostEntity post;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final rawContent = post.content;

    // Parse options, prompt, explanation, and answer comparison if available
    final lines = rawContent.split('\n');
    final promptLines = <String>[];
    final options = <String>[];
    final explanationLines = <String>[];
    String? correctAnswer;
    String? userAnswer;

    var readingOptions = false;
    var readingExplanation = false;

    final optionPrefixRegex = RegExp(
      r'^([A-Da-d0-9][\.\:\)]|\([A-Da-d0-9]\)|[\•\-\*])\s*(.*)',
    );
    final letterPrefixRegex = RegExp(
      r'^([A-Da-d0-9][\.\:\)]|\([A-Da-d0-9]\))\s*(.*)',
    );

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final lower = line.toLowerCase();
      if (lower.startsWith('**options:**') ||
          lower.startsWith('options:') ||
          lower.startsWith('choices:')) {
        readingOptions = true;
        readingExplanation = false;
        continue;
      }
      if (lower.startsWith('**explanation:**') ||
          lower.startsWith('explanation:') ||
          lower.startsWith('solution:') ||
          lower.startsWith('why is this correct?')) {
        readingExplanation = true;
        readingOptions = false;
        final colonIdx = line.indexOf(':');
        if (colonIdx != -1 && colonIdx < line.length - 1) {
          final contentAfter = line
              .substring(colonIdx + 1)
              .replaceAll('*', '')
              .trim();
          if (contentAfter.isNotEmpty) {
            explanationLines.add(contentAfter);
          }
        }
        continue;
      }
      if (lower.startsWith('**correct answer:**') ||
          lower.startsWith('correct answer:') ||
          lower.startsWith('correct:')) {
        final colonIdx = line.indexOf(':');
        correctAnswer = colonIdx != -1
            ? line.substring(colonIdx + 1).replaceAll('*', '').trim()
            : line.replaceAll('*', '').trim();
        readingOptions = false;
        continue;
      }
      if (lower.startsWith('**your answer:**') ||
          lower.startsWith('your answer:') ||
          lower.startsWith('selected answer:') ||
          lower.startsWith('user answer:')) {
        final colonIdx = line.indexOf(':');
        userAnswer = colonIdx != -1
            ? line.substring(colonIdx + 1).replaceAll('*', '').trim()
            : line.replaceAll('*', '').trim();
        readingOptions = false;
        continue;
      }
      if (lower.startsWith('**question:**') || lower.startsWith('question:')) {
        final colonIdx = line.indexOf(':');
        if (colonIdx != -1 && colonIdx < line.length - 1) {
          final after = line.substring(colonIdx + 1).replaceAll('*', '').trim();
          if (after.isNotEmpty) {
            promptLines.add(after);
          }
        }
        continue;
      }

      if (readingExplanation) {
        explanationLines.add(line);
      } else if (readingOptions) {
        if (optionPrefixRegex.hasMatch(line) ||
            RegExp('^[A-Da-d]').hasMatch(line)) {
          options.add(line);
        } else {
          readingOptions = false;
          promptLines.add(line);
        }
      } else if (letterPrefixRegex.hasMatch(line)) {
        options.add(line);
        readingOptions = true;
      } else {
        promptLines.add(line);
      }
    }

    final promptText = promptLines
        .join('\n')
        .replaceAll(RegExp(r'^\*\*Question:\*\*\s*', caseSensitive: false), '')
        .trim();
    final explanationText = explanationLines.join('\n').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prompt Card
        if (promptText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfacePrimary
                  : colors.surfaceSecondary.withAlpha(120),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 40 : 20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'QUESTION PROMPT',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (options.isNotEmpty)
                      QuizAudioReaderButton(
                        questionText: promptText,
                        options: options,
                        size: 28,
                        iconSize: 14,
                      )
                    else
                      AudioPronounceButton(
                        textToPronounce: promptText,
                        size: 28,
                        iconSize: 14,
                        tooltip: 'Listen to prompt',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _CleanFormattedText(
                  text: promptText,
                  baseStyle: typography.body.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

        // Neutral Question Options List
        if (options.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Options',
            style: typography.caption.bold.copyWith(
              color: colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            var letter = '';
            var optText = opt;

            final letterMatch = letterPrefixRegex.firstMatch(opt);
            if (letterMatch != null) {
              letter =
                  letterMatch
                      .group(1)
                      ?.replaceAll(RegExp(r'[\(\)\.\:\s]'), '') ??
                  '';
              optText = letterMatch.group(2) ?? opt;
            } else if (opt.startsWith('•') ||
                opt.startsWith('-') ||
                opt.startsWith('*')) {
              letter = String.fromCharCode(65 + idx);
              optText = opt.replaceFirst(RegExp(r'^[\•\-\*]\s*'), '');
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfacePrimary
                    : colors.surfaceSecondary.withAlpha(100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(isDark ? 30 : 15),
                ),
              ),
              child: Row(
                children: [
                  if (letter.isNotEmpty) ...[
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withAlpha(isDark ? 35 : 20),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 60 : 35),
                        ),
                      ),
                      child: Text(
                        letter.toUpperCase(),
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _CleanFormattedText(
                      text: optText,
                      baseStyle: typography.footnote.regular.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // User & Correct Answer Summary Pill
        if (correctAnswer != null || userAnswer != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfacePrimary
                  : colors.surfaceSecondary.withAlpha(80),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(isDark ? 30 : 20),
              ),
            ),
            child: Row(
              children: [
                if (correctAnswer != null) ...[
                  Icon(
                    Icons.check_circle_outline,
                    size: 15,
                    color: colors.success,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _CleanFormattedText(
                      text: 'Correct: $correctAnswer',
                      baseStyle: typography.caption.bold.copyWith(
                        color: colors.success,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
                if (userAnswer != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: _CleanFormattedText(
                      text: 'Selected: $userAnswer',
                      baseStyle: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Concept Explanation Card
        if (explanationText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 25 : 12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 50 : 30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: colors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Concept Explanation',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            letterSpacing: 0.5,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    AudioPronounceButton(
                      textToPronounce: explanationText,
                      size: 26,
                      iconSize: 13,
                      tooltip: 'Listen to explanation',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _CleanFormattedText(
                  text: explanationText,
                  baseStyle: typography.footnote.regular.copyWith(
                    color: colors.textPrimary,
                    height: 1.45,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CleanFormattedText extends StatelessWidget {
  const _CleanFormattedText({
    required this.text,
    required this.baseStyle,
  });

  final String text;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    var sanitized = text.replaceAll(
      RegExp(r'[\uFFFD\u0000-\u0008\u000B\u000C\u000E-\u001F]+'),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'^\*\*Question:\*\*\s*', caseSensitive: false),
      '',
    );

    return LatexRichViewer(
      text: sanitized,
      style: baseStyle,
    );
  }
}
