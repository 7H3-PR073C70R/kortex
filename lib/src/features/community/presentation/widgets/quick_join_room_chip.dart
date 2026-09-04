import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

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
    final theme = context.theme;
    final l10n = context.l10n;
    final peerCountStr = l10n.activeRoomPeers(widget.activePeersCount);
    final semanticLabel =
        '${l10n.quickJoinStudyRoom}: ${widget.roomTitle}, $peerCountStr';

    final colors = context.colors;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.recallEasy.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.26),
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
                        boxShadow: [
                          BoxShadow(
                            color: colors.recallEasy.withValues(
                              alpha: _pulseAnimation.value * 0.6,
                            ),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  widget.roomTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.activePeersCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.recallEasy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
