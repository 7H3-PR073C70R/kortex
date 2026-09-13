import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
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
    VoidCallback? onTap,
    VoidCallback? onDownloadComplete,
    DismissType dismissType = DismissType.onSwipe,
    List<DismissDirection> dismissDirection = const [
      DismissDirection.up,
      DismissDirection.horizontal,
      DismissDirection.down,
    ],
    OverlayState? overlay,
  }) {
    var overlayState = overlay ?? Overlay.maybeOf(this);
    if (overlayState == null) {
      if (this is StatefulElement &&
          (this as StatefulElement).state is NavigatorState) {
        overlayState =
            ((this as StatefulElement).state as NavigatorState).overlay;
      } else {
        overlayState = Navigator.maybeOf(this)?.overlay;
      }
    }
    if (overlayState == null) return;

    final isModelDownload = message.contains('LocalLlmNotDownloadedException') ||
        message.contains('On-device neural engine is not downloaded') ||
        message.contains('248MB model weights') ||
        message.contains('248 MB model weights');

    final effectiveDuration = isModelDownload
        ? const Duration(minutes: 5)
        : duration;

    showTopSnackBar(
      overlayState,
      _ThemedDistinctSnackBar(
        message: message,
        type: type,
        onTap: onTap,
        onDownloadComplete: onDownloadComplete,
      ),
      displayDuration: effectiveDuration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
      dismissType: dismissType,
      dismissDirection: dismissDirection,
    );
  }

  void showModelDownloadSnackBar({
    String? message,
    VoidCallback? onDownloadComplete,
    OverlayState? overlay,
  }) {
    showSnackBar(
      message: message ??
          'On-device neural engine is not downloaded. Please download the 248MB model weights to enable offline reasoning.',
      type: SnackBarType.error,
      duration: const Duration(minutes: 5),
      onDownloadComplete: onDownloadComplete,
      overlay: overlay,
    );
  }
}

class _ThemedDistinctSnackBar extends StatefulWidget {
  const _ThemedDistinctSnackBar({
    required this.message,
    required this.type,
    this.onTap,
    this.onDownloadComplete,
  });

  final String message;
  final SnackBarType type;
  final VoidCallback? onTap;
  final VoidCallback? onDownloadComplete;

  @override
  State<_ThemedDistinctSnackBar> createState() =>
      _ThemedDistinctSnackBarState();
}

class _ThemedDistinctSnackBarState extends State<_ThemedDistinctSnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _badgeController;
  late final Animation<double> _badgeScale;

  bool _isDownloading = false;
  double _downloadProgress = 0;
  bool _isDone = false;
  String? _downloadError;
  StreamSubscription<double>? _downloadSub;

  bool get _isModelDownloadMessage =>
      widget.message.contains('LocalLlmNotDownloadedException') ||
      widget.message.contains('On-device neural engine is not downloaded') ||
      widget.message.contains('248MB model weights') ||
      widget.message.contains('248 MB model weights');

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
    unawaited(_downloadSub?.cancel());
    _badgeController.dispose();
    super.dispose();
  }

  void _startDownload() {
    if (!locator.isRegistered<LocalLlmEngineClient>()) return;
    final client = locator<LocalLlmEngineClient>();

    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.05;
      _downloadError = null;
    });

    _downloadSub = client.downloadModel().listen(
      (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isDone = true;
            _downloadProgress = 1.0;
          });
          unawaited(HapticFeedback.heavyImpact());
          widget.onDownloadComplete?.call();
        }
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadError = 'Download failed. Tap to retry.';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final effectiveType = _isDone
        ? SnackBarType.success
        : (_isDownloading ? SnackBarType.info : widget.type);

    final (
      Color accentColor,
      Color bgTint,
      Color borderColor,
      IconData icon,
      String title,
    ) = switch (effectiveType) {
      SnackBarType.error => (
        colors.error,
        colors.error.withAlpha(isDark ? 55 : 35),
        colors.error.withAlpha(isDark ? 160 : 120),
        Icons.error_outline_rounded,
        'Notice',
      ),
      SnackBarType.success => (
        colors.success,
        colors.success.withAlpha(isDark ? 50 : 30),
        colors.success.withAlpha(isDark ? 150 : 110),
        Icons.check_circle_rounded,
        'Success',
      ),
      SnackBarType.info => (
        colors.primary,
        colors.primary.withAlpha(isDark ? 50 : 30),
        colors.primary.withAlpha(isDark ? 150 : 110),
        Icons.download_rounded,
        'Downloading Model',
      ),
    };

    return Center(
      child: Material(
        color: colors.transparent,
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
                    color: colors.black.withAlpha(isDark ? 90 : 20),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: widget.onTap != null && !_isModelDownloadMessage
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onTap,
                      child: _buildContent(accentColor, bgTint, icon, title, colors, typography, isDark),
                    )
                  : _buildContent(accentColor, bgTint, icon, title, colors, typography, isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    Color accentColor,
    Color bgTint,
    IconData icon,
    String title,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    if (_isModelDownloadMessage) {
      return _buildModelDownloadContent(accentColor, bgTint, colors, typography, isDark);
    }

    return Row(
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
                color: accentColor.withAlpha(200),
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
    );
  }

  Widget _buildModelDownloadContent(
    Color accentColor,
    Color bgTint,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Icon Badge
        ScaleTransition(
          scale: _badgeScale,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgTint,
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withAlpha(200),
                width: 1.2,
              ),
            ),
            child: Icon(
              _isDone
                  ? Icons.check_circle_rounded
                  : (_isDownloading
                      ? Icons.downloading_rounded
                      : Icons.error_outline_rounded),
              color: accentColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Interactive Download Body
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isDone
                    ? 'Engine Ready'
                    : (_isDownloading
                        ? 'Downloading Neural Model'
                        : 'On-Device AI Required'),
                style: typography.caption.bold.copyWith(
                  color: accentColor,
                  fontSize: 11.5,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              if (_isDone) ...[
                Text(
                  'Model weights downloaded (248 MB) and activated! Generating response...',
                  style: typography.caption.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ] else if (_isDownloading) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Downloading weights...',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                    Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: colors.primary.withAlpha(isDark ? 40 : 25),
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_downloadProgress * 248).toStringAsFixed(1)} MB of 248 MB',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ] else ...[
                Text(
                  'On-device neural engine is not downloaded. Please download the 248MB model weights to enable offline reasoning.',
                  style: typography.caption.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                if (_downloadError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _downloadError!,
                    style: typography.caption.bold.copyWith(
                      color: colors.error,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ShrinkableButton(
                  onTap: _startDownload,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withAlpha(70),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.download_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Download Model (248 MB)',
                          style: typography.caption.bold.copyWith(
                            color: Colors.white,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
