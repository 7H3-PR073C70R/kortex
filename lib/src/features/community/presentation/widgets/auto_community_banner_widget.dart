import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_cubit.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_state.dart';
import 'package:kortex/src/l10n/l10n.dart';

class AutoCommunityBannerWidget extends StatefulWidget {
  const AutoCommunityBannerWidget({
    super.key,
    this.onTapOpenHub,
    this.onTapJoinRoom,
  });

  final void Function(StudyCommunityEntity community)? onTapOpenHub;
  final void Function(String roomId)? onTapJoinRoom;

  @override
  State<AutoCommunityBannerWidget> createState() =>
      _AutoCommunityBannerWidgetState();
}

class _AutoCommunityBannerWidgetState extends State<AutoCommunityBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  bool _hasAnnounced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _announceIfReady(BuildContext context, String message) {
    if (!_hasAnnounced && message.isNotEmpty) {
      _hasAnnounced = true;
      try {
        final view = View.of(context);
        unawaited(
          SemanticsService.sendAnnouncement(view, message, TextDirection.ltr),
        );
      } on Object catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;

    return BlocBuilder<AutoCommunityCubit, AutoCommunityState>(
      builder: (context, state) {
        if (!state.shouldShowBanner || state.community == null) {
          return const SizedBox.shrink();
        }

        final community = state.community!;
        final titleText = l10n.autoCommunityCreatedTitle(community.courseCode);
        final subtitleText = l10n.autoCommunityJoinedSubtitle(
          community.memberCount,
        );

        _announceIfReady(context, '$titleText $subtitleText');

        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Semantics(
                container: true,
                label: '$titleText $subtitleText',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 600;

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.18,
                                ),
                                theme.colorScheme.secondary.withValues(
                                  alpha: 0.10,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: isDesktop
                              ? _buildDesktopLayout(
                                  context,
                                  community,
                                  titleText,
                                  subtitleText,
                                )
                              : _buildMobileLayout(
                                  context,
                                  community,
                                  titleText,
                                  subtitleText,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    StudyCommunityEntity community,
    String titleText,
    String subtitleText,
  ) {
    final theme = context.theme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (community.isFoundingMember)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          l10n.foundingMemberBadge,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.amber.shade300,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    titleText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.white54,
              ),
              tooltip: l10n.cancelAction,
              onPressed: () =>
                  context.read<AutoCommunityCubit>().dismissBanner(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('open_hub_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  l10n.openCommunityHub,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  widget.onTapOpenHub?.call(community);
                },
              ),
            ),
            if (community.activeRoomId != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('join_room_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(
                  Icons.sensors_rounded,
                  size: 16,
                  color: Colors.greenAccent,
                ),
                label: Text(l10n.quickJoinStudyRoom),
                onPressed: () {
                  widget.onTapJoinRoom?.call(community.activeRoomId!);
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    StudyCommunityEntity community,
    String titleText,
    String subtitleText,
  ) {
    final theme = context.theme;
    final l10n = context.l10n;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.groups_rounded,
            color: theme.colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    titleText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (community.isFoundingMember)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        l10n.foundingMemberBadge,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.amber.shade300,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitleText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (community.activeRoomId != null) ...[
          OutlinedButton.icon(
            key: const Key('join_room_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            icon: const Icon(
              Icons.sensors_rounded,
              size: 18,
              color: Colors.greenAccent,
            ),
            label: Text(l10n.quickJoinStudyRoom),
            onPressed: () {
              widget.onTapJoinRoom?.call(community.activeRoomId!);
            },
          ),
          const SizedBox(width: 8),
        ],
        ElevatedButton.icon(
          key: const Key('open_hub_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.forum_rounded, size: 18),
          label: Text(
            l10n.openCommunityHub,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            widget.onTapOpenHub?.call(community);
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(
            Icons.close_rounded,
            size: 20,
            color: Colors.white54,
          ),
          tooltip: l10n.cancelAction,
          onPressed: () => context.read<AutoCommunityCubit>().dismissBanner(),
        ),
      ],
    );
  }
}
