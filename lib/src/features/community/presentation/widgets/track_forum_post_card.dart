import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_media_attachment_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_player_widget.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:share_plus/share_plus.dart';

class TrackForumPostCard extends HookWidget {
  const TrackForumPostCard({
    required this.post,
    required this.onTap,
    this.onUpvoteTap,
    this.onDownvoteTap,
    super.key,
  });

  final ForumPostEntity post;
  final VoidCallback onTap;
  final VoidCallback? onUpvoteTap;
  final VoidCallback? onDownvoteTap;

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showPostOptionsMenu(BuildContext context) {
    unawaited(HapticFeedback.lightImpact());
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.dialog)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withAlpha(80),
                          borderRadius: AppRadius.radiusMicro,
                        ),
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
                      unawaited(
                        SharePlus.instance.share(
                          ShareParams(
                            text:
                                'Check out this forum discussion: ${post.title}\n\n${post.content}',
                          ),
                        ),
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
                  ListTile(
                    leading: Icon(
                      Icons.flag_outlined,
                      color: colors.error,
                    ),
                    title: Text(
                      'Report Content',
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
                  if (() {
                    final userStorage = locator.isRegistered<UserStorageService>()
                        ? locator<UserStorageService>()
                        : null;
                    final currentUserId = userStorage?.getUserId();
                    final currentUserName = userStorage?.getUserDisplayName();
                    return (currentUserId != null && currentUserId == post.authorId) ||
                        (currentUserName != null && currentUserName == post.authorName);
                  }())
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
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text('Delete Discussion?', style: typography.title3.bold.copyWith(color: colors.textPrimary)),
                            content: Text(
                              'Are you sure you want to permanently delete this discussion thread and all its replies?',
                              style: typography.body.regular.copyWith(color: colors.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(false),
                                child: Text('Cancel', style: typography.body.medium.copyWith(color: colors.textSecondary)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.error,
                                  foregroundColor: colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => Navigator.of(dialogCtx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          if (locator.isRegistered<CommunityHubBloc>()) {
                            locator<CommunityHubBloc>().add(DeleteForumPostEvent(post.id));
                          }
                          if (context.mounted) {
                            context.showSnackBar(message: 'Discussion deleted successfully');
                          }
                        }
                      },
                    ),
                  Builder(
                    builder: (innerCtx) {
                      final currentUserId = locator<UserStorageService>().getUserId();
                      final isAuthor = currentUserId != null &&
                          currentUserId.trim().isNotEmpty &&
                          currentUserId.trim() == post.authorId.trim();

                      if (!isAuthor) return const SizedBox.shrink();

                      return ListTile(
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: colors.error,
                        ),
                        title: Text(
                          'Delete Discussion',
                          style: typography.body.bold.copyWith(
                            color: colors.error,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _confirmDeletePost(context);
                        },
                      );
                    },
                  ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeletePost(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusDialog),
          title: Text(
            'Delete Discussion?',
            style: typography.headline.bold.copyWith(color: colors.textPrimary),
          ),
          content: Text(
            'Are you sure you want to delete "${post.title}"? This action cannot be undone and all replies will be removed.',
            style: typography.body.regular.copyWith(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Cancel',
                style: typography.body.medium.copyWith(color: colors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusBadge),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                context.read<CommunityHubBloc>().add(DeleteForumPostEvent(post.id));
                context.showSnackBar(message: 'Discussion deleted');
              },
              child: Text(
                'Delete',
                style: typography.body.bold.copyWith(color: colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isUpvoted = post.userVote == 1;
    final isDownvoted = post.userVote == -1;

    final semanticsLabel =
        'Forum Post: ${post.title}, Track: ${post.track}, '
        'By ${post.authorName}, Score: ${post.netVotes}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) => AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: AppRadius.radiusPanel,
            border: Border.all(
              color: post.isVerifiedSolution
                  ? colors.success.withAlpha(isDark ? (isHovered ? 120 : 60) : (isHovered ? 80 : 40))
                  : isHovered
                      ? colors.primary.withAlpha(isDark ? 80 : 60)
                      : (isDark
                          ? colors.surfaceBorder.withAlpha(30)
                          : colors.surfaceBorder.withAlpha(15)),
              width: isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(isDark ? (isHovered ? 50 : 25) : (isHovered ? 16 : 6)),
                blurRadius: isHovered ? 14 : 8,
                offset: Offset(0, isHovered ? 4 : 2),
              ),
            ],
          ),
          child: Material(
            color: colors.transparent,
            borderRadius: AppRadius.radiusPanel,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.radiusPanel,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel & Options Header: [Dot + c/Track] ... [more_horiz]
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                            const SizedBox(width: 6),
                            Text(
                              'c/${post.track}',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (post.isVerifiedSolution)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.success.withAlpha(isDark ? 35 : 20),
                                  borderRadius: AppRadius.radiusMicro,
                                  border: Border.all(
                                    color: colors.success.withAlpha(isDark ? 70 : 40),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 11,
                                      color: colors.success,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Solved',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.success,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            PlatformHoverBuilder(
                              builder: (context, isMoreHovered, child) => AnimatedContainer(
                                duration: AppMotion.snappy,
                                curve: AppMotion.easeOutCubic,
                                decoration: BoxDecoration(
                                  color: isMoreHovered
                                      ? colors.surfaceBorder.withAlpha(isDark ? 40 : 25)
                                      : colors.transparent,
                                  borderRadius: AppRadius.radiusMicro,
                                ),
                                child: ShrinkableButton(
                                  onTap: () => _showPostOptionsMenu(context),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.more_horiz_rounded,
                                      size: 20,
                                      color: isMoreHovered ? colors.textPrimary : colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Author Row: [Avatar with online ring] [Name] [PRO/MOD badge] • [Time]
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: colors.primary.withAlpha(isDark ? 50 : 30),
                              child: Text(
                                post.authorName.isNotEmpty
                                    ? post.authorName[0].toUpperCase()
                                    : 'U',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -1,
                              right: -1,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.success,
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
                        const SizedBox(width: 10),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '@${post.authorName}',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (post.isQuestion) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.warning.withAlpha(isDark ? 35 : 20),
                                    borderRadius: AppRadius.radiusMicro,
                                  ),
                                  child: Text(
                                    '+100 XP',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.warning,
                                      fontSize: 9.5,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              Text(
                                '•',
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatTime(post.createdAt),
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

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
                    Builder(
                      builder: (context) {
                        var snippet = post.content;
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
                        if (snippet.isEmpty) snippet = post.content;

                        return LatexRichViewer(
                          text: snippet,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                            height: 1.45,
                          ),
                        );
                      },
                    ),

                    // Optional Rich Preview Callout (e.g. Formula or Interactive element)
                    if (post.latexContent != null &&
                        post.latexContent!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfacePrimary.withAlpha(160)
                              : colors.surfaceSecondary.withAlpha(100),
                          borderRadius: AppRadius.radiusCard,
                          border: Border.all(
                            color: colors.surfaceBorder.withAlpha(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(20),
                                borderRadius: AppRadius.radiusMicro,
                              ),
                              child: Icon(
                                Icons.functions_rounded,
                                size: 16,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                post.latexContent!,
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceElevated.withAlpha(120),
                                borderRadius: AppRadius.radiusMicro,
                              ),
                              child: Text(
                                'LaTeX',
                                style: typography.caption.bold.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Voice note player preview if present
                    if (post.voiceNoteUrl != null &&
                        post.voiceNoteUrl!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      VoiceNotePlayerWidget(
                        audioUrl: post.voiceNoteUrl!,
                        durationSeconds: post.voiceNoteDurationSeconds,
                        compact: true,
                      ),
                    ],

                    // Image attachments preview if present
                    if (post.mediaUrls.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ForumPostMediaPreview(
                        mediaUrls: post.mediaUrls,
                        heroHeight: 140,
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Tags Row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfacePrimary.withAlpha(160)
                                : colors.surfaceSecondary.withAlpha(120),
                            borderRadius: AppRadius.radiusBadge,
                          ),
                          child: Text(
                            '#${post.track.toLowerCase()}',
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (post.syllabusTag.isNotEmpty &&
                            post.syllabusTag != 'General')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfacePrimary.withAlpha(160)
                                  : colors.surfaceSecondary.withAlpha(120),
                              borderRadius: AppRadius.radiusBadge,
                            ),
                            child: Text(
                              '#${post.syllabusTag.replaceAll(' ', '').toLowerCase()}',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (post.tags.isNotEmpty)
                          ...post.tags.map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfacePrimary.withAlpha(160)
                                    : colors.surfaceSecondary.withAlpha(120),
                                borderRadius: AppRadius.radiusBadge,
                              ),
                              child: Text(
                                tag.startsWith('#') ? tag.toLowerCase() : '#${tag.toLowerCase()}',
                                style: typography.caption.medium.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        if (post.isQuestion)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfacePrimary.withAlpha(160)
                                  : colors.surfaceSecondary.withAlpha(120),
                              borderRadius: AppRadius.radiusBadge,
                            ),
                            child: Text(
                              '#question',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Actions Bar: [Vote Capsule] [Reply Pill] ... [Share] [Bookmark]
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left actions: Votes & Replies
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Upvote / Downvote Capsule
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: (isUpvoted || isDownvoted)
                                    ? (isUpvoted
                                        ? colors.primary.withAlpha(isDark ? 35 : 20)
                                        : colors.error.withAlpha(isDark ? 35 : 20))
                                    : (isDark
                                        ? colors.surfacePrimary.withAlpha(180)
                                        : colors.surfaceSecondary.withAlpha(120)),
                                borderRadius: AppRadius.radiusBadge,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ShrinkableButton(
                                    onTap: onUpvoteTap == null
                                        ? null
                                        : () {
                                            unawaited(HapticFeedback.selectionClick());
                                            onUpvoteTap!();
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      child: Icon(
                                        Icons.keyboard_arrow_up_rounded,
                                        size: 18,
                                        color: isUpvoted
                                            ? colors.primary
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: Text(
                                      '${post.netVotes}',
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
                                    onTap: onDownvoteTap == null
                                        ? null
                                        : () {
                                            unawaited(HapticFeedback.selectionClick());
                                            onDownvoteTap!();
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: isDownvoted
                                            ? colors.error
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Reply Pill
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfacePrimary.withAlpha(180)
                                    : colors.surfaceSecondary.withAlpha(120),
                                borderRadius: AppRadius.radiusBadge,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 14,
                                    color: colors.textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    post.topLevelRepliesCount == 1
                                        ? '1 reply'
                                        : '${post.topLevelRepliesCount} replies',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Right actions: Share & Bookmark
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PlatformHoverBuilder(
                              builder: (context, isShareHovered, child) => AnimatedContainer(
                                duration: AppMotion.snappy,
                                curve: AppMotion.easeOutCubic,
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isShareHovered
                                      ? colors.primary.withAlpha(isDark ? 40 : 25)
                                      : colors.transparent,
                                  borderRadius: AppRadius.radiusMicro,
                                ),
                                child: ShrinkableButton(
                                  onTap: () {
                                    unawaited(HapticFeedback.lightImpact());
                                    unawaited(
                                      SharePlus.instance.share(
                                        ShareParams(
                                          text:
                                              'Check out this forum discussion: ${post.title}\n\n${post.content}',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Center(
                                    child: Icon(
                                      Icons.ios_share_rounded,
                                      size: 18,
                                      color: isShareHovered ? colors.primary : colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Builder(
                              builder: (context) {
                                final hubBloc = context.watch<CommunityHubBloc?>();
                                final isBookmarked = hubBloc?.state.bookmarkedPostIds.contains(post.id) ?? false;
                                return PlatformHoverBuilder(
                                  builder: (context, isBmHovered, child) => AnimatedContainer(
                                    duration: AppMotion.snappy,
                                    curve: AppMotion.easeOutCubic,
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isBmHovered
                                          ? colors.primary.withAlpha(isDark ? 40 : 25)
                                          : colors.transparent,
                                      borderRadius: AppRadius.radiusMicro,
                                    ),
                                    child: ShrinkableButton(
                                      onTap: () async {
                                        unawaited(HapticFeedback.lightImpact());
                                        if (hubBloc != null) {
                                          hubBloc.add(ToggleBookmarkForumPostEvent(post.id));
                                        } else {
                                          final repo = locator<CommunityRepository>();
                                          await repo.toggleBookmarkForumPost(post.id);
                                        }
                                        final newBookmarked = !isBookmarked;
                                        if (context.mounted) {
                                          context.showSnackBar(
                                            message: newBookmarked
                                                ? 'Thread saved to bookmarks'
                                                : 'Thread removed from bookmarks',
                                          );
                                        }
                                      },
                                      child: Center(
                                        child: Icon(
                                          isBookmarked
                                              ? Icons.bookmark_rounded
                                              : Icons.bookmark_border_rounded,
                                          size: 19,
                                          color: isBookmarked
                                              ? colors.primary
                                              : (isBmHovered ? colors.primary : colors.textSecondary),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
