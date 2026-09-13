import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Available sorting modes for forum replies
enum ForumSortFilter {
  mostRecent('Most Recent', Icons.schedule_rounded),
  topVoted('Top Voted', Icons.trending_up_rounded),
  aiFirst('AI Solution First', Icons.auto_awesome_rounded),
  unanswered('Unanswered', Icons.help_outline_rounded);

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
    final sortFilter = useState<ForumSortFilter>(ForumSortFilter.mostRecent);
    final currentPost = useState<ForumPostEntity>(post);
    final localReplies = useState<List<ForumReplyEntity>>(post.replies);
    final replyingToReply = useState<ForumReplyEntity?>(null);

    // Real-time replies stream — seeded with initial replies from the post
    final repo = locator<CommunityRepository>();
    final repliesStream = useMemoized(
      () => repo.watchForumReplies(post.id),
      [post.id],
    );
    final repliesSnapshot = useStream(repliesStream, initialData: post.replies);

    useEffect(() {
      if (repliesSnapshot.hasData && repliesSnapshot.data != null) {
        localReplies.value = repliesSnapshot.data!;
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

    // Quick text insertion helper for the composer (LaTeX, AI, Code block)
    void insertIntoComposer(String snippet) {
      final text = replyController.text;
      final selection = replyController.selection;
      if (selection.isValid && selection.start >= 0) {
        final newText = text.replaceRange(selection.start, selection.end, snippet);
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

    // Intelligent Syllabot Socratic Hint generator
    Future<void> generateSyllabotHint() async {
      if (isGeneratingAiHint.value) return;
      isGeneratingAiHint.value = true;
      unawaited(HapticFeedback.mediumImpact());
      try {
        final promptBuffer = StringBuffer()
          ..writeln('You are Syllabot, an elite academic AI tutor with deep subject mastery across STEM and Humanities.')
          ..writeln('A student in "${post.track}" (${post.syllabusTag.isNotEmpty ? post.syllabusTag : post.track}) needs a high-yield conceptual hint for this question:')
          ..writeln()
          ..writeln('Question Title: "${post.title}"');
        if (post.content.trim().isNotEmpty) {
          promptBuffer.writeln('Question Content:\n${post.content}');
        }
        if (post.latexContent != null && post.latexContent!.trim().isNotEmpty) {
          promptBuffer.writeln('Formulas / Equations:\n${post.latexContent}');
        }
        promptBuffer
          ..writeln()
          ..writeln(
            'Provide an authentic, highly insightful Socratic hint tailored specifically to the exact subject matter of this question:\n\n'
            '1. 💡 **Core Subject Principle**: Explain the specific biological, chemical, physical, mathematical, or academic concept/definition involved in direct, engaging terms. Do NOT cite generic physical formulas for non-physics questions.\n'
            '2. 🔍 **Concept Breakdown & Distinctions**: Analyze the specific structures, variables, mechanisms, or options mentioned in the problem, highlighting key differences or common student misconceptions.\n'
            '3. 🎯 **Socratic Checkpoint**: A sharp, thought-provoking guiding question that empowers the student to deduce the correct answer themselves.\n\n'
            'Ensure the response is concise, sharp, pedagogically brilliant, and free from repetitive filler.',
          );

        final isPro = !locator.isRegistered<SubscriptionGuard>() ||
            locator<SubscriptionGuard>().canAccessCloudAi();
        final preferredEngine = isPro
            ? ExecutionEngineType.cloudRemote
            : ExecutionEngineType.localOnDevice;

        String? aiErrorMessage;
        var generatedHint = '';
        if (locator.isRegistered<StreamSyllabotResponseUseCase>()) {
          try {
            final streamUseCase = locator<StreamSyllabotResponseUseCase>();
            final responseStream = streamUseCase.call(
              prompt: promptBuffer.toString(),
              sessionId: UuidUtils.isValidUuid(post.id)
                  ? post.id
                  : UuidUtils.generate(),
              socraticMode: SocraticMode.stepByStep,
              preferredEngine: preferredEngine,
            );

            final tokenBuffer = StringBuffer();
            await responseStream
                .timeout(
                  const Duration(seconds: 20),
                  onTimeout: (sink) => sink.close(),
                )
                .forEach(tokenBuffer.write);
            generatedHint = tokenBuffer.toString().trim();
          } on Object catch (e) {
            aiErrorMessage = e.toString();
            debugPrint('[ForumHint] Stream AI note: $e');
          }
        }

        if (generatedHint.isEmpty &&
            locator.isRegistered<LocalLlmEngineClient>()) {
          try {
            final localLlm = locator<LocalLlmEngineClient>();
            final localBuffer = StringBuffer();
            await localLlm
                .generate(
                  prompt: promptBuffer.toString(),
                  systemInstruction:
                      'You are Syllabot, an expert academic tutor. Provide an insightful, subject-specific Socratic hint.',
                )
                .forEach(localBuffer.write);
            generatedHint = localBuffer.toString().trim();
          } on Object catch (e) {
            aiErrorMessage ??= e.toString();
            debugPrint('[ForumHint] Local LLM note: $e');
          }
        }

        if (generatedHint.trim().isEmpty) {
          if (context.mounted) {
            final isNotDownloaded = aiErrorMessage != null &&
                (aiErrorMessage.contains('LocalLlmNotDownloadedException') ||
                 aiErrorMessage.contains('On-device neural engine is not downloaded') ||
                 aiErrorMessage.contains('248MB model weights') ||
                 aiErrorMessage.contains('248 MB model weights'));

            if (isNotDownloaded) {
              context.showModelDownloadSnackBar(
                onDownloadComplete: () {
                  unawaited(generateSyllabotHint());
                },
              );
            } else {
              context.showSnackBar(
                message: aiErrorMessage != null
                    ? 'Could not generate Syllabot hint: $aiErrorMessage'
                    : 'Unable to generate Syllabot AI hint. Please check your internet connection.',
                type: SnackBarType.error,
              );
            }
          }
          return;
        }

        // Clean formatting and remove any degenerate repetition loops
        var cleanHint = generatedHint.replaceAll(
          RegExp(r'[\uFFFD\u0000-\u0008\u000B\u000C\u000E-\u001F]+'),
          '',
        );
        final lines = cleanHint.split('\n');
        final deduplicatedLines = <String>[];
        String? previousLine;
        var repeatCount = 0;
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed == previousLine && trimmed.isNotEmpty) {
            repeatCount++;
            if (repeatCount < 2) {
              deduplicatedLines.add(line);
            }
          } else {
            repeatCount = 0;
            previousLine = trimmed;
            deduplicatedLines.add(line);
          }
        }
        cleanHint = deduplicatedLines.join('\n').trim();

        final finalHintContent = cleanHint.startsWith('🤖 Syllabot')
            ? cleanHint
            : '🤖 Syllabot Socratic Hint:\n\n$cleanHint';

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
      } finally {
        isGeneratingAiHint.value = false;
      }
    }

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
          ),
          onPressed: () => unawaited(context.router.maybePop()),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              post.track,
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            if (post.syllabusTag.isNotEmpty)
              Text(
                post.syllabusTag,
                style: typography.caption.medium.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        actions: [
          // Subscribe / Follow Thread toggle
          IconButton(
            icon: Icon(
              isSubscribed.value
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: isSubscribed.value ? colors.primary : colors.textSecondary,
              size: 22,
            ),
            tooltip: isSubscribed.value ? 'Unsubscribe' : 'Subscribe to thread',
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              isSubscribed.value = !isSubscribed.value;
              context.showSnackBar(
                message: isSubscribed.value
                    ? 'Subscribed to thread notifications'
                    : 'Unsubscribed from thread notifications',
              );
            },
          ),
          // Report Discussion
          IconButton(
            icon: Icon(
              Icons.flag_outlined,
              color: colors.textSecondary,
              size: 20,
            ),
            tooltip: 'Report Discussion',
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
          // Live indicator
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.liveIndicator,
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Main Question Card & Post Hero
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Author row & Post Upvote/Downvote Capsule
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: colors.primary.withAlpha(isDark ? 50 : 35),
                                    child: Text(
                                      currentPost.value.authorName.isNotEmpty
                                          ? currentPost.value.authorName[0].toUpperCase()
                                          : '?',
                                      style: typography.footnote.bold.copyWith(
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentPost.value.authorName,
                                        style: typography.footnote.bold.copyWith(
                                          color: colors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _formatTime(currentPost.value.createdAt, l10n),
                                        style: typography.caption.regular.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Stack Overflow Post Vote Capsule
                              _ForumVoteCapsule(
                                netVotes: currentPost.value.netVotes,
                                userVote: currentPost.value.userVote,
                                onUpvote: () => votePost(1),
                                onDownvote: () => votePost(-1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Badges Row (Question Bounty, Syllabus Module, Solved Status)
                          if (currentPost.value.isQuestion ||
                              currentPost.value.syllabusTag.isNotEmpty ||
                              currentPost.value.isVerifiedSolution ||
                              localReplies.value.any((r) => r.isVerifiedSolution)) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (currentPost.value.isQuestion)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.warning.withAlpha(
                                        isDark ? 40 : 25,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: colors.warning.withAlpha(90),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '❓',
                                          style: typography.caption.medium.copyWith(fontSize: 12),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Peer Question Bounty • +100 XP',
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: colors.warning,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (currentPost.value.syllabusTag.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.syllabotAccent.withAlpha(
                                        isDark ? 35 : 20,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: colors.syllabotAccent.withAlpha(80),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '📚',
                                          style: typography.caption.medium.copyWith(fontSize: 11),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          currentPost.value.syllabusTag,
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: colors.syllabotAccent,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (currentPost.value.isVerifiedSolution ||
                                    localReplies.value.any((r) => r.isVerifiedSolution))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.recallEasy.withAlpha(
                                        isDark ? 40 : 25,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: colors.recallEasy,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 12,
                                          color: colors.recallEasy,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Solved',
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: colors.recallEasy,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Title
                          Text(
                            _cleanTitle(currentPost.value.title, currentPost.value.syllabusTag, currentPost.value.track),
                            style: typography.title2.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Structured Content Body Card
                          _ForumThreadStructuredBody(post: currentPost.value),

                          // LaTeX Formula block
                          if (currentPost.value.latexContent != null &&
                              currentPost.value.latexContent!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfaceSecondary
                                    : colors.surfaceSecondary.withAlpha(150),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.primary.withAlpha(40),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.formulaEquation,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    currentPost.value.latexContent!,
                                    style: typography.body.bold.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Discussion / Comments Header (matching Images 1, 2, 3)
                          Row(
                            children: [
                              Text(
                                'Discussion',
                                style: typography.headline.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  key: ValueKey(localReplies.value.length),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(isDark ? 40 : 25),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colors.primary.withAlpha(isDark ? 60 : 35),
                                    ),
                                  ),
                                  child: Text(
                                    '${localReplies.value.length}',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Sort & Filter Dropdown Pill
                              PopupMenuButton<ForumSortFilter>(
                                initialValue: sortFilter.value,
                                tooltip: 'Sort Replies',
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: colors.primary.withAlpha(isDark ? 40 : 20),
                                  ),
                                ),
                                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                                onSelected: (filter) {
                                  unawaited(HapticFeedback.selectionClick());
                                  sortFilter.value = filter;
                                },
                                itemBuilder: (context) => ForumSortFilter.values.map((f) {
                                  final isSelected = f == sortFilter.value;
                                  return PopupMenuItem<ForumSortFilter>(
                                    value: f,
                                    child: Row(
                                      children: [
                                        Icon(
                                          f.icon,
                                          size: 16,
                                          color: isSelected ? colors.primary : colors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          f.label,
                                          style: typography.footnote.medium.copyWith(
                                            color: isSelected ? colors.primary : colors.textPrimary,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                                        ? colors.surfaceSecondary
                                        : colors.surfaceSecondary.withAlpha(120),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: colors.primary.withAlpha(isDark ? 30 : 15),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        sortFilter.value.icon,
                                        size: 13,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        sortFilter.value.label,
                                        style: typography.caption.bold.copyWith(
                                          color: colors.textPrimary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 14,
                                        color: colors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // Replies list & Threaded Branch Trees
                  Builder(
                    builder: (context) {
                      final allReplies = localReplies.value;

                      // Filter & sort top-level replies based on selected filter
                      final topLevelReplies = (allReplies
                          .where((r) =>
                              r.parentReplyId == null ||
                              r.parentReplyId!.isEmpty)
                          .toList())
                        ..sort((a, b) {
                          // Keep verified solutions pinned to the top
                          if (a.isVerifiedSolution != b.isVerifiedSolution) {
                            return a.isVerifiedSolution ? -1 : 1;
                          }

                          switch (sortFilter.value) {
                            case ForumSortFilter.mostRecent:
                              return b.createdAt.compareTo(a.createdAt);
                            case ForumSortFilter.topVoted:
                              final voteComp = b.netVotes.compareTo(a.netVotes);
                              if (voteComp != 0) return voteComp;
                              return b.createdAt.compareTo(a.createdAt);
                            case ForumSortFilter.aiFirst:
                              final aIsAi = a.authorName.toLowerCase().contains('syllabot') || a.content.contains('🤖');
                              final bIsAi = b.authorName.toLowerCase().contains('syllabot') || b.content.contains('🤖');
                              if (aIsAi != bIsAi) return aIsAi ? -1 : 1;
                              return b.netVotes.compareTo(a.netVotes);
                            case ForumSortFilter.unanswered:
                              final aHasChildren = allReplies.any((r) => r.parentReplyId == a.id);
                              final bHasChildren = allReplies.any((r) => r.parentReplyId == b.id);
                              if (aHasChildren != bHasChildren) return aHasChildren ? 1 : -1;
                              return b.createdAt.compareTo(a.createdAt);
                          }
                        });

                      // Group nested replies
                      final nestedRepliesMap = <String, List<ForumReplyEntity>>{};
                      for (final reply in allReplies) {
                        if (reply.parentReplyId != null &&
                            reply.parentReplyId!.isNotEmpty) {
                          nestedRepliesMap
                              .putIfAbsent(reply.parentReplyId!, () => [])
                              .add(reply);
                        }
                      }
                      for (final list in nestedRepliesMap.values) {
                        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                      }

                      final hasAiHintInEmpty = allReplies.any(
                        (r) =>
                            r.authorName.toLowerCase().contains('syllabot') ||
                            r.content.contains('Syllabot') ||
                            r.content.contains('🤖') ||
                            r.content.contains('Socratic Hint'),
                      );

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
                                    color: colors.primary.withAlpha(isDark ? 25 : 15),
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
                                  style: typography.caption.regular.copyWith(
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
                                        borderRadius: BorderRadius.circular(12),
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
                                                    AlwaysStoppedAnimation<Color>(
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
                                            style: typography.caption.bold.copyWith(
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
                            final children = nestedRepliesMap[reply.id] ?? const [];
                            final hasVerifiedSolution = allReplies.any(
                              (r) => r.isVerifiedSolution,
                            );
                            final userStorage = locator<UserStorageService>();
                            final currentUserId = userStorage.getUserId();
                            final isAuthor =
                                currentUserId == null ||
                                currentUserId == currentPost.value.authorId;

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: _ForumAnswerCard(
                                reply: reply,
                                children: children,
                                nestedRepliesMap: nestedRepliesMap,
                                isQuestion: currentPost.value.isQuestion,
                                isAuthor: isAuthor,
                                hasVerifiedSolution: hasVerifiedSolution,
                                onVote: (direction) => voteReply(reply, direction),
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
                                          message: failure.message ?? 'Failed to verify solution',
                                          type: SnackBarType.error,
                                        );
                                      }
                                    },
                                    (_) {
                                      localReplies.value = localReplies.value
                                          .map(
                                            (r) => r.id == reply.id
                                                ? r.copyWith(isVerifiedSolution: true)
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

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),

            // Active Reply Context Banner (Replying to @...)
            if (replyingToReply.value != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 35 : 15),
                  border: Border(
                    top: BorderSide(color: colors.primary.withAlpha(50)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.reply_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Replying to @${replyingToReply.value!.authorName}',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ShrinkableButton(
                      onTap: () => replyingToReply.value = null,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Rich Academic Bottom Composer Bar (Images 1, 2, 3)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                border: Border(
                  top: BorderSide(color: colors.primary.withAlpha(isDark ? 20 : 12)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick Tools Strip (LaTeX, AI Socratic, Code Block, Emoji/Formula shortcuts)
                  Row(
                    children: [
                      // LaTeX Formula Picker
                      _ComposerToolButton(
                        icon: Icons.functions_rounded,
                        tooltip: 'Insert Formula',
                        label: '√x',
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          _showLatexSnippetDialog(context, insertIntoComposer);
                        },
                      ),
                      const SizedBox(width: 6),
                      // Syllabot AI Assist
                      _ComposerToolButton(
                        icon: Icons.auto_awesome_rounded,
                        tooltip: 'Ask AI for Socratic Hint',
                        label: 'AI Hint',
                        accentColor: colors.syllabotAccent,
                        onTap: isGeneratingAiHint.value ? null : generateSyllabotHint,
                      ),
                      const SizedBox(width: 6),
                      // Markdown Code Block
                      _ComposerToolButton(
                        icon: Icons.code_rounded,
                        tooltip: 'Code Block',
                        label: '</>',
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          insertIntoComposer('\n```\n// Code or equation here\n```\n');
                        },
                      ),
                      const SizedBox(width: 6),
                      // Key Formula symbol quick picker (Δ, θ, π)
                      _ComposerToolButton(
                        icon: Icons.emoji_symbols_rounded,
                        tooltip: 'Insert Math Symbol',
                        label: 'π / θ',
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          _showMathSymbolDialog(context, insertIntoComposer);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Input Row & Send Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: replyController,
                          focusNode: focusNode,
                          maxLines: 5,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: replyingToReply.value != null
                                ? 'Reply to @${replyingToReply.value!.authorName}...'
                                : 'Share your solution or answer...',
                            hintStyle: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? colors.surfacePrimary
                                : colors.surfaceSecondary.withAlpha(120),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ShrinkableButton(
                        onTap: isSubmitting.value
                            ? null
                            : () async {
                                final text = replyController.text.trim();
                                if (text.isEmpty) return;
                                final targetParentId = replyingToReply.value?.id;
                                isSubmitting.value = true;
                                final res = await repo.replyToForumPost(
                                  postId: currentPost.value.id,
                                  content: text,
                                  parentReplyId: targetParentId,
                                );
                                isSubmitting.value = false;
                                res.fold(
                                  (failure) {
                                    if (context.mounted) {
                                      context.showSnackBar(
                                        message:
                                            failure.message ?? failure.toString(),
                                        type: SnackBarType.error,
                                      );
                                    }
                                  },
                                  (createdReply) {
                                    replyController.clear();
                                    replyingToReply.value = null;
                                    if (!localReplies.value.any(
                                      (r) => r.id == createdReply.id,
                                    )) {
                                      localReplies.value = [
                                        ...localReplies.value,
                                        createdReply,
                                      ];
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
                              },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                          ),
                          child: isSubmitting.value
                              ? AppLogoLoader(
                                  size: 18,
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
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLatexSnippetDialog(BuildContext context, void Function(String snippet) onInsert) {
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
      {'label': 'Matrix 2x2', 'snippet': r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}'},
    ];

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 30 : 15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.primary.withAlpha(50)),
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

  void _showMathSymbolDialog(BuildContext context, void Function(String symbol) onInsert) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final symbols = [
      'π', 'θ', 'Δ', 'α', 'β', 'γ', 'λ', 'μ', 'σ', 'ω',
      '≈', '≠', '≤', '≥', '±', '×', '÷', '∞', '√', '∫',
    ];

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
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
                          border: Border.all(color: colors.primary.withAlpha(40)),
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

/// Helper button for composer tool strip
class _ComposerToolButton extends StatelessWidget {
  const _ComposerToolButton({
    required this.icon,
    required this.tooltip,
    required this.label,
    this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String tooltip;
  final String label;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final tint = accentColor ?? colors.primary;

    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tint.withAlpha(isDark ? 30 : 15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: tint.withAlpha(isDark ? 60 : 35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: tint,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: tint,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
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

    final optionPrefixRegex =
        RegExp(r'^([A-Da-d0-9][\.\:\)]|\([A-Da-d0-9]\)|[\•\-\*])\s*(.*)');
    final letterPrefixRegex =
        RegExp(r'^([A-Da-d0-9][\.\:\)]|\([A-Da-d0-9]\))\s*(.*)');

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
          final contentAfter =
              line.substring(colonIdx + 1).replaceAll('*', '').trim();
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
          final after =
              line.substring(colonIdx + 1).replaceAll('*', '').trim();
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary
                  : colors.surfaceSecondary.withAlpha(120),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 40 : 25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'QUESTION PROMPT',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _CleanFormattedText(
                  text: promptText,
                  baseStyle: typography.body.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

        // Neutral Question Options List
        if (options.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Options',
            style: typography.caption.bold.copyWith(
              color: colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            var letter = '';
            var optText = opt;

            final letterMatch = letterPrefixRegex.firstMatch(opt);
            if (letterMatch != null) {
              letter = letterMatch
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
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary
                    : colors.surfaceSecondary.withAlpha(120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 30 : 15),
                ),
              ),
              child: Row(
                children: [
                  if (letter.isNotEmpty) ...[
                    Container(
                      width: 26,
                      height: 26,
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
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _CleanFormattedText(
                      text: optText,
                      baseStyle: typography.footnote.regular.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        height: 1.4,
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 30 : 20),
              ),
            ),
            child: Row(
              children: [
                if (correctAnswer != null) ...[
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: colors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _CleanFormattedText(
                      text: 'Correct: $correctAnswer',
                      baseStyle: typography.caption.bold.copyWith(
                        color: colors.success,
                      ),
                    ),
                  ),
                ],
                if (userAnswer != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CleanFormattedText(
                      text: 'Selected: $userAnswer',
                      baseStyle: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
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
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 25 : 15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 60 : 40),
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
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Concept Explanation',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CleanFormattedText(
                  text: explanationText,
                  baseStyle: typography.footnote.regular.copyWith(
                    color: colors.textPrimary,
                    height: 1.5,
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
    // Sanitize any corrupt unicode replacement chars or stray non-printable control chars
    var sanitized = text.replaceAll(
      RegExp(r'[\uFFFD\u0000-\u0008\u000B\u000C\u000E-\u001F]+'),
      '',
    );
    // Clean up any double/triple question prefixes
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

/// Matte bidirectional vote capsule for post hero
class _ForumVoteCapsule extends StatelessWidget {
  const _ForumVoteCapsule({
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
      height: 32,
      decoration: BoxDecoration(
        color: (isUpvoted || isDownvoted)
            ? (isUpvoted
                ? colors.primary.withAlpha(isDark ? 30 : 18)
                : colors.error.withAlpha(isDark ? 30 : 18))
            : (isDark
                ? colors.surfacePrimary.withAlpha(180)
                : colors.surfaceSecondary.withAlpha(120)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isUpvoted || isDownvoted)
              ? (isUpvoted
                  ? colors.primary.withAlpha(80)
                  : colors.error.withAlpha(80))
              : colors.primary.withAlpha(isDark ? 25 : 12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShrinkableButton(
            onTap: onUpvote,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 8,
                right: 4,
                top: 4,
                bottom: 4,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 16,
                color: isUpvoted ? colors.primary : colors.textSecondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$netVotes',
              style: typography.caption.bold.copyWith(
                color: isUpvoted
                    ? colors.primary
                    : isDownvoted
                        ? colors.error
                        : colors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          ShrinkableButton(
            onTap: onDownvote,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 4,
                right: 8,
                top: 4,
                bottom: 4,
              ),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: isDownvoted ? colors.error : colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clean Reddit-style top-level discussion comment node (Directly on UI canvas, matte, borderless)
class _ForumAnswerCard extends HookWidget {
  const _ForumAnswerCard({
    required this.reply,
    required this.children,
    required this.nestedRepliesMap,
    required this.isQuestion,
    required this.isAuthor,
    required this.hasVerifiedSolution,
    required this.onVote,
    required this.onChildVote,
    required this.onReplyTap,
    required this.onChildReplyTap,
    required this.onVerifySolution,
  });

  final ForumReplyEntity reply;
  final List<ForumReplyEntity> children;
  final Map<String, List<ForumReplyEntity>> nestedRepliesMap;
  final bool isQuestion;
  final bool isAuthor;
  final bool hasVerifiedSolution;
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

    // Sub-replies are hidden by default
    final isExpanded = useState<bool>(false);
    // Sub-replies pagination (3 at a time)
    final visibleChildCount = useState<int>(3);

    final isUpvoted = reply.userVote == 1;
    final isDownvoted = reply.userVote == -1;

    final isAiReply = reply.authorName.toLowerCase().contains('syllabot') ||
        reply.content.contains('🤖') ||
        reply.content.contains('Syllabot Socratic Hint');

    final pagedChildren = children.take(visibleChildCount.value).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Avatar, Username, Flairs, Relative Time
          Row(
            children: [
              if (isAiReply)
                ClipOval(
                  child: Image(
                    image: AppAssets.images.syllabotAvatar.provider(),
                    width: 22,
                    height: 22,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.syllabotAccent.withAlpha(isDark ? 40 : 25),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.smart_toy_rounded,
                        size: 13,
                        color: colors.syllabotAccent,
                      ),
                    ),
                  ),
                )
              else
                CircleAvatar(
                  radius: 11,
                  backgroundColor: colors.primary.withAlpha(isDark ? 35 : 20),
                  child: Text(
                    reply.authorName.isNotEmpty
                        ? reply.authorName[0].toUpperCase()
                        : '?',
                    style: typography.caption.bold.copyWith(
                      fontSize: 10,
                      color: colors.primary,
                    ),
                  ),
                ),
              const SizedBox(width: 8),

              // Author Username (Distinct font style from body text)
              Flexible(
                child: Text(
                  'u/${reply.authorName}',
                  style: typography.caption.bold.copyWith(
                    color: isAiReply
                        ? colors.syllabotAccent
                        : colors.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Badges (AI TUTOR / OP / Verified)
              if (isAiReply) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.syllabotAccent.withAlpha(isDark ? 30 : 20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AI TUTOR',
                    style: typography.caption.bold.copyWith(
                      color: colors.syllabotAccent,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],

              if (reply.isVerifiedSolution) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.success.withAlpha(isDark ? 30 : 20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 10,
                        color: colors.success,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'SOLVED',
                        style: typography.caption.bold.copyWith(
                          color: colors.success,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(width: 6),
              Text(
                '• ${_formatTime(reply.createdAt, l10n)}',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary.withAlpha(180),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Comment Body (Placed directly on UI canvas)
          _CleanFormattedText(
            text: reply.content,
            baseStyle: typography.footnote.regular.copyWith(
              color: colors.textPrimary,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
          if (reply.latexContent != null &&
              reply.latexContent!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(120)
                    : colors.surfaceSecondary.withAlpha(80),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                reply.latexContent!,
                style: typography.caption.bold.copyWith(
                  color: colors.primary,
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Reddit-style Matte Action Bar (Using Wrap to prevent any horizontal overflow)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Bidirectional Vote Pill
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: (isUpvoted || isDownvoted)
                      ? (isUpvoted
                          ? colors.primary.withAlpha(isDark ? 30 : 18)
                          : colors.error.withAlpha(isDark ? 30 : 18))
                      : (isDark
                          ? colors.surfaceSecondary.withAlpha(140)
                          : colors.surfaceSecondary.withAlpha(90)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShrinkableButton(
                      onTap: () => onVote(1),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 6,
                          right: 3,
                          top: 3,
                          bottom: 3,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 14,
                          color: isUpvoted
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        '${reply.netVotes}',
                        style: typography.caption.bold.copyWith(
                          color: isUpvoted
                              ? colors.primary
                              : isDownvoted
                                  ? colors.error
                                  : colors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    ShrinkableButton(
                      onTap: () => onVote(-1),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 3,
                          right: 6,
                          top: 3,
                          bottom: 3,
                        ),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: isDownvoted
                              ? colors.error
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Reply Button
              ShrinkableButton(
                onTap: onReplyTap,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(140)
                        : colors.surfaceSecondary.withAlpha(90),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: 13,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
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
              ),

              // Mark as Verified Solution (Author only)
              if (isQuestion &&
                  !reply.isVerifiedSolution &&
                  (!hasVerifiedSolution || isAuthor))
                ShrinkableButton(
                  onTap: onVerifySolution,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: colors.warning.withAlpha(isDark ? 30 : 18),
                      borderRadius: BorderRadius.circular(14),
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
                          'Mark Solution (+100 XP)',
                          style: typography.caption.bold.copyWith(
                            color: colors.warning,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Collapse / Unhide toggle if has children (Hidden by default)
              if (children.isNotEmpty)
                ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    isExpanded.value = !isExpanded.value;
                  },
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(140)
                          : colors.surfaceSecondary.withAlpha(90),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isExpanded.value
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isExpanded.value
                              ? 'Hide replies'
                              : '${children.length} ${children.length == 1 ? 'reply' : 'replies'}',
                          style: typography.caption.medium.copyWith(
                            color: colors.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Threaded Nested Replies Tree with continuous left threadline and pagination
          if (children.isNotEmpty && isExpanded.value)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...pagedChildren.map((child) {
                    final grandChildren = nestedRepliesMap[child.id] ?? const [];
                    return _ThreadedReplyTree(
                      childReply: child,
                      children: grandChildren,
                      onVote: (direction) => onChildVote(child, direction),
                      onReplyTap: () => onChildReplyTap(child),
                      onChildVote: onChildVote,
                      onChildReplyTap: onChildReplyTap,
                    );
                  }),

                  // Pagination "Show more replies" button
                  if (children.length > visibleChildCount.value)
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 6, bottom: 4),
                      child: ShrinkableButton(
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          visibleChildCount.value += 5;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 13,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Show ${children.length - visibleChildCount.value} more ${children.length - visibleChildCount.value == 1 ? 'reply' : 'replies'}',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
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

          // Subtle divider separating top-level replies on the UI canvas
          const SizedBox(height: 10),
          Divider(
            height: 16,
            thickness: 0.6,
            color: colors.surfaceBorder.withAlpha(isDark ? 35 : 20),
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

/// Borderless nested reply item placed directly on the UI canvas with Likes instead of votes
class _ThreadedReplyTree extends HookWidget {
  const _ThreadedReplyTree({
    required this.childReply,
    required this.onVote,
    this.children = const [],
    this.depth = 1,
    this.onReplyTap,
    this.onChildVote,
    this.onChildReplyTap,
  });

  final ForumReplyEntity childReply;
  final List<ForumReplyEntity> children;
  final int depth;
  final void Function(int direction) onVote;
  final VoidCallback? onReplyTap;
  final void Function(ForumReplyEntity child, int direction)? onChildVote;
  final void Function(ForumReplyEntity child)? onChildReplyTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    // Sub-sub replies are hidden by default
    final isExpanded = useState<bool>(false);
    final isLiked = childReply.userVote == 1;

    final isAiReply = childReply.authorName.toLowerCase().contains('syllabot') ||
        childReply.content.contains('🤖');

    final canReply = depth < 2 && onReplyTap != null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Continuous Thread Connector Guide Line
            SizedBox(
              width: 16,
              child: CustomPaint(
                painter: _BranchLinePainter(
                  lineColor: colors.primary.withAlpha(isDark ? 40 : 25),
                  hasChildren: children.isNotEmpty && isExpanded.value,
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Borderless sub-comment placed directly on the UI canvas
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author Header Row & Timestamp
                    Row(
                      children: [
                        if (isAiReply)
                          ClipOval(
                            child: Image(
                              image: AppAssets.images.syllabotAvatar.provider(),
                              width: 18,
                              height: 18,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.syllabotAccent.withAlpha(isDark ? 40 : 25),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.smart_toy_rounded,
                                  size: 11,
                                  color: colors.syllabotAccent,
                                ),
                              ),
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: colors.primary.withAlpha(isDark ? 35 : 20),
                            child: Text(
                              childReply.authorName.isNotEmpty
                                  ? childReply.authorName[0].toUpperCase()
                                  : '?',
                              style: typography.caption.bold.copyWith(
                                fontSize: 8,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),

                        // Author Name (Distinct styling from body)
                        Flexible(
                          child: Text(
                            'u/${childReply.authorName}',
                            style: typography.caption.bold.copyWith(
                              color: isAiReply
                                  ? colors.syllabotAccent
                                  : colors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${_formatTime(childReply.createdAt, l10n)}',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary.withAlpha(180),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Comment Body (Directly on canvas)
                    _CleanFormattedText(
                      text: childReply.content,
                      baseStyle: typography.footnote.regular.copyWith(
                        color: colors.textPrimary,
                        height: 1.4,
                        fontSize: 12.5,
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
                    const SizedBox(height: 6),

                    // Actions: Likes instead of upvote/downvote + Reply + Collapse
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Heart / Like Button for Sub-Replies
                        ShrinkableButton(
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            onVote(isLiked ? 0 : 1);
                          },
                          child: Container(
                            height: 24,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            decoration: BoxDecoration(
                              color: isLiked
                                  ? colors.error.withAlpha(isDark ? 30 : 18)
                                  : (isDark
                                      ? colors.surfaceSecondary.withAlpha(120)
                                      : colors.surfaceSecondary.withAlpha(80)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 12,
                                  color: isLiked
                                      ? colors.error
                                      : colors.textSecondary,
                                ),
                                if (childReply.upvotes > 0) ...[
                                  const SizedBox(width: 3),
                                  Text(
                                    '${childReply.upvotes}',
                                    style: typography.caption.bold.copyWith(
                                      color: isLiked
                                          ? colors.error
                                          : colors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Reply Button
                        if (canReply)
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
                                const SizedBox(width: 2),
                                Text(
                                  'Reply',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Toggle for Sub-Sub-Replies (Hidden by default)
                        if (children.isNotEmpty)
                          ShrinkableButton(
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              isExpanded.value = !isExpanded.value;
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                isExpanded.value
                                    ? 'Hide'
                                    : '+${children.length} ${children.length == 1 ? 'reply' : 'replies'}',
                                style: typography.caption.bold.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Grandchildren branch (Depth 2)
                    if (children.isNotEmpty && isExpanded.value && depth < 2) ...[
                      const SizedBox(height: 6),
                      Column(
                        children: children.map((grandChild) {
                          return _ThreadedReplyTree(
                            childReply: grandChild,
                            depth: 2,
                            onVote: (direction) {
                              if (onChildVote != null) {
                                onChildVote!(grandChild, direction);
                              } else {
                                onVote(direction);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
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

/// Custom painter for clean, non-glowing branch connector lines
class _BranchLinePainter extends CustomPainter {
  const _BranchLinePainter({
    required this.lineColor,
    required this.hasChildren,
  });

  final Color lineColor;
  final bool hasChildren;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startX = size.width * 0.4;
    const startY = 0.0;
    final curveEndX = size.width;
    const midY = 14.0;

    // Draw smooth L-curved branch into comment
    final path = Path()
      ..moveTo(startX, startY)
      ..lineTo(startX, midY - 4)
      ..quadraticBezierTo(startX, midY, startX + 4, midY)
      ..lineTo(curveEndX, midY);

    canvas.drawPath(path, paint);

    // If there are sub-children, continue line downwards
    if (hasChildren) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BranchLinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.hasChildren != hasChildren;
  }
}
