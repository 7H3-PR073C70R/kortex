import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/thread_group/forum_reply_options_menu.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Author metadata row for top-level parent forum reply.
class ParentReplyAuthorHeader extends StatelessWidget {
  const ParentReplyAuthorHeader({
    required this.parentReply,
    required this.isAiReply,
    required this.isOp,
    this.onEditReply,
    this.onDeleteReply,
    this.userStorage,
    super.key,
  });

  final ForumReplyEntity parentReply;
  final bool isAiReply;
  final bool isOp;
  final VoidCallback? onEditReply;
  final VoidCallback? onDeleteReply;
  final UserStorageService? userStorage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Row(
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
        else if (parentReply.isAnonymous)
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? colors.surfaceSecondary
                  : colors.surfaceBorder.withAlpha(40),
              border: Border.all(
                color: colors.textSecondary.withAlpha(
                  isDark ? 60 : 35,
                ),
                width: 0.8,
              ),
            ),
            child: Icon(
              Icons.visibility_off_rounded,
              size: 14,
              color: colors.textSecondary,
            ),
          )
        else
          AppAvatar(
            customDimension: 28,
            name: parentReply.authorName,
            backgroundColor: colors.primary.withAlpha(
              isDark ? 40 : 25,
            ),
            foregroundColor: colors.primary,
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
                      parentReply.isAnonymous
                          ? parentReply.authorName
                          : '@${parentReply.authorName}',
                      style: typography.subhead.bold.copyWith(
                        color: isAiReply
                            ? colors.syllabotAccent
                            : (parentReply.isAnonymous
                                  ? colors.textSecondary
                                  : colors.textPrimary),
                        fontSize: 13.5,
                        fontStyle: parentReply.isAnonymous
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (parentReply.isAnonymous)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withAlpha(
                          isDark ? 35 : 20,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: colors.textSecondary.withAlpha(
                            isDark ? 60 : 35,
                          ),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 8.5,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Incognito',
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        style: typography.caption.bold.copyWith(
                          color: colors.white,
                          fontSize: 9,
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
                formatTime(parentReply.createdAt, l10n),
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        ShrinkableButton(
          onTap: () => showForumReplyOptionsMenu(
            context,
            parentReply,
            onEdit: onEditReply,
            onDelete: onDeleteReply,
            userStorage: userStorage,
          ),
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
    );
  }

  static String formatTime(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
