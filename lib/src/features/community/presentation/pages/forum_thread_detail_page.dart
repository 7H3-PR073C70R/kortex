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
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

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
        title: Text(
          post.track,
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        actions: [
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
          const SizedBox(width: 8),
          // Live indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(120),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.liveIndicator,
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    letterSpacing: 1.2,
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
                  // Original Post
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                                    backgroundColor: colors.primary.withAlpha(40),
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
                              // Stack Overflow Post Vote Widget
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
                              currentPost.value.syllabusTag.isNotEmpty) ...[
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
                                        color: colors.syllabotAccent.withAlpha(
                                          80,
                                        ),
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

                          // Title (Cleaned up from redundant prompt duplication)
                          Text(
                            _cleanTitle(currentPost.value.title, currentPost.value.syllabusTag, currentPost.value.track),
                            style: typography.title2.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Structured Content Card
                          _ForumThreadStructuredBody(post: currentPost.value),

                          // LaTeX block
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

                          // Replies header
                          Row(
                            children: [
                              Text(
                                l10n.repliesHeader,
                                style: typography.footnote.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  key: ValueKey(localReplies.value.length),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${localReplies.value.length}',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (localReplies.value.isNotEmpty &&
                                  !localReplies.value.any(
                                    (r) =>
                                        r.authorName
                                            .toLowerCase()
                                            .contains('syllabot') ||
                                        r.content.contains('Syllabot') ||
                                        r.content.contains('🤖') ||
                                        r.content.contains('Socratic Hint'),
                                  ))
                                ShrinkableButton(
                                  onTap: isGeneratingAiHint.value
                                      ? null
                                      : generateSyllabotHint,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.syllabotAccent.withAlpha(
                                        isDark ? 40 : 20,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: colors.syllabotAccent.withAlpha(
                                          80,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isGeneratingAiHint.value)
                                          SizedBox(
                                            width: 12,
                                            height: 12,
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
                                            size: 13,
                                            color: colors.syllabotAccent,
                                          ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isGeneratingAiHint.value
                                              ? 'Thinking...'
                                              : 'AI Socratic Hint 🤖',
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: colors.syllabotAccent,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),

                  // Replies list & Nested Threads
                  Builder(
                    builder: (context) {
                      final allReplies = localReplies.value;
                      // Order top-level replies by netVotes descending (highest upvote first)
                      final topLevelReplies = allReplies
                          .where((r) =>
                              r.parentReplyId == null ||
                              r.parentReplyId!.isEmpty)
                          .toList()
                        ..sort((a, b) {
                          if (a.isVerifiedSolution != b.isVerifiedSolution) {
                            return a.isVerifiedSolution ? -1 : 1;
                          }
                          final voteComp = b.netVotes.compareTo(a.netVotes);
                          if (voteComp != 0) return voteComp;
                          return b.createdAt.compareTo(a.createdAt);
                        });

                      // Group nested replies and sort by date descending (most recent first)
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
                        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
                              vertical: 28,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 36,
                                  color: colors.textSecondary.withAlpha(100),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.noRepliesYet,
                                  style: typography.footnote.medium.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (!hasAiHintInEmpty) ...[
                                  const SizedBox(height: 16),
                                  ShrinkableButton(
                                    onTap: isGeneratingAiHint.value
                                        ? null
                                        : generateSyllabotHint,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    decoration: BoxDecoration(
                                      color: colors.syllabotAccent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.syllabotAccent.withAlpha(
                                            isDark ? 80 : 40,
                                          ),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isGeneratingAiHint.value)
                                          SizedBox(
                                            width: 14,
                                            height: 14,
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
                                              : 'Ask Syllabot for Socratic Hint',
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

            // Active Reply Context Banner (Stack Overflow / Reddit style)
            if (replyingToReply.value != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 30 : 15),
                  border: Border(
                    top: BorderSide(color: colors.primary.withAlpha(40)),
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

            // Bottom reply input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                border: Border(
                  top: BorderSide(color: colors.primary.withAlpha(30)),
                ),
              ),
              child: Row(
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
                            : l10n.writeHelpfulReply,
                        hintStyle: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? colors.surfacePrimary
                            : colors.surfaceSecondary.withAlpha(100),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
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

        // Neutral Question Options List (Never styled as selected or checked)
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
    return LatexRichViewer(
      text: text,
      style: baseStyle,
    );
  }
}

/// Bidirectional vote capsule for post or replies
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
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: (isUpvoted || isDownvoted)
            ? (isUpvoted
                ? colors.primary.withAlpha(isDark ? 35 : 20)
                : colors.error.withAlpha(isDark ? 35 : 20))
            : (isDark
                ? colors.surfaceSecondary
                : colors.surfaceSecondary.withAlpha(120)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isUpvoted || isDownvoted)
              ? (isUpvoted
                  ? colors.primary.withAlpha(120)
                  : colors.error.withAlpha(120))
              : colors.primary.withAlpha(isDark ? 30 : 15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShrinkableButton(
            onTap: onUpvote,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 3,
              ),
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: isUpvoted ? colors.primary : colors.textSecondary,
              ),
            ),
          ),
          Text(
            '$netVotes',
            style: typography.caption.bold.copyWith(
              color: isUpvoted
                  ? colors.primary
                  : isDownvoted
                      ? colors.error
                      : colors.textPrimary,
              fontSize: 12.5,
            ),
          ),
          ShrinkableButton(
            onTap: onDownvote,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 3,
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: isDownvoted ? colors.error : colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stack Overflow style top-level answer card with voting column & nested sub-replies
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

    final isExpanded = useState<bool>(true);
    final isUpvoted = reply.userVote == 1;
    final isDownvoted = reply.userVote == -1;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reply.isVerifiedSolution
              ? colors.recallEasy
              : colors.primary.withAlpha(isDark ? 30 : 15),
          width: reply.isVerifiedSolution ? 1.5 : 1.0,
        ),
        boxShadow: reply.isVerifiedSolution
            ? [
                BoxShadow(
                  color: colors.recallEasy.withAlpha(isDark ? 50 : 25),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Stack Overflow Voting gutter & Accepted solution checkmark
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShrinkableButton(
                      onTap: () => onVote(1),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUpvoted
                              ? colors.primary.withAlpha(30)
                              : colors.transparent,
                        ),
                        child: Icon(
                          Icons.arrow_drop_up_rounded,
                          size: 32,
                          color: isUpvoted
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${reply.netVotes}',
                      style: typography.body.bold.copyWith(
                        color: isUpvoted
                            ? colors.primary
                            : isDownvoted
                                ? colors.error
                                : colors.textPrimary,
                        fontSize: 14.5,
                      ),
                    ),
                    ShrinkableButton(
                      onTap: () => onVote(-1),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDownvoted
                              ? colors.error.withAlpha(30)
                              : colors.transparent,
                        ),
                        child: Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 32,
                          color: isDownvoted
                              ? colors.error
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                    if (reply.isVerifiedSolution) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.recallEasy.withAlpha(30),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: colors.recallEasy,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 12),

                // Right Column: Answer Body, Stack Overflow Author signature card, Actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verified Solution Pill
                      if (reply.isVerifiedSolution)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.recallEasy.withAlpha(isDark ? 40 : 20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.recallEasy),
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
                                'Verified Solution',
                                style: typography.caption.bold.copyWith(
                                  color: colors.recallEasy,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Answer Content
                      _CleanFormattedText(
                        text: reply.content,
                        baseStyle: typography.body.regular.copyWith(
                          color: colors.textPrimary,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                      if (reply.latexContent != null &&
                          reply.latexContent!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          reply.latexContent!,
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Author & Action Bar Row (Stack Overflow layout)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Left actions: Reply + Comments toggle + Mark solution
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ShrinkableButton(
                                onTap: onReplyTap,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(isDark ? 25 : 15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.reply_rounded,
                                        size: 14,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Reply',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.primary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (children.isNotEmpty)
                                ShrinkableButton(
                                  onTap: () {
                                    unawaited(HapticFeedback.selectionClick());
                                    isExpanded.value = !isExpanded.value;
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.surfacePrimary.withAlpha(isDark ? 120 : 80),
                                      borderRadius: BorderRadius.circular(6),
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
                                        const SizedBox(width: 3),
                                        Text(
                                          isExpanded.value
                                              ? 'Hide (${children.length})'
                                              : '💬 ${children.length}',
                                          style: typography.caption.medium.copyWith(
                                            color: colors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (isQuestion &&
                                  !reply.isVerifiedSolution &&
                                  (!hasVerifiedSolution || isAuthor))
                                ShrinkableButton(
                                  onTap: onVerifySolution,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.warning
                                          .withAlpha(isDark ? 40 : 25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: colors.warning.withAlpha(90),
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
                            ],
                          ),

                          // Right author card
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfacePrimary.withAlpha(140)
                                  : colors.surfaceSecondary.withAlpha(120),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor:
                                      reply.authorName.contains('Syllabot')
                                          ? colors.syllabotAccent.withAlpha(50)
                                          : colors.primary.withAlpha(40),
                                  child: Text(
                                    reply.authorName.contains('Syllabot')
                                        ? '🤖'
                                        : (reply.authorName.isNotEmpty
                                            ? reply.authorName[0].toUpperCase()
                                            : '?'),
                                    style: typography.caption.bold.copyWith(
                                      fontSize: reply.authorName.contains('Syllabot')
                                          ? 10
                                          : 9,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      reply.authorName,
                                      style: typography.caption.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'answered ${_formatTime(reply.createdAt, l10n)}',
                                      style: typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
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
          ),

          // Sleek Stack Overflow Nested Comments Section
          if (children.isNotEmpty && isExpanded.value) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: colors.primary.withAlpha(isDark ? 25 : 15),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final child = entry.value;
                  final grandChildren = nestedRepliesMap[child.id] ?? const [];
                  return Column(
                    children: [
                      if (idx > 0)
                        Divider(
                          height: 12,
                          thickness: 0.5,
                          color: colors.primary.withAlpha(isDark ? 20 : 10),
                        ),
                      _ForumNestedReplyItem(
                        childReply: child,
                        children: grandChildren,
                        onVote: (direction) => onChildVote(child, direction),
                        onReplyTap: () => onChildReplyTap(child),
                        onChildVote: onChildVote,
                        onChildReplyTap: onChildReplyTap,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
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

/// Stack Overflow style comment item (Supports Depth 1 and Depth 2 with depth limit of 2)
class _ForumNestedReplyItem extends HookWidget {
  const _ForumNestedReplyItem({
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

    final isExpanded = useState<bool>(true);
    final isUpvoted = childReply.userVote == 1;
    final isDownvoted = childReply.userVote == -1;

    // Hard depth limit of 2: Depth 2 comments CANNOT have a reply button
    final canReply = depth < 2 && onReplyTap != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Author name + timestamp + sleek compact vote pill
          Row(
            children: [
              CircleAvatar(
                radius: 9,
                backgroundColor: childReply.authorName.contains('Syllabot')
                    ? colors.syllabotAccent.withAlpha(50)
                    : colors.primary.withAlpha(35),
                child: Text(
                  childReply.authorName.contains('Syllabot')
                      ? '🤖'
                      : (childReply.authorName.isNotEmpty
                          ? childReply.authorName[0].toUpperCase()
                          : '?'),
                  style: typography.caption.bold.copyWith(
                    fontSize: childReply.authorName.contains('Syllabot') ? 9 : 8,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  childReply.authorName,
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '• ${_formatTime(childReply.createdAt, l10n)}',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 9.5,
                ),
              ),
              const Spacer(),
              // Minimal sleek vote pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: (isUpvoted || isDownvoted)
                      ? (isUpvoted
                          ? colors.primary.withAlpha(isDark ? 35 : 20)
                          : colors.error.withAlpha(isDark ? 35 : 20))
                      : colors.surfacePrimary.withAlpha(isDark ? 100 : 60),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShrinkableButton(
                      onTap: () => onVote(1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 15,
                          color: isUpvoted ? colors.primary : colors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${childReply.netVotes}',
                      style: typography.caption.bold.copyWith(
                        color: isUpvoted
                            ? colors.primary
                            : isDownvoted
                                ? colors.error
                                : colors.textPrimary,
                        fontSize: 10.5,
                      ),
                    ),
                    ShrinkableButton(
                      onTap: () => onVote(-1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 15,
                          color: isDownvoted ? colors.error : colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Comment body
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  const SizedBox(height: 3),
                  Text(
                    childReply.latexContent!,
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 4),

                // Action buttons: Reply + Sub-comments toggle
                Row(
                  children: [
                    if (canReply)
                      ShrinkableButton(
                        onTap: onReplyTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              size: 13,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Reply',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (canReply && children.isNotEmpty)
                      const SizedBox(width: 12),
                    if (children.isNotEmpty)
                      ShrinkableButton(
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          isExpanded.value = !isExpanded.value;
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpanded.value
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 13,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              isExpanded.value
                                  ? 'Hide'
                                  : '${children.length} ${children.length == 1 ? 'reply' : 'replies'}',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 10,
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

          // Grandchildren comments list (Depth 2) with elegant left thread guide line
          if (children.isNotEmpty && isExpanded.value && depth < 2) ...[
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.only(left: 14),
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: colors.primary.withAlpha(isDark ? 45 : 25),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final grandChild = entry.value;
                  return Column(
                    children: [
                      if (idx > 0)
                        Divider(
                          height: 10,
                          thickness: 0.5,
                          color: colors.primary.withAlpha(isDark ? 20 : 10),
                        ),
                      _ForumNestedReplyItem(
                        childReply: grandChild,
                        depth: 2,
                        onVote: (direction) {
                          if (onChildVote != null) {
                            onChildVote!(grandChild, direction);
                          } else {
                            onVote(direction);
                          }
                        },
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
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
