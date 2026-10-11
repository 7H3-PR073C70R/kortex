import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';
import 'package:kortex/src/core/services/media_upload_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/services/content_moderation_service.dart';
import 'package:kortex/src/features/community/domain/services/forum_socratic_hint_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/discussion_thread_group_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_flashcard_sheets.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_media_attachment_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_post_vote_pill.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_edit_sheets.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_reply_composer_bar.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_structured_body.dart';
import 'package:kortex/src/features/community/presentation/widgets/moderation_feedback_dialog.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/subject_master_badge.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder_widget.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
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

        final finalHintContent = await ForumSocraticHintService.generateHint(
          post: currentPost.value,
          streamUseCase: streamUseCase,
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

    // Initial check for thread subscription and bookmark state (deferred post-frame for zero-latency route transition)
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

      StreamSubscription<List<ForumReplyEntity>>? wsSubscription;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // WebSocket Realtime Stream for live thread replies
        wsSubscription = repo.watchForumReplies(post.id).listen((
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
      });

      return () {
        unawaited(wsSubscription?.cancel());
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

    final isFirstSortEffect = useRef<bool>(true);
    useEffect(() {
      if (isFirstSortEffect.value) {
        isFirstSortEffect.value = false;
        return null;
      }
      unawaited(fetchTopLevelReplies());
      return null;
    }, [sortFilter.value]);

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
      } on Object catch (e, st) { AppLogger.recordNonFatal(e, st); }
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
      await ForumThreadEditSheets.confirmDeletePost(
        context,
        postId: currentPost.value.id,
        repository: repo,
      );
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
      await ForumThreadEditSheets.showEditPostSheet(
        context,
        post: currentPost.value,
        repository: repo,
        onUpdated: (updated) {
          currentPost.value = currentPost.value.copyWith(
            title: updated.title,
            content: updated.content,
          );
        },
      );
    }

    Future<void> showEditReplySheet(
      BuildContext context,
      ForumReplyEntity reply,
    ) async {
      await ForumThreadEditSheets.showEditReplySheet(
        context,
        reply: reply,
        repository: repo,
        onUpdated: (updated) {
          localReplies.value = localReplies.value
              .map<ForumReplyEntity>((r) {
                if (r.id == reply.id) {
                  return r.copyWith(content: updated.content);
                }
                return r;
              })
              .toList();
        },
      );
    }

    Future<void> confirmDeleteReply(
      BuildContext context,
      ForumReplyEntity reply,
    ) async {
      await ForumThreadEditSheets.confirmDeleteReply(
        context,
        postId: post.id,
        reply: reply,
        repository: repo,
        onDeleted: () {
          localReplies.value = localReplies.value
              .where((r) => r.id != reply.id)
              .toList();
          currentPost.value = currentPost.value.copyWith(
            repliesCount: math.max(0, currentPost.value.repliesCount - 1),
          );
        },
      );
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

    Future<void> submitReply() async {
      final text = replyController.text.trim();
      if (text.isEmpty &&
          replyImages.value.isEmpty &&
          replyVoiceNoteUrl.value == null) {
        return;
      }

      // Content safety & anti-abuse moderation check for replies
      if (text.isNotEmpty) {
        const moderation = ContentModerationService();
        final modResult = moderation.validateReply(content: text);
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

      final sanitizedText = ContentModerationService.sanitizeText(text);
      final targetParentId = replyingToReply.value?.id;
      isSubmitting.value = true;

      var finalReplyImages = <String>[];
      if (replyImages.value.isNotEmpty) {
        if (locator.isRegistered<MediaUploadService>()) {
          final uploadService = locator<MediaUploadService>();
          for (final imgPath in replyImages.value) {
            if (imgPath.startsWith('http://') ||
                imgPath.startsWith('https://')) {
              finalReplyImages.add(imgPath);
            } else {
              try {
                final r2Url = await uploadService.uploadMedia(
                  pathOrUrl: imgPath,
                  file: kIsWeb ? null : File(imgPath),
                  mediaType: ForumMediaType.image,
                );
                finalReplyImages.add(r2Url);
              } on Object catch (e, st) {
                AppLogger.recordNonFatal(e, st);
              }
            }
          }
        } else {
          finalReplyImages = replyImages.value;
        }
      }

      var finalReplyVoiceNoteUrl = replyVoiceNoteUrl.value;
      if (finalReplyVoiceNoteUrl != null &&
          !finalReplyVoiceNoteUrl.startsWith('http://') &&
          !finalReplyVoiceNoteUrl.startsWith('https://') &&
          locator.isRegistered<MediaUploadService>()) {
        final uploadService = locator<MediaUploadService>();
        try {
          final r2Url = await uploadService.uploadMedia(
            pathOrUrl: finalReplyVoiceNoteUrl,
            file: kIsWeb ? null : File(finalReplyVoiceNoteUrl),
            mediaType: ForumMediaType.voice,
          );
          finalReplyVoiceNoteUrl = r2Url;
        } on Object catch (e, st) {
          AppLogger.recordNonFatal(e, st);
        }
      }

      final res = await repo.replyToForumPost(
        postId: currentPost.value.id,
        content: sanitizedText.isNotEmpty
            ? sanitizedText
            : 'Shared media attachment',
        parentReplyId: targetParentId,
        mediaUrls: finalReplyImages,
        voiceNoteUrl: finalReplyVoiceNoteUrl,
        voiceNoteDurationSeconds: replyVoiceNoteDuration.value > 0
            ? replyVoiceNoteDuration.value
            : null,
        voiceNoteTranscript: replyVoiceTranscript.value.trim().isNotEmpty
            ? replyVoiceTranscript.value.trim()
            : null,
        isAnonymous: isAnonymousReply.value,
      );
      isSubmitting.value = false;
      res.fold(
        (failure) {
          if (context.mounted) {
            context.showSnackBar(
              message: failure.message ?? failure.toString(),
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
          if (!localReplies.value.any((r) => r.id == createdReply.id)) {
            localReplies.value = [
              ...localReplies.value,
              createdReply,
            ];
          }

          final vnUrl = createdReply.voiceNoteUrl;
          if (vnUrl != null &&
              vnUrl.trim().isNotEmpty &&
              locator.isRegistered<MediaUploadService>()) {
            unawaited(
              locator<MediaUploadService>().triggerVoiceNoteTranscription(
                audioUrl: vnUrl,
                replyId: createdReply.id,
              ),
            );
          }
          if (targetParentId != null) {
            localReplies.value = localReplies.value.map((r) {
              if (r.id == targetParentId) {
                return r.copyWith(repliesCount: r.repliesCount + 1);
              }
              return r;
            }).toList();
            expandedParentReplyIds.value = {
              ...expandedParentReplyIds.value,
              targetParentId,
            };
          }
          if (locator.isRegistered<CommunityHubBloc>()) {
            locator<CommunityHubBloc>().add(
              ForumPostRepliesIncrementedEvent(
                postId: currentPost.value.id,
                reply: createdReply,
              ),
            );
          }
        },
      );
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
                                      ForumThreadStructuredBody(
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
                                          // Left cluster scales down on narrow
                                          // panes so the trailing buttons never overflow.
                                          Expanded(
                                            child: Align(
                                              alignment: AlignmentDirectional
                                                  .centerStart,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: AlignmentDirectional
                                                    .centerStart,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Vote Group Pill
                                                    ForumPostVotePill(
                                                      netVotes: currentPost
                                                          .value
                                                          .netVotes,
                                                      userVote: currentPost
                                                          .value
                                                          .userVote,
                                                      onUpvote: () =>
                                                          votePost(1),
                                                      onDownvote: () =>
                                                          votePost(-1),
                                                    ),
                                                    const SizedBox(width: 8),

                                                    // Replies Count Indicator
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? colors
                                                                  .surfacePrimary
                                                                  .withAlpha(
                                                                    160,
                                                                  )
                                                            : colors
                                                                  .surfaceSecondary
                                                                  .withAlpha(
                                                                    120,
                                                                  ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .chat_bubble_outline_rounded,
                                                            size: 15,
                                                            color: colors
                                                                .textSecondary,
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            '${localReplies.value.length}',
                                                            style: typography
                                                                .caption
                                                                .bold
                                                                .copyWith(
                                                                  color: colors
                                                                      .textSecondary,
                                                                  fontSize: 12,
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
                                          const SizedBox(width: 8),

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
                                        child: DiscussionThreadGroupCard(
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

            // Sticky Bottom Quick Reply Bar (Modularized widget)
            ForumThreadReplyComposerBar(
              replyController: replyController,
              focusNode: focusNode,
              replyRecorderController: replyRecorderController,
              replyingToReply: replyingToReply,
              showFormattingTools: showFormattingTools,
              isRecordingReplyVoice: isRecordingReplyVoice,
              isReplyVoiceLocked: isReplyVoiceLocked,
              replyVoiceNoteDuration: replyVoiceNoteDuration,
              replyVoiceTranscript: replyVoiceTranscript,
              replyVoiceNoteUrl: replyVoiceNoteUrl,
              replyImages: replyImages,
              isAnonymousReply: isAnonymousReply,
              isSubmitting: isSubmitting,
              isGeneratingAiHint: isGeneratingAiHint,
              onApplyFormat: applyFormat,
              onInsertSnippet: insertIntoComposer,
              onGenerateAiHint: generateSyllabotHint,
              onSubmitReply: submitReply,
            ),
          ],
        ),
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
