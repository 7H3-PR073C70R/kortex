import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

class OcclusionMask {
  const OcclusionMask({
    required this.id,
    required this.rect,
    required this.label,
    this.isRevealed = false,
  });

  final String id;

  /// Normalized coordinates (0.0 to 1.0)
  final Rect rect;
  final String label;
  final bool isRevealed;

  OcclusionMask copyWith({bool? isRevealed}) {
    return OcclusionMask(
      id: id,
      rect: rect,
      label: label,
      isRevealed: isRevealed ?? this.isRevealed,
    );
  }
}

class ImageOcclusionCanvas extends StatefulWidget {
  const ImageOcclusionCanvas({
    required this.imageUrl,
    required this.masks,
    this.onMaskTapped,
    super.key,
  });

  final String imageUrl;
  final List<OcclusionMask> masks;
  final ValueChanged<int>? onMaskTapped;

  @override
  State<ImageOcclusionCanvas> createState() => _ImageOcclusionCanvasState();
}

class _ImageOcclusionCanvasState extends State<ImageOcclusionCanvas> {
  late List<OcclusionMask> _currentMasks;

  @override
  void initState() {
    super.initState();
    _currentMasks = List.from(widget.masks);
  }

  @override
  void didUpdateWidget(ImageOcclusionCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.masks != oldWidget.masks) {
      _currentMasks = List.from(widget.masks);
    }
  }

  void _toggleMask(int index) {
    AppFeedback.light();
    setState(() {
      final mask = _currentMasks[index];
      _currentMasks[index] = mask.copyWith(isRevealed: !mask.isRevealed);
    });
    widget.onMaskTapped?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final colors = context.colors;
    final typography = context.typography;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Base anatomical diagram / image
                Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: neural.obsidian850,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_rounded,
                          color: neural.slate400,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Diagram Image Unavailable',
                          style: typography.caption.regular.copyWith(
                            color: neural.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Occlusion Mask Overlays
                ..._currentMasks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final mask = entry.value;

                  final left = mask.rect.left * width;
                  final top = mask.rect.top * height;
                  final maskWidth = mask.rect.width * width;
                  final maskHeight = mask.rect.height * height;

                  return Positioned(
                    left: left,
                    top: top,
                    width: maskWidth,
                    height: maskHeight,
                    child: Semantics(
                      button: true,
                      label: mask.isRevealed
                          ? 'Occlusion mask ${mask.label}, revealed'
                          : 'Hidden occlusion mask, double tap to reveal',
                      child: GestureDetector(
                        onTap: () => _toggleMask(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: mask.isRevealed
                                ? neural.emerald.withAlpha(40)
                                : neural.amber.withAlpha(230),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: mask.isRevealed
                                  ? neural.emerald400
                                  : neural.amber400,
                              width: 1.5,
                            ),
                            boxShadow: [
                              if (!mask.isRevealed)
                                BoxShadow(
                                  color: colors.black.withAlpha(80),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: mask.isRevealed
                              ? Text(
                                  mask.label,
                                  textAlign: TextAlign.center,
                                  style: typography.caption.bold.copyWith(
                                    color: neural.emerald400,
                                    fontSize: 11,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.visibility_off_rounded,
                                      size: 14,
                                      color: colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tap to reveal',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
