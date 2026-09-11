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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Thread reported for community safety moderation.',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: colors.surfaceSecondary,
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
                                      style: typography.caption.regular.copyWith(
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
                          if (post.isQuestion || post.syllabusTag.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (post.isQuestion)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colors.warning.withAlpha(isDark ? 40 : 25),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: colors.warning.withAlpha(90)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('❓', style: TextStyle(fontSize: 12)),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Peer Question Bounty • +100 XP',
                                          style: typography.caption.bold.copyWith(
                                            color: colors.warning,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (post.syllabusTag.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colors.syllabotAccent.withAlpha(isDark ? 35 : 20),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: colors.syllabotAccent.withAlpha(80)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('📚', style: TextStyle(fontSize: 11)),
                                        const SizedBox(width: 4),
                                        Text(
                                          post.syllabusTag,
                                          style: typography.caption.bold.copyWith(
                                            color: colors.syllabotAccent,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (post.isVerifiedSolution || replies.any((r) => r.isVerifiedSolution))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colors.recallEasy.withAlpha(isDark ? 40 : 25),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: colors.recallEasy),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 12, color: colors.recallEasy),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Solved',
                                          style: typography.caption.bold.copyWith(
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
                            post.title,
                            style: typography.title2.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Content
                          Text(
                            post.content,
                            style: typography.body.regular.copyWith(
                              color: colors.textSecondary,
                              height: 1.6,
                            ),
                          ),

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
                          vertical: 32,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 40,
                              color: colors.textSecondary.withAlpha(100),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noRepliesYet,
                              style: typography.footnote.medium.copyWith(
                                color: colors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
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
                          final hasVerifiedSolution = replies.any((r) => r.isVerifiedSolution);
                          final userStorage = locator<UserStorageService>();
                          final currentUserId = userStorage.getUserId();
                          final isAuthor = currentUserId == null || currentUserId == post.authorId;

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
                                  // Verified Solution Notice Badge
                                  if (reply.isVerifiedSolution)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.recallEasy.withAlpha(isDark ? 40 : 20),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: colors.recallEasy),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 14,
                                            color: colors.recallEasy,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Verified Solution • 100 XP Bounty Awarded',
                                            style: typography.caption.bold.copyWith(
                                              color: colors.recallEasy,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor:
                                            colors.primary.withAlpha(30),
                                        child: Text(
                                          reply.authorName.isNotEmpty
                                              ? reply.authorName[0].toUpperCase()
                                              : '?',
                                          style: typography.caption.bold.copyWith(
                                            color: colors.primary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          reply.authorName,
                                          style: typography.caption.bold.copyWith(
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatTime(reply.createdAt, l10n),
                                        style: typography.caption.regular.copyWith(
                                          color: colors.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    reply.content,
                                    style: typography.footnote.regular.copyWith(
                                      color: colors.textSecondary,
                                      height: 1.5,
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
                                  if (post.isQuestion && !reply.isVerifiedSolution && (!hasVerifiedSolution || isAuthor)) ...[
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
                                                message: failure.message ??
                                                    'Failed to verify solution',
                                                type: SnackBarType.error,
                                              );
                                            }
                                          },
                                          (_) {
                                            localReplies.value = localReplies.value.map(
                                              (r) => r.id == reply.id
                                                  ? r.copyWith(isVerifiedSolution: true)
                                                  : r,
                                            ).toList();
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
                                          color: colors.warning.withAlpha(isDark ? 40 : 25),
                                          borderRadius: BorderRadius.circular(8),
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
                                    message: failure.message ??
                                        failure.toString(),
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
