import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class QuickJoinRoomChip extends StatefulWidget {
  const QuickJoinRoomChip({
    required this.roomId,
    required this.roomTitle,
    required this.activePeersCount,
    super.key,
    this.onTap,
  });

  final String roomId;
  final String roomTitle;
  final int activePeersCount;
  final VoidCallback? onTap;

  @override
  State<QuickJoinRoomChip> createState() => _QuickJoinRoomChipState();
}

class _QuickJoinRoomChipState extends State<QuickJoinRoomChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    unawaited(_pulseController.repeat(reverse: true));

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final peerCountStr = l10n.activeRoomPeers(widget.activePeersCount);
    final semanticLabel =
        '${l10n.quickJoinStudyRoom}: ${widget.roomTitle}, $peerCountStr';

    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: ShrinkableButton(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.recallEasy.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.recallEasy.withValues(
                        alpha: _pulseAnimation.value,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                widget.roomTitle,
                style: typography.footnote.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.activePeersCount}',
                  style: typography.caption.bold.copyWith(
                    color: colors.recallEasy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
