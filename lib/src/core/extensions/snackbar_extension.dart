import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

enum SnackBarType {
  info,
  success,
  error,
}

extension BuildContextExtension on BuildContext {
  void showSnackBar({
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(milliseconds: 4500),
  }) {
    showTopSnackBar(
      Overlay.of(this),
      _ThemedDistinctSnackBar(
        message: message,
        type: type,
      ),
      displayDuration: duration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }
}

class _ThemedDistinctSnackBar extends StatefulWidget {
  const _ThemedDistinctSnackBar({
    required this.message,
    required this.type,
  });

  final String message;
  final SnackBarType type;

  @override
  State<_ThemedDistinctSnackBar> createState() =>
      _ThemedDistinctSnackBarState();
}

class _ThemedDistinctSnackBarState extends State<_ThemedDistinctSnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _badgeController;
  late final Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _badgeScale = CurvedAnimation(
      parent: _badgeController,
      curve: Curves.elasticOut,
    );
    unawaited(_badgeController.forward());
  }

  @override
  void dispose() {
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final (
      Color accentColor,
      Color bgTint,
      Color borderColor,
      IconData icon,
      String title
    ) = switch (widget.type) {
      SnackBarType.error => (
          const Color(0xFFEF4444),
          const Color(0xFFEF4444).withAlpha(isDark ? 55 : 35),
          const Color(0xFFEF4444).withAlpha(isDark ? 160 : 120),
          Icons.error_outline_rounded,
          'Notice',
        ),
      SnackBarType.success => (
          const Color(0xFF10B981),
          const Color(0xFF10B981).withAlpha(isDark ? 50 : 30),
          const Color(0xFF10B981).withAlpha(isDark ? 150 : 110),
          Icons.check_circle_rounded,
          'Success',
        ),
      SnackBarType.info => (
          const Color(0xFF6366F1),
          const Color(0xFF6366F1).withAlpha(isDark ? 50 : 30),
          const Color(0xFF6366F1).withAlpha(isDark ? 150 : 110),
          Icons.info_outline_rounded,
          'Info',
        ),
    };

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.92,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfacePrimary.withAlpha(240)
                    : colors.surfacePrimary.withAlpha(250),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withAlpha(isDark ? 70 : 40),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 90 : 20),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Prominent Status Icon Badge
                  ScaleTransition(
                    scale: _badgeScale,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: bgTint,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withAlpha(isDark ? 120 : 80),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Message Text
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: typography.caption.bold.copyWith(
                            color: accentColor,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          style: typography.caption.medium.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
