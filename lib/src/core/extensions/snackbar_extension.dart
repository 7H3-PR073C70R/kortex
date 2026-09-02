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
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    showTopSnackBar(
      Overlay.of(this),
      _ThemedSlimSnackBar(
        message: message,
        type: type,
      ),
      displayDuration: duration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
  }
}

class _ThemedSlimSnackBar extends StatefulWidget {
  const _ThemedSlimSnackBar({
    required this.message,
    required this.type,
  });

  final String message;
  final SnackBarType type;

  @override
  State<_ThemedSlimSnackBar> createState() => _ThemedSlimSnackBarState();
}

class _ThemedSlimSnackBarState extends State<_ThemedSlimSnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _emojiController;
  late final Animation<double> _emojiScale;

  @override
  void initState() {
    super.initState();
    _emojiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _emojiScale = CurvedAnimation(
      parent: _emojiController,
      curve: Curves.elasticOut,
    );
    unawaited(_emojiController.forward());
  }

  @override
  void dispose() {
    _emojiController.dispose();
    super.dispose();
  }

  String get emoji => switch (widget.type) {
        SnackBarType.success => '😊',
        SnackBarType.error => '😢',
        SnackBarType.info => '💡',
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final accentColor = switch (widget.type) {
      SnackBarType.success => colors.success,
      SnackBarType.error => colors.error,
      SnackBarType.info => colors.primary,
    };

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.88,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfacePrimary.withAlpha(225)
                    : colors.surfacePrimary.withAlpha(240),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: accentColor.withAlpha(isDark ? 90 : 60),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withAlpha(isDark ? 45 : 25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 80 : 15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _emojiScale,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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
