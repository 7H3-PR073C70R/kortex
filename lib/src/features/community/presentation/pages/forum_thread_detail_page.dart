import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/l10n/l10n.dart';
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
        title: Text(
          post.track,
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        actions: [
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
          ),
          onPressed: () => unawaited(context.router.maybePop()),
        ),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.authorName,
                                    style: typography.footnote.bold.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _formatTime(post.createdAt, l10n),
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

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
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfaceSecondary
                                    : colors.surfaceSecondary.withAlpha(100),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.white,
                              ),
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
