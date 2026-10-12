import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';

/// Content preview section for TrackForumPostCard displaying the post title,
/// sanitized markdown/text snippet via [LatexRichViewer], and optional [LatexFormulaBlock].
class PostCardContentPreview extends StatelessWidget {
  const PostCardContentPreview({
    required this.post,
    super.key,
  });

  final ForumPostEntity post;

  String _extractSnippet(String content) {
    var snippet = content;
    if (snippet.contains('**Question:**')) {
      final parts = snippet.split('**Question:**');
      if (parts.length > 1) snippet = parts[1];
    } else if (snippet.startsWith('Question:')) {
      snippet = snippet.substring(9);
    }
    if (snippet.contains('**Options:**')) {
      snippet = snippet.split('**Options:**').first;
    } else if (snippet.contains('Options:')) {
      snippet = snippet.split('Options:').first;
    }
    snippet = snippet.trim();
    return snippet.isEmpty ? content : snippet;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final snippet = _extractSnippet(post.content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post Title
        Text(
          post.title,
          style: typography.body.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 15.5,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),

        // Post Content Preview / Rich Viewer
        LatexRichViewer(
          text: snippet,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: typography.footnote.regular.copyWith(
            color: colors.textSecondary,
            height: 1.45,
          ),
        ),

        // Optional Rich Formula Callout
        if (post.latexContent != null &&
            post.latexContent!.isNotEmpty) ...[
          const SizedBox(height: 10),
          LatexFormulaBlock(
            formula: post.latexContent!,
            backgroundColor: isDark
                ? colors.surfacePrimary.withAlpha(160)
                : colors.surfaceSecondary.withAlpha(100),
            borderColor: colors.surfaceBorder.withAlpha(
              isDark ? 30 : 20,
            ),
            textStyle: typography.body.bold.copyWith(
              color: colors.primary,
              fontSize: 13.5,
            ),
          ),
        ],
      ],
    );
  }
}
