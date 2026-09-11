import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';

class CameraLiveOcrOverlay extends StatelessWidget {
  const CameraLiveOcrOverlay({
    required this.detectedBlocks,
    super.key,
    this.isProcessing = false,
    this.onCapture,
    this.contrastNormalized = true,
  });

  final List<RecognizedTextBlock> detectedBlocks;
  final bool isProcessing;
  final VoidCallback? onCapture;
  final bool contrastNormalized;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = context.colors;
    final l10n = context.l10n;

    return Semantics(
      container: true,
      label:
          'Live Document OCR Camera Scanner View with '
          '${detectedBlocks.length} detected text blocks',
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Semi-transparent scan guidance & auto-crop page border layer
          CustomPaint(
            painter: _BoundingBoxPainter(
              blocks: detectedBlocks,
              accentColor: theme.colorScheme.primary,
            ),
          ),

          // Top guidance header with frosted glass style and contrast normalization status
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  label: l10n.alignCameraTextHint,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.white.withValues(alpha: 0.15),
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
                              color: colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Auto-crop & Contrast Normalization Pills
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.crop_free_rounded,
                            color: colors.primary,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Smart Page Auto-Crop',
                            style: TextStyle(
                              color: colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (contrastNormalized)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tonality_rounded,
                              color: colors.success,
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Contrast Normalization Active',
                              style: TextStyle(
                                color: colors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
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
                        color: colors.white,
                        width: 4,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isProcessing
                            ? colors.gray
                            : theme.colorScheme.primary,
                      ),
                      child: isProcessing
                          ? Center(
                              child: AppLogoLoader(
                                size: 24,
                                color: colors.white,
                              ),
                            )
                          : Icon(
                              Icons.camera_alt_rounded,
                              color: colors.white,
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
    // 1. Draw textbook page auto-crop guideline viewfinder
    final marginH = size.width * 0.08;
    final marginV = size.height * 0.16;
    final cropRect = Rect.fromLTRB(
      marginH,
      marginV,
      size.width - marginH,
      size.height - marginV - 80,
    );

    final cropGuidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cornerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(cropRect, const Radius.circular(16));
    canvas.drawRRect(rrect, cropGuidePaint);

    // Corner brackets for auto-crop alignment
    const cornerLength = 24.0;
    // Top-left
    canvas.drawLine(cropRect.topLeft, cropRect.topLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(cropRect.topLeft, cropRect.topLeft + const Offset(0, cornerLength), cornerPaint);
    // Top-right
    canvas.drawLine(cropRect.topRight, cropRect.topRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(cropRect.topRight, cropRect.topRight + const Offset(0, cornerLength), cornerPaint);
    // Bottom-left
    canvas.drawLine(cropRect.bottomLeft, cropRect.bottomLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(cropRect.bottomLeft, cropRect.bottomLeft + const Offset(0, -cornerLength), cornerPaint);
    // Bottom-right
    canvas.drawLine(cropRect.bottomRight, cropRect.bottomRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(cropRect.bottomRight, cropRect.bottomRight + const Offset(0, -cornerLength), cornerPaint);

    // 2. Draw detected OCR text blocks
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
      final blockRRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas
        ..drawRRect(blockRRect, fillPaint)
        ..drawRRect(blockRRect, boxPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.blocks != blocks;
  }
}
