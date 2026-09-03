import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
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
    final isDark = context.isDarkMode;

    final replyController = useTextEditingController();
    final replies = useState<List<ForumReplyEntity>>(post.replies);

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          post.track,
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author & Date
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: colors.primary.withAlpha(40),
                          child: Text(
                            post.authorName[0],
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
                              'Posted today',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Thread Title
                    Text(
                      post.title,
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Thread Content
                    Text(
                      post.content,
                      style: typography.body.regular.copyWith(
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),

                    // LaTeX Math Block if present
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
                              'FORMULA / EQUATION',
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
                    const SizedBox(height: 28),

                    // Replies Header
                    Text(
                      'Replies (${replies.value.length})',
                      style: typography.footnote.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Replies List
                    if (replies.value.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No replies yet. Be the first to share an answer!',
                            style: typography.footnote.medium.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...replies.value.map(
                        (reply) => Container(
                          margin: const EdgeInsets.only(bottom: 14),
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
                                    backgroundColor: colors.primary.withAlpha(
                                      30,
                                    ),
                                    child: Text(
                                      reply.authorName[0],
                                      style: typography.caption.bold.copyWith(
                                        color: colors.primary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    reply.authorName,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                reply.content,
                                style: typography.footnote.regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Reply Bar
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
                      decoration: InputDecoration(
                        hintText: 'Write a helpful reply...',
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
                    onTap: () {
                      final text = replyController.text.trim();
                      if (text.isEmpty) return;
                      final newReply = ForumReplyEntity(
                        id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
                        postId: post.id,
                        authorId: 'me',
                        authorName: 'You',
                        content: text,
                        createdAt: DateTime.now(),
                      );
                      replies.value = [...replies.value, newReply];
                      replyController.clear();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
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
}
