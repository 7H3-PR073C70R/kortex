import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';
import 'package:kortex/src/l10n/l10n.dart';

class CameraLiveOcrOverlay extends StatelessWidget {
  const CameraLiveOcrOverlay({
    required this.detectedBlocks,
    super.key,
    this.isProcessing = false,
    this.onCapture,
  });

  final List<RecognizedTextBlock> detectedBlocks;
  final bool isProcessing;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;

    return Semantics(
      container: true,
      label:
          'Live Document OCR Camera Scanner View with '
          '${detectedBlocks.length} detected text blocks',
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Semi-transparent scan guidance layer
          CustomPaint(
            painter: _BoundingBoxPainter(
              blocks: detectedBlocks,
              accentColor: theme.colorScheme.primary,
            ),
          ),

          // Top guidance header with frosted glass style
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Semantics(
              liveRegion: true,
              label: l10n.alignCameraTextHint,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.center_focus_strong_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.alignCameraTextHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom capture button trigger
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                button: true,
                label: 'Capture Camera Frame for Document Extraction',
                child: GestureDetector(
                  onTap: isProcessing ? null : onCapture,
                  child: Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isProcessing
                            ? Colors.grey
                            : theme.colorScheme.primary,
                      ),
                      child: isProcessing
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  _BoundingBoxPainter({
    required this.blocks,
    required this.accentColor,
  });

  final List<RecognizedTextBlock> blocks;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    for (final block in blocks) {
      final rect = Rect.fromLTWH(
        block.left,
        block.top,
        block.width,
        block.height,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas
        ..drawRRect(rrect, fillPaint)
        ..drawRRect(rrect, boxPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.blocks != blocks;
  }
}
