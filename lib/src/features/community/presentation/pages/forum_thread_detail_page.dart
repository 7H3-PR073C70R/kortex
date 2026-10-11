import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';
import 'package:kortex/src/core/services/media_upload_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_flashcard_sheets.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_composer_actions.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_detail_app_bar.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_edit_sheets.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_header_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_options_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_replies_coordinator.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_replies_river.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_reply_composer_bar.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder_widget.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';

export 'package:kortex/src/features/community/presentation/widgets/forum_thread_replies_river.dart'
    show ForumSortFilter;

/// Detail screen for a specific community forum thread.
///
/// Features the original discussion post, threaded replies river with recursive nesting,
/// inline Socratic AI hints, media upload attachments, and audio voice replies.
@RoutePage()
class ForumThreadDetailPage extends HookWidget {
  const ForumThreadDetailPage({
    required this.post,
    this.highlightReplyId,
    this.onClosePanel,
    this.communityRepository,
    this.userStorageService,
    this.linkSharingService,
    this.mediaUploadService,
    this.streamSyllabotResponseUseCase,
    this.communityHubBloc,
    super.key,
  });

  final ForumPostEntity post;
  final String? highlightReplyId;
  final VoidCallback? onClosePanel;
  final CommunityRepository? communityRepository;
  final UserStorageService? userStorageService;
  final LinkSharingService? linkSharingService;
  final MediaUploadService? mediaUploadService;
  final StreamSyllabotResponseUseCase? streamSyllabotResponseUseCase;
  final CommunityHubBloc? communityHubBloc;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final repo = communityRepository ?? locator<CommunityRepository>();
    final userStorage = userStorageService ?? locator<UserStorageService>();
    final shareService = linkSharingService ?? locator<LinkSharingService>();
    final uploadService = mediaUploadService ??
        (locator.isRegistered<MediaUploadService>()
            ? locator<MediaUploadService>()
            : null);
    final hubBloc = communityHubBloc ??
        (locator.isRegistered<CommunityHubBloc>()
            ? locator<CommunityHubBloc>()
            : null);
    final streamUseCase = streamSyllabotResponseUseCase ??
        (locator.isRegistered<StreamSyllabotResponseUseCase>()
            ? locator<StreamSyllabotResponseUseCase>()
            : null);

    final currentUserId = userStorage.getUserId();
    final currentUserName = userStorage.getUserDisplayName() ?? '';

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

    final coordinator = ForumThreadRepliesCoordinator(
      postId: post.id,
      repository: repo,
      hubBloc: hubBloc,
      streamUseCase: streamUseCase,
      currentPost: currentPost,
      localReplies: localReplies,
      sortFilter: sortFilter,
      topLevelOffset: topLevelOffset,
      isInitialLoadingReplies: isInitialLoadingReplies,
      isLoadingMoreTopLevel: isLoadingMoreTopLevel,
      hasMoreTopLevel: hasMoreTopLevel,
      isGeneratingAiHint: isGeneratingAiHint,
      expandedParentReplyIds: expandedParentReplyIds,
      loadingParentReplyIds: loadingParentReplyIds,
      hasMoreSubRepliesMap: hasMoreSubRepliesMap,
      subReplyOffsets: subReplyOffsets,
    );

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
          (_) => unawaited(coordinator.fetchTopLevelReplies()),
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

            if (treeData.post.isQuestion &&
                treeData.replies.isEmpty &&
                treeData.post.socraticHint == null &&
                !isGeneratingAiHint.value) {
              unawaited(
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (context.mounted &&
                      localReplies.value.isEmpty &&
                      !isGeneratingAiHint.value) {
                    unawaited(coordinator.generateSyllabotHint(context));
                  }
                }),
              );
            }
          },
        );
      }

      StreamSubscription<List<ForumReplyEntity>>? wsSubscription;

      WidgetsBinding.instance.addPostFrameCallback((_) {
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

    useEffect(() {
      unawaited(coordinator.fetchTopLevelReplies());
      return null;
    }, [sortFilter.value]);

    Future<void> toggleSubscription() async {
      isSubscribed.value = !isSubscribed.value;
      final res = await repo.toggleForumPostSubscription(post.id);
      res.fold((_) {}, (serverVal) {
        if (isSubscribed.value != serverVal) {
          isSubscribed.value = serverVal;
        }
      });
    }

    Future<void> toggleBookmark() async {
      isBookmarked.value = !isBookmarked.value;
      if (isBookmarked.value) {
        context.showSnackBar(message: 'Thread saved to bookmarks');
      } else {
        context.showSnackBar(message: 'Thread removed from bookmarks');
      }
      await repo.toggleBookmarkForumPost(post.id);
    }

    void shareThread() {
      unawaited(
        shareService.shareForumPost(
          postId: post.id,
          title: currentPost.value.title,
          authorName: currentPost.value.authorName,
          subjectTrack: currentPost.value.track,
        ),
      );
    }

    Future<void> copyPostLink() async {
      final result = await shareService.shareForumPost(
        postId: post.id,
        title: currentPost.value.title,
        authorName: currentPost.value.authorName,
        subjectTrack: currentPost.value.track,
      );
      final copied = await shareService.copyLinkToClipboard(result.linkUri);
      if (copied && context.mounted) {
        context.showSnackBar(message: 'Post link copied to clipboard');
      }
    }

    Future<void> showEditPostSheet() async {
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

    Future<void> showEditReplySheet(ForumReplyEntity reply) async {
      await ForumThreadEditSheets.showEditReplySheet(
        context,
        reply: reply,
        repository: repo,
        onUpdated: (updated) {
          localReplies.value = localReplies.value.map<ForumReplyEntity>((r) {
            if (r.id == reply.id) {
              return r.copyWith(content: updated.content);
            }
            return r;
          }).toList();
        },
      );
    }

    Future<void> confirmDeleteReply(ForumReplyEntity reply) async {
      await ForumThreadEditSheets.confirmDeleteReply(
        context,
        postId: post.id,
        reply: reply,
        repository: repo,
        onDeleted: () {
          localReplies.value =
              localReplies.value.where((r) => r.id != reply.id).toList();
          currentPost.value = currentPost.value.copyWith(
            repliesCount: math.max(0, currentPost.value.repliesCount - 1),
          );
        },
      );
    }

    final isAuthor = (currentUserId != null &&
            currentUserId == currentPost.value.authorId) ||
        (currentUserName.isNotEmpty &&
            currentUserName.toLowerCase() ==
                currentPost.value.authorName.toLowerCase());

    void showPostOptionsMenu() {
      unawaited(
        ForumThreadOptionsSheet.show(
          context,
          post: currentPost.value,
          isBookmarked: isBookmarked.value,
          isSubscribed: isSubscribed.value,
          isAuthor: isAuthor,
          onToggleBookmark: () => unawaited(toggleBookmark()),
          onToggleSubscription: () => unawaited(toggleSubscription()),
          onShare: shareThread,
          onCopyLink: copyPostLink,
          onEditPost: () => unawaited(showEditPostSheet()),
          onDeletePost: () => unawaited(
            ForumThreadEditSheets.confirmDeletePost(
              context,
              postId: currentPost.value.id,
              repository: repo,
            ),
          ),
          onReport: () {
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
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? colors.backgroundPrimary : colors.surfacePrimary,
      appBar: ForumThreadDetailAppBar(
        postTitle: post.title,
        isSubscribed: isSubscribed.value,
        onToggleSubscription: () => unawaited(toggleSubscription()),
        onReport: () {
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
        onShare: shareThread,
        onClosePanel: onClosePanel,
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
                        coordinator.fetchTopLevelReplies(),
                        () async {
                          final subRes = await repo.isForumPostSubscribed(
                            post.id,
                          );
                          subRes.fold(
                            (_) {},
                            (sub) => isSubscribed.value = sub,
                          );
                          final bookRes =
                              await repo.getBookmarkedForumPostIds();
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
                        // Original Post Card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: ForumThreadHeaderCard(
                              post: currentPost.value,
                              isBookmarked: isBookmarked.value,
                              repliesCount: localReplies.value.length,
                              onVote: coordinator.votePost,
                              onBookmark: () => unawaited(toggleBookmark()),
                              onShare: shareThread,
                              onShowOptionsMenu: showPostOptionsMenu,
                              onTranscriptLoaded: (newTranscript) {
                                currentPost.value = currentPost.value.copyWith(
                                  voiceNoteTranscript: newTranscript,
                                );
                              },
                              onGenerateDeck: () => unawaited(
                                ForumGenerateDeckSheet.show(
                                  context,
                                  post: currentPost.value,
                                  replies: localReplies.value,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Discussion River Section Header
                        ForumThreadRepliesHeaderSliver(
                          repliesCount: localReplies.value.length,
                          sortFilter: sortFilter.value,
                          onSortFilterSelected: (filter) {
                            sortFilter.value = filter;
                          },
                        ),

                        // Replies List
                        ForumThreadRepliesListSliver(
                          allReplies: localReplies.value,
                          sortFilter: sortFilter.value,
                          isInitialLoading: isInitialLoadingReplies.value,
                          isGeneratingAiHint: isGeneratingAiHint.value,
                          currentUserId: currentUserId,
                          isAuthor: isAuthor,
                          isQuestion: currentPost.value.isQuestion,
                          opAuthorName: currentPost.value.authorName,
                          highlightReplyId: highlightReplyId,
                          expandedParentReplyIds: expandedParentReplyIds.value,
                          loadingParentReplyIds: loadingParentReplyIds.value,
                          hasMoreSubRepliesMap: hasMoreSubRepliesMap.value,
                          onToggleExpand: coordinator.toggleSubRepliesExpansion,
                          onLoadMoreChildren: (id) =>
                              coordinator.loadSubRepliesForParent(
                            id,
                            isLoadMore: true,
                          ),
                          onVoteReply: coordinator.voteReply,
                          onReplyTap: (reply) {
                            replyingToReply.value = reply;
                            focusNode.requestFocus();
                          },
                          onSaveFlashcard: (target) => unawaited(
                            ForumSaveFlashcardSheet.show(
                              context,
                              post: currentPost.value,
                              reply: target,
                            ),
                          ),
                          onEditReply: (reply) => unawaited(
                            showEditReplySheet(reply),
                          ),
                          onDeleteReply: (reply) => unawaited(
                            confirmDeleteReply(reply),
                          ),
                          onTranscriptUpdated:
                              (targetReplyId, newTranscript) {
                            localReplies.value = localReplies.value.map((r) {
                              if (r.id == targetReplyId) {
                                return r.copyWith(
                                  voiceNoteTranscript: newTranscript,
                                );
                              }
                              return r;
                            }).toList();
                          },
                          onVerifySolution: (reply) => unawaited(
                            coordinator.verifySolution(context, reply),
                          ),
                          onGenerateAiHint: () => unawaited(
                            coordinator.generateSyllabotHint(context),
                          ),
                        ),

                        // Top-Level Pagination trigger
                        if (hasMoreTopLevel.value)
                          ForumThreadPaginationSliver(
                            isLoadingMore: isLoadingMoreTopLevel.value,
                            onLoadMore: () => unawaited(
                              coordinator.fetchTopLevelReplies(isLoadMore: true),
                            ),
                          ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 24),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Sticky Bottom Quick Reply Bar
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
              onApplyFormat: (prefix, suffix, [placeholder = '']) =>
                  ForumComposerFormatting.applyFormat(
                replyController,
                focusNode,
                prefix,
                suffix,
                placeholder,
              ),
              onInsertSnippet: (snippet) =>
                  ForumComposerFormatting.insertSnippet(
                replyController,
                focusNode,
                snippet,
              ),
              onGenerateAiHint: () => unawaited(
                coordinator.generateSyllabotHint(context),
              ),
              onSubmitReply: () => ForumThreadReplySubmitter.submitReply(
                context: context,
                replyController: replyController,
                replyImages: replyImages,
                replyVoiceNoteUrl: replyVoiceNoteUrl,
                replyVoiceNoteDuration: replyVoiceNoteDuration,
                replyVoiceTranscript: replyVoiceTranscript,
                isAnonymousReply: isAnonymousReply,
                isSubmitting: isSubmitting,
                replyingToReply: replyingToReply,
                localReplies: localReplies,
                expandedParentReplyIds: expandedParentReplyIds,
                currentPost: currentPost.value,
                repository: repo,
                uploadService: uploadService,
                hubBloc: hubBloc,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
