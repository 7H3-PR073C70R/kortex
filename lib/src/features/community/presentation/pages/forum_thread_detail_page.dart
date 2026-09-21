import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/services/forum_socratic_hint_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_media_attachment_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_player_widget.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:share_plus/share_plus.dart';

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
    super.key,
  });

  final ForumPostEntity post;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final replyController = useTextEditingController();
    final focusNode = useFocusNode();
    final isSubmitting = useState<bool>(false);
    final isGeneratingAiHint = useState<bool>(false);
    final isSubscribed = useState<bool>(false);
    final isBookmarked = useState<bool>(false);
    final sortFilter = useState<ForumSortFilter>(ForumSortFilter.topVoted);
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
    final showFormattingTools = useState<bool>(false);
    final replyRecordingTimer = useRef<Timer?>(null);

    final replySttHandler = useMemoized(
      () => SpeechToTextHandler(
        onResult: (words) {
          if (words.trim().isNotEmpty) {
            final current = replyController.text;
            if (current.isEmpty) {
              replyController.text = words;
            } else if (!current.contains(words)) {
              replyController.text = '$current $words';
            }
          }
        },
        onListeningChanged: (listening) {
          isRecordingReplyVoice.value = listening;
          if (listening) {
            replyVoiceNoteDuration.value = 0;
            replyRecordingTimer.value?.cancel();
            replyRecordingTimer.value = Timer.periodic(
              const Duration(seconds: 1),
              (timer) {
                replyVoiceNoteDuration.value = timer.tick;
              },
            );
          } else {
            replyRecordingTimer.value?.cancel();
            if (replyVoiceNoteDuration.value > 0) {
              replyVoiceNoteUrl.value ??= 'audio/voice_note.wav';
            }
          }
        },
        onError: (err) {
          isRecordingReplyVoice.value = false;
          replyRecordingTimer.value?.cancel();
        },
      ),
    );

    useEffect(() {
      return () {
        replyRecordingTimer.value?.cancel();
        replySttHandler.dispose();
      };
    }, []);

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
          final existingIds = localReplies.value.map((r) => r.id).toSet();
          final unique = fetched
              .where((r) => !existingIds.contains(r.id))
              .toList();
          if (isLoadMore) {
            localReplies.value = [...localReplies.value, ...unique];
            topLevelOffset.value = currentOffset + fetched.length;
            hasMoreTopLevel.value = fetched.length >= fetchLimit;
          } else {
            final childReplies = localReplies.value
                .where(
                  (r) => r.parentReplyId != null && r.parentReplyId!.isNotEmpty,
                )
                .toList();
            localReplies.value = [...unique, ...childReplies];
            topLevelOffset.value = fetched.length;
            hasMoreTopLevel.value = fetched.length >= fetchLimit;
          }
        },
      );
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
            localReplies.value = treeData.replies;
            isInitialLoadingReplies.value = false;
            topLevelOffset.value = treeData.replies
                .where((r) => !r.isNested)
                .length;
          },
        );
      }

      unawaited(checkSubscriptionAndBookmark());
      unawaited(initialLoadThreadTree());
      return null;
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

    // Real-time replies stream
    final repliesStream = useMemoized(
      () => repo.watchForumReplies(post.id),
      [post.id],
    );
    final repliesSnapshot = useStream(repliesStream, initialData: post.replies);

    useEffect(() {
      if (repliesSnapshot.hasData && repliesSnapshot.data != null) {
        final streamed = repliesSnapshot.data!;
        final existingIds = localReplies.value.map((r) => r.id).toSet();
        final newOnes = streamed
            .where((r) => !existingIds.contains(r.id))
            .toList();
        if (newOnes.isNotEmpty) {
          localReplies.value = [...localReplies.value, ...newOnes];
        }
      }
      return null;
    }, [repliesSnapshot.data]);

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
                style: TextStyle(color: colors.textSecondary),
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
        SharePlus.instance.share(
          ShareParams(
            text:
                'Check out this discussion on Kortex: ${currentPost.value.title}\n\n${currentPost.value.content}\n\nhttps://kortex.app/forum/post/${post.id}',
          ),
        ),
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
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: isDark
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                        Icons.link_rounded,
                        color: colors.textPrimary,
                      ),
                      title: Text(
                        'Copy Link',
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        unawaited(
                          Clipboard.setData(
                            ClipboardData(
                              text: 'https://kortex.app/forum/post/${post.id}',
                            ),
                          ),
                        );
                        context.showSnackBar(
                          message: 'Post link copied to clipboard',
                        );
                      },
                    ),
                    if (isAuthor)
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
                      )
                    else
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
      if (selection.isValid &&
          selection.start >= 0 &&
          selection.end > selection.start) {
        final selectedText = text.substring(selection.start, selection.end);
        final replacement = '$prefix$selectedText$suffix';
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          replacement,
        );
        replyController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: selection.start + prefix.length,
            extentOffset: selection.start + prefix.length + selectedText.length,
          ),
        );
      } else {
        final insertIndex = selection.isValid && selection.start >= 0
            ? selection.start
            : text.length;
        final snippet = '$prefix$placeholder$suffix';
        final newText = text.replaceRange(insertIndex, insertIndex, snippet);
        final cursorOffset =
            insertIndex +
            prefix.length +
            (placeholder.isNotEmpty ? placeholder.length : 0);
        replyController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursorOffset),
        );
      }
      focusNode.requestFocus();
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

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor:
            (isDark ? colors.surfaceSecondary : colors.surfacePrimary)
                .withAlpha(230),
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: colors.black.withAlpha(20),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colors.textPrimary,
            size: 22,
          ),
          onPressed: () => unawaited(context.router.maybePop()),
        ),
        title: Row(
          children: [
            Text(
              'Thread Detail',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
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
            tooltip: 'Report Thread',
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
            tooltip: 'Share Thread',
            onPressed: shareThread,
          ),
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
                  child: CustomScrollView(
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
                                  border: Border.all(
                                    color: colors.surfaceBorder.withAlpha(
                                      isDark ? 50 : 30,
                                    ),
                                  ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                            borderRadius: BorderRadius.circular(
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
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: colors.primary
                                                  .withAlpha(isDark ? 50 : 35),
                                              child: Text(
                                                currentPost
                                                        .value
                                                        .authorName
                                                        .isNotEmpty
                                                    ? currentPost
                                                          .value
                                                          .authorName[0]
                                                          .toUpperCase()
                                                    : '?',
                                                style: typography.footnote.bold
                                                    .copyWith(
                                                      color: colors.primary,
                                                    ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: -1,
                                              right: -1,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: colors.success,
                                                  border: Border.all(
                                                    color: isDark
                                                        ? colors
                                                              .surfaceSecondary
                                                        : colors.surfacePrimary,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.check,
                                                  size: 8,
                                                  color: colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
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
                                                      '@${currentPost.value.authorName}',
                                                      style: typography
                                                          .subhead
                                                          .bold
                                                          .copyWith(
                                                            color: colors
                                                                .textPrimary,
                                                            fontSize: 14.5,
                                                          ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
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
                                                      style: TextStyle(
                                                        color: colors.white,
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                currentPost
                                                        .value
                                                        .syllabusTag
                                                        .isNotEmpty
                                                    ? 'Staff Level Scholar • ${currentPost.value.syllabusTag}'
                                                    : 'Staff Level Scholar',
                                                style: typography
                                                    .caption
                                                    .regular
                                                    .copyWith(
                                                      color:
                                                          colors.textSecondary,
                                                      fontSize: 11.5,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
                                            color: colors.primary.withAlpha(40),
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
                                            Text(
                                              currentPost.value.latexContent!,
                                              style: typography.body.bold
                                                  .copyWith(
                                                    color: colors.primary,
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
                                        durationSeconds: currentPost
                                            .value
                                            .voiceNoteDurationSeconds,
                                      ),
                                    ],

                                    // Media Images preview if present
                                    if (currentPost
                                        .value
                                        .mediaUrls
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      ForumPostMediaPreview(
                                        mediaUrls: currentPost.value.mediaUrls,
                                        heroHeight: 165,
                                      ),
                                    ],

                                    // Semantic Tags Wrap
                                    if (currentPost.value.tags.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: currentPost.value.tags.map((
                                          tag,
                                        ) {
                                          final displayTag = tag.startsWith('#')
                                              ? tag
                                              : '#$tag';
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
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
                                          netVotes: currentPost.value.netVotes,
                                          userVote: currentPost.value.userVote,
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
                                            borderRadius: BorderRadius.circular(
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
                                                      color:
                                                          colors.textSecondary,
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

                              // Sort Filter Dropdown Pill
                              PopupMenuButton<ForumSortFilter>(
                                initialValue: sortFilter.value,
                                tooltip: 'Sort Replies',
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
                                      final isSelected = f == sortFilter.value;
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
                                              style: typography.footnote.medium
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
                                        ? colors.surfaceSecondary.withAlpha(160)
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
                                        style: typography.caption.bold.copyWith(
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
                                      return b.createdAt.compareTo(a.createdAt);
                                    case ForumSortFilter.topVoted:
                                      final voteComp = b.netVotes.compareTo(
                                        a.netVotes,
                                      );
                                      if (voteComp != 0) return voteComp;
                                      return b.createdAt.compareTo(a.createdAt);
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
                                      if (aIsAi != bIsAi) return aIsAi ? -1 : 1;
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
                                      return b.createdAt.compareTo(a.createdAt);
                                  }
                                });

                          // Group nested replies
                          final nestedRepliesMap =
                              <String, List<ForumReplyEntity>>{};
                          for (final reply in allReplies) {
                            if (reply.parentReplyId != null &&
                                reply.parentReplyId!.isNotEmpty) {
                              nestedRepliesMap
                                  .putIfAbsent(reply.parentReplyId!, () => [])
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
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
                                                        >(
                                                          colors.white,
                                                        ),
                                                  ),
                                                )
                                              else
                                                Icon(
                                                  Icons.auto_awesome_rounded,
                                                  size: 16,
                                                  color: colors.white,
                                                ),
                                              const SizedBox(width: 8),
                                              Text(
                                                isGeneratingAiHint.value
                                                    ? 'Consulting Syllabot...'
                                                    : 'Ask Syllabot for Socratic Hint 🤖',
                                                style: typography.caption.bold
                                                    .copyWith(
                                                      color: colors.white,
                                                      letterSpacing: 0.2,
                                                    ),
                                              ),
                                            ],
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
                                    currentUserId == currentPost.value.authorId;

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
                                    opAuthorName: currentPost.value.authorName,
                                    isQuestion: currentPost.value.isQuestion,
                                    isAuthor: isAuthor,
                                    hasVerifiedSolution: hasVerifiedSolution,
                                    isExpanded: expandedParentReplyIds.value
                                        .contains(reply.id),
                                    isLoadingChildren: loadingParentReplyIds
                                        .value
                                        .contains(reply.id),
                                    hasMoreChildren:
                                        hasMoreSubRepliesMap.value[reply.id] ??
                                        false,
                                    onToggleExpand: () =>
                                        toggleSubRepliesExpansion(reply.id),
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
                                    onVerifySolution: () async {
                                      final res = await repo.verifyForumReply(
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
                                          localReplies.value = localReplies
                                              .value
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
                                                  'Marked as verified solution! 100 XP bounty awarded to ${reply.authorName}.',
                                            );
                                          }
                                        },
                                      );
                                    },
                                  ),
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
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.error.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colors.error.withAlpha(60),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.mic_rounded,
                                    size: 16,
                                    color: colors.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Recording voice (${replyVoiceNoteDuration.value}s)... Tap mic to finish',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
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
                              compact: true,
                              onDelete: () {
                                replyVoiceNoteUrl.value = null;
                                replyVoiceNoteDuration.value = 0;
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
                                icon: Icon(
                                  Icons.attach_file_rounded,
                                  size: 21,
                                  color: replyImages.value.isNotEmpty
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                                tooltip: 'Attach Image',
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

                              // 2. Mic Button (Replaces code button in row)
                              IconButton(
                                icon: Icon(
                                  isRecordingReplyVoice.value
                                      ? Icons.stop_circle_rounded
                                      : Icons.mic_rounded,
                                  size: 21,
                                  color: isRecordingReplyVoice.value
                                      ? colors.error
                                      : (replyVoiceNoteUrl.value != null
                                            ? colors.primary
                                            : colors.textSecondary),
                                ),
                                tooltip: isRecordingReplyVoice.value
                                    ? 'Stop Recording'
                                    : 'Voice Reply',
                                onPressed: () async {
                                  unawaited(HapticFeedback.mediumImpact());
                                  try {
                                    if (isRecordingReplyVoice.value) {
                                      await replySttHandler.stopListening();
                                      replyRecordingTimer.value?.cancel();
                                      if (replyVoiceNoteDuration.value == 0) {
                                        replyVoiceNoteDuration.value = 5;
                                      }
                                      replyVoiceNoteUrl.value ??=
                                          'audio/voice_note.wav';
                                    } else {
                                      await replySttHandler.startListening();
                                    }
                                  } on Object catch (e) {
                                    isRecordingReplyVoice.value = false;
                                    replyRecordingTimer.value?.cancel();
                                    if (context.mounted) {
                                      context.showSnackBar(
                                        message:
                                            'Speech recognition unavailable: $e',
                                      );
                                    }
                                  }
                                },
                              ),

                              // 3. Compact Styling Tools Toggle Button
                              IconButton(
                                icon: Icon(
                                  showFormattingTools.value
                                      ? Icons.text_format_rounded
                                      : Icons.text_fields_rounded,
                                  size: 20,
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

                              // 4. Text Field
                              Expanded(
                                child: TextField(
                                  controller: replyController,
                                  focusNode: focusNode,
                                  maxLines: 4,
                                  minLines: 1,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    hintText: replyingToReply.value != null
                                        ? 'Write a reply to @${replyingToReply.value!.authorName}...'
                                        : 'Add a thoughtful reply...',
                                    hintStyle: typography.body.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? colors.surfaceSecondary.withAlpha(160)
                                        : colors.surfaceSecondary.withAlpha(
                                            130,
                                          ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      borderSide: BorderSide(
                                        color: colors.surfaceBorder.withAlpha(
                                          isDark ? 60 : 35,
                                        ),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      borderSide: BorderSide(
                                        color: colors.surfaceBorder.withAlpha(
                                          isDark ? 60 : 35,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      borderSide: BorderSide(
                                        color: colors.primary.withAlpha(160),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 9,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 5. Send Button
                              PlatformHoverBuilder(
                                builder: (context, isHovered, child) {
                                  return AnimatedScale(
                                    scale: isHovered ? 1.06 : 1.0,
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
                                          final targetParentId =
                                              replyingToReply.value?.id;
                                          isSubmitting.value = true;
                                          final res = await repo
                                              .replyToForumPost(
                                                postId: currentPost.value.id,
                                                content: text.isNotEmpty
                                                    ? text
                                                    : 'Shared media attachment',
                                                parentReplyId: targetParentId,
                                                mediaUrls: replyImages.value,
                                                voiceNoteUrl:
                                                    replyVoiceNoteUrl.value,
                                                voiceNoteDurationSeconds:
                                                    replyVoiceNoteDuration
                                                            .value >
                                                        0
                                                    ? replyVoiceNoteDuration
                                                          .value
                                                    : null,
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
                                              if (!localReplies.value.any(
                                                (r) => r.id == createdReply.id,
                                              )) {
                                                localReplies.value = [
                                                  ...localReplies.value,
                                                  createdReply,
                                                ];
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
                                    child: isSubmitting.value
                                        ? AppLogoLoader(
                                            size: 16,
                                            color: colors.white,
                                            showMessage: false,
                                          )
                                        : Icon(
                                            Icons.send_rounded,
                                            color: colors.white,
                                            size: 18,
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
      {'label': 'Fraction', 'snippet': r'\frac{a}{b}'},
      {'label': 'Square Root', 'snippet': r'\sqrt{x}'},
      {'label': 'Exponent', 'snippet': 'x^{2}'},
      {'label': 'Integral', 'snippet': r'\int_{a}^{b} f(x) dx'},
      {'label': 'Summation', 'snippet': r'\sum_{i=1}^{n} x_i'},
      {'label': 'Limit', 'snippet': r'\lim_{x \to \infty}'},
      {
        'label': 'Matrix 2x2',
        'snippet': r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
      },
    ];

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: isDark
            ? colors.surfaceSecondary
            : colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
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
        ),
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
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: isDark
            ? colors.surfaceSecondary
            : colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
  });

  final ForumReplyEntity parentReply;
  final List<ForumReplyEntity> children;
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
  final void Function(ForumReplyEntity child) onChildReplyTap;
  final VoidCallback onVerifySolution;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

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
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(isDark ? 40 : 25),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(isDark ? 25 : 8),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  else
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: colors.primary.withAlpha(
                        isDark ? 40 : 25,
                      ),
                      child: Text(
                        parentReply.authorName.isNotEmpty
                            ? parentReply.authorName[0].toUpperCase()
                            : '?',
                        style: typography.caption.bold.copyWith(
                          fontSize: 11,
                          color: colors.primary,
                        ),
                      ),
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
                                '@${parentReply.authorName}',
                                style: typography.subhead.bold.copyWith(
                                  color: isAiReply
                                      ? colors.syllabotAccent
                                      : colors.textPrimary,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
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
                                  style: TextStyle(
                                    color: colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
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
                    onTap: () {
                      unawaited(
                        ReportContentModalSheet.show(
                          context,
                          contentType: 'forum_reply',
                          contentId: parentReply.id,
                          contentTitle: parentReply.content,
                        ),
                      );
                    },
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfacePrimary
                        : colors.surfaceSecondary.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    parentReply.latexContent!,
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],

              // Voice note if attached
              if (parentReply.voiceNoteUrl != null &&
                  parentReply.voiceNoteUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                VoiceNotePlayerWidget(
                  audioUrl: parentReply.voiceNoteUrl!,
                  durationSeconds: parentReply.voiceNoteDurationSeconds,
                  compact: true,
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
              Row(
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
                    const Spacer(),
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
                ],
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
                            onVote: (direction) =>
                                onChildVote(child, direction),
                            onReplyTap: () => onChildReplyTap(child),
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

/// Level 2 Child Reply Node with Horizontal Anchor Indicator and Collapsible state
class _Level2ChildReplyCard extends HookWidget {
  const _Level2ChildReplyCard({
    required this.childReply,
    required this.opAuthorName,
    required this.onVote,
    required this.onReplyTap,
  });

  final ForumReplyEntity childReply;
  final String opAuthorName;
  final void Function(int direction) onVote;
  final VoidCallback onReplyTap;

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
                      '@${childReply.authorName}',
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 12,
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
                  color: colors.surfaceBorder.withAlpha(isDark ? 30 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author Info & Collapse Toggle
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: colors.primary.withAlpha(
                          isDark ? 40 : 25,
                        ),
                        child: Text(
                          childReply.authorName.isNotEmpty
                              ? childReply.authorName[0].toUpperCase()
                              : '?',
                          style: typography.caption.bold.copyWith(
                            fontSize: 9.5,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '@${childReply.authorName}',
                        style: typography.caption.bold.copyWith(
                          color: isAiReply
                              ? colors.syllabotAccent
                              : colors.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                      if (isOp) ...[
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
                            style: TextStyle(
                              color: colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
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
                      const Spacer(),
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
                    Text(
                      childReply.latexContent!,
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],

                  // Voice note if attached
                  if (childReply.voiceNoteUrl != null &&
                      childReply.voiceNoteUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    VoiceNotePlayerWidget(
                      audioUrl: childReply.voiceNoteUrl!,
                      durationSeconds: childReply.voiceNoteDurationSeconds,
                      compact: true,
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
