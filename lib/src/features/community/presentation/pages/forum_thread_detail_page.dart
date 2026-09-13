import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
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
    final isSubmitting = useState<bool>(false);
    final isGeneratingAiHint = useState<bool>(false);
    final localReplies = useState<List<ForumReplyEntity>>(post.replies);

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

    // Intelligent Syllabot Socratic Hint generator
    Future<void> generateSyllabotHint() async {
      if (isGeneratingAiHint.value) return;
      isGeneratingAiHint.value = true;
      unawaited(HapticFeedback.mediumImpact());
      try {
        final promptBuffer = StringBuffer()
          ..writeln('You are Syllabot, an expert academic tutor.')
          ..writeln(
            'A student in track "${post.track}" (Subject/Syllabus: "${post.syllabusTag}") posted this question:',
          )
          ..writeln('Question Title: "${post.title}"');
        if (post.content.trim().isNotEmpty) {
          promptBuffer.writeln('Question Details: "${post.content}"');
        }
        if (post.latexContent != null && post.latexContent!.trim().isNotEmpty) {
          promptBuffer.writeln('Formulas / LaTeX: ${post.latexContent}');
        }
        promptBuffer
          ..writeln()
          ..writeln(
            'Provide a high-yield, step-by-step Socratic hint and conceptual breakdown. '
            'Do NOT provide the final direct answer or multiple-choice option immediately. '
            'Instead, provide:\n'
            '1. 💡 Core Governing Principles (the exact physical law, formula, or definition involved)\n'
            '2. 🔍 Step-by-Step Problem Breakdown & Variables to isolate\n'
            '3. 🎯 Socratic Checkpoint question to test their understanding.',
          );

        final isPro = !locator.isRegistered<SubscriptionGuard>() ||
            locator<SubscriptionGuard>().canAccessCloudAi();
        final preferredEngine = isPro
            ? ExecutionEngineType.cloudRemote
            : ExecutionEngineType.localOnDevice;

        var generatedHint = '';
        if (locator.isRegistered<StreamSyllabotResponseUseCase>()) {
          try {
            final streamUseCase = locator<StreamSyllabotResponseUseCase>();
            final responseStream = streamUseCase.call(
              prompt: promptBuffer.toString(),
              sessionId: 'forum_hint_${post.id}',
              socraticMode: SocraticMode.stepByStep,
              preferredEngine: preferredEngine,
            );

            final tokenBuffer = StringBuffer();
            await responseStream
                .timeout(
                  const Duration(seconds: 15),
                  onTimeout: (sink) => sink.close(),
                )
                .forEach(tokenBuffer.write);
            generatedHint = tokenBuffer.toString().trim();
          } on Object catch (e) {
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
                      'Provide a high-yield Socratic hint for this question.',
                )
                .forEach(localBuffer.write);
            generatedHint = localBuffer.toString().trim();
          } on Object catch (e) {
            debugPrint('[ForumHint] Local LLM note: $e');
          }
        }

        // Clean formatting and prefix
        final cleanHint = generatedHint.isNotEmpty
            ? (generatedHint.startsWith('🤖 Syllabot')
                ? generatedHint
                : '🤖 Syllabot Socratic Hint:\n\n$generatedHint')
            : '🤖 Syllabot Socratic Hint:\n\n'
                '### 💡 Core Governing Principles:\n'
                'Review the fundamental theorems and formulas governing ${post.syllabusTag}.\n\n'
                '### 🔍 Step-by-Step Problem Breakdown:\n'
                '• Extract the known variables and the target unknown from the problem statement.\n'
                '• Relate the parameters using conservation laws or standard kinematic/algebraic formulas.\n\n'
                '### 🎯 Socratic Checkpoint:\n'
                'How does changing the primary input variable affect the magnitude of the final result?';

        final res = await repo.replyToForumPost(
          postId: post.id,
          content: cleanHint,
        );
        res.fold(
          (failure) {
            if (context.mounted) {
              context.showSnackBar(
                message: failure.message ?? 'Could not generate AI hint.',
                type: SnackBarType.error,
              );
            }
          },
          (reply) {
            if (!localReplies.value.any((r) => r.id == reply.id)) {
              localReplies.value = [...localReplies.value, reply];
            }
          },
        );
      } finally {
        isGeneratingAiHint.value = false;
      }
    }

    final replies = localReplies.value;

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
                          // Author row
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: colors.primary.withAlpha(40),
                                child: Text(
                                  post.authorName.isNotEmpty
                                      ? post.authorName[0].toUpperCase()
                                      : '?',
                                  style: typography.footnote.bold.copyWith(
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.authorName,
                                      style: typography.footnote.bold.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _formatTime(post.createdAt, l10n),
                                      style: typography.caption.regular
                                          .copyWith(
                                            color: colors.textSecondary,
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

                          // Badges Row (Question Bounty, Syllabus Module, Solved Status)
                          if (post.isQuestion ||
                              post.syllabusTag.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (post.isQuestion)
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
                                        const Text(
                                          '❓',
                                          style: TextStyle(fontSize: 12),
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
                                if (post.syllabusTag.isNotEmpty)
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
                                        const Text(
                                          '📚',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          post.syllabusTag,
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: colors.syllabotAccent,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (post.isVerifiedSolution ||
                                    replies.any((r) => r.isVerifiedSolution))
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
                            _cleanTitle(post.title, post.syllabusTag, post.track),
                            style: typography.title2.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Structured Content Card
                          _ForumThreadStructuredBody(post: post),

                          // LaTeX block
                          if (post.latexContent != null &&
                              post.latexContent!.isNotEmpty) ...[
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
                                    post.latexContent!,
                                    style: typography.body.bold.copyWith(
                                      color: colors.primary,
                                      fontFamily: 'monospace',
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
                                  key: ValueKey(replies.length),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${replies.length}',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (replies.isNotEmpty)
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
                                          const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
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

                  // Replies list
                  if (replies.isEmpty)
                    SliverToBoxAdapter(
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
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isGeneratingAiHint.value
                                          ? 'Consulting Syllabot...'
                                          : 'Ask Syllabot for Socratic Hint',
                                      style: typography.caption.bold.copyWith(
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final reply = replies[index];
                          final hasVerifiedSolution = replies.any(
                            (r) => r.isVerifiedSolution,
                          );
                          final userStorage = locator<UserStorageService>();
                          final currentUserId = userStorage.getUserId();
                          final isAuthor =
                              currentUserId == null ||
                              currentUserId == post.authorId;

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfaceSecondary
                                    : colors.surfaceSecondary.withAlpha(100),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: reply.isVerifiedSolution
                                      ? colors.recallEasy
                                      : colors.primary.withAlpha(
                                          isDark ? 30 : 15,
                                        ),
                                  width: reply.isVerifiedSolution ? 1.5 : 1.0,
                                ),
                                boxShadow: reply.isVerifiedSolution
                                    ? [
                                        BoxShadow(
                                          color: colors.recallEasy.withAlpha(
                                            isDark ? 50 : 25,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Verified Solution Notice Badge
                                  if (reply.isVerifiedSolution)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.recallEasy.withAlpha(
                                          isDark ? 40 : 20,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: colors.recallEasy,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 14,
                                            color: colors.recallEasy,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Verified Solution',
                                            style: typography.caption.bold
                                                .copyWith(
                                                  color: colors.recallEasy,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Reply Author Row
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor:
                                            reply.authorName.contains('Syllabot')
                                                ? colors.syllabotAccent.withAlpha(
                                                    50,
                                                  )
                                                : colors.primary.withAlpha(40),
                                        child: Text(
                                          reply.authorName.contains('Syllabot')
                                              ? '🤖'
                                              : (reply.authorName.isNotEmpty
                                                  ? reply.authorName[0]
                                                      .toUpperCase()
                                                  : '?'),
                                          style: TextStyle(
                                            fontSize:
                                                reply.authorName.contains(
                                                      'Syllabot',
                                                    )
                                                    ? 12
                                                    : 11,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              reply.authorName,
                                              style: typography.footnote.bold
                                                  .copyWith(
                                                    color: colors.textPrimary,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              _formatTime(
                                                reply.createdAt,
                                                l10n,
                                              ),
                                              style: typography.caption.regular
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                    fontSize: 10,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Reply Body rendered without markdown asterisks
                                  _CleanFormattedText(
                                    text: reply.content,
                                    baseStyle: typography.body.regular.copyWith(
                                      color: colors.textSecondary,
                                      height: 1.5,
                                      fontSize: 13.5,
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

                                  // Mark as Verified Solution Button (Post Author action on questions)
                                  if (post.isQuestion &&
                                      !reply.isVerifiedSolution &&
                                      (!hasVerifiedSolution || isAuthor)) ...[
                                    const SizedBox(height: 10),
                                    ShrinkableButton(
                                      onTap: () async {
                                        final res = await repo.verifyForumReply(
                                          postId: post.id,
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
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.warning.withAlpha(
                                            isDark ? 40 : 25,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: colors.warning.withAlpha(90),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.verified_outlined,
                                              size: 13,
                                              color: colors.warning,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Mark as Solution (+100 XP)',
                                              style: typography.caption.bold
                                                  .copyWith(
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
                            ),
                          );
                        },
                        childCount: replies.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
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
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.writeHelpfulReply,
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
                            isSubmitting.value = true;
                            final res = await repo.replyToForumPost(
                              postId: post.id,
                              content: text,
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
                                if (!localReplies.value.any(
                                  (r) => r.id == createdReply.id,
                                )) {
                                  localReplies.value = [
                                    ...localReplies.value,
                                    createdReply,
                                  ];
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
  }
  if (cleaned.length > 90) {
    if (syllabusTag.isNotEmpty) {
      return '$syllabusTag ($track) Question Breakdown';
    }
    return '${cleaned.substring(0, 87)}...';
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

    final optionRegex = RegExp(r'^([A-Da-d0-9][\.\:\)]|\([A-Da-d0-9]\))\s*(.*)');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final lower = line.toLowerCase();
      if (lower.startsWith('options:') || lower.startsWith('choices:')) {
        readingOptions = true;
        readingExplanation = false;
        continue;
      }
      if (lower.startsWith('explanation:') || lower.startsWith('solution:') || lower.startsWith('why is this correct?')) {
        readingExplanation = true;
        readingOptions = false;
        final colonIdx = line.indexOf(':');
        if (colonIdx != -1 && colonIdx < line.length - 1) {
          final contentAfter = line.substring(colonIdx + 1).trim();
          if (contentAfter.isNotEmpty) {
            explanationLines.add(contentAfter);
          }
        }
        continue;
      }
      if (lower.startsWith('correct answer:') || lower.startsWith('correct:')) {
        final colonIdx = line.indexOf(':');
        correctAnswer = colonIdx != -1 ? line.substring(colonIdx + 1).trim() : line;
        continue;
      }
      if (lower.startsWith('your answer:') || lower.startsWith('selected answer:') || lower.startsWith('user answer:')) {
        final colonIdx = line.indexOf(':');
        userAnswer = colonIdx != -1 ? line.substring(colonIdx + 1).trim() : line;
        continue;
      }

      if (readingExplanation) {
        explanationLines.add(line);
      } else if (optionRegex.hasMatch(line)) {
        options.add(line);
        readingOptions = true;
      } else if (readingOptions) {
        // If it was already reading options and starts with a letter, add to options
        if (RegExp('^[A-Da-d]').hasMatch(line)) {
          options.add(line);
        } else {
          readingOptions = false;
          promptLines.add(line);
        }
      } else {
        promptLines.add(line);
      }
    }

    final promptText = promptLines.join('\n').trim();
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
                color: colors.primary.withAlpha(25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(25),
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
                  baseStyle: typography.body.regular.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

        // Options List (if structured)
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
          ...options.map((opt) {
            var letter = '';
            var optText = opt;
            final match = optionRegex.firstMatch(opt);
            if (match != null) {
              letter = match.group(1)?.replaceAll(RegExp(r'[\(\)\.\:\s]'), '') ?? '';
              optText = match.group(2) ?? opt;
            }

            final isCorrect = correctAnswer != null &&
                (correctAnswer.toLowerCase().contains(optText.toLowerCase()) ||
                    (letter.isNotEmpty && correctAnswer.toUpperCase().contains(letter.toUpperCase())));

            final isUserSelected = userAnswer != null &&
                (userAnswer.toLowerCase().contains(optText.toLowerCase()) ||
                    (letter.isNotEmpty && userAnswer.toUpperCase().contains(letter.toUpperCase())));

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCorrect
                    ? colors.success.withAlpha(20)
                    : isUserSelected
                        ? colors.error.withAlpha(20)
                        : (isDark ? colors.surfaceSecondary : colors.surfacePrimary),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect
                      ? colors.success.withAlpha(100)
                      : isUserSelected
                          ? colors.error.withAlpha(100)
                          : colors.primary.withAlpha(20),
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
                        color: isCorrect
                            ? colors.success
                            : isUserSelected
                                ? colors.error
                                : colors.primary.withAlpha(30),
                      ),
                      child: Text(
                        letter.toUpperCase(),
                        style: typography.caption.bold.copyWith(
                          color: (isCorrect || isUserSelected)
                              ? colors.white
                              : colors.primary,
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
                      ),
                    ),
                  ),
                  if (isCorrect)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: colors.success,
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
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.primary.withAlpha(20),
              ),
            ),
            child: Row(
              children: [
                if (correctAnswer != null) ...[
                  Icon(Icons.check_circle_outline, size: 16, color: colors.success),
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

        // Explanation Card
        if (explanationText.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withAlpha(50),
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
                    height: 1.45,
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
    // Parse **bold** markdown tokens into rich text spans without showing raw asterisks
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.*?)\*\*|__(.*?)__');
    var lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }
      final boldContent = match.group(1) ?? match.group(2) ?? '';
      spans.add(
        TextSpan(
          text: boldContent,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: baseStyle,
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }
}
