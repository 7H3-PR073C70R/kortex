import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';

/// Normalized rectangular occlusion mask on an image (coordinates 0.0 to 1.0).
class OcclusionMask {
  const OcclusionMask({
    required this.id,
    required this.rect,
    required this.answerText,
    this.isTarget = true,
  });

  final String id;
  final Rect rect; // Normalized (0.0 to 1.0)
  final String answerText;
  final bool isTarget;
}

/// Touch-enabled Image Occlusion viewer for medical and STEM flashcards (FSR-13).
class ImageOcclusionCardViewer extends HookWidget {
  const ImageOcclusionCardViewer({
    super.key,
    required this.masks,
    this.imageUrl,
    this.imageBytes,
    this.onMaskRevealed,
    this.activeMaskId,
  });

  final List<OcclusionMask> masks;
  final String? imageUrl;
  final List<int>? imageBytes;
  final ValueChanged<String>? onMaskRevealed;
  final String? activeMaskId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final transformationController = useTransformationController();
    final revealedMaskIds = useState<Set<String>>({});

    final allRevealed = revealedMaskIds.value.length == masks.length && masks.isNotEmpty;

    void toggleMask(String id) {
      AppFeedback.selection();
      final next = Set<String>.from(revealedMaskIds.value);
      if (next.contains(id)) {
        next.remove(id);
      } else {
        next.add(id);
      }
      revealedMaskIds.value = next;
      onMaskRevealed?.call(id);
    }

    void toggleAll() {
      AppFeedback.light();
      if (allRevealed) {
        revealedMaskIds.value = {};
      } else {
        revealedMaskIds.value = masks.map((m) => m.id).toSet();
      }
    }

    return Column(
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pinch to Zoom • Tap Mask to Reveal',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton.icon(
                onPressed: masks.isEmpty ? null : toggleAll,
                icon: Icon(
                  allRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 16,
                  color: colors.primary,
                ),
                label: Text(
                  allRevealed ? 'Hide All' : 'Reveal All',
                  style: typography.caption.regular.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Interactive Zoom & Pan Canvas
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.surfaceBorder.withOpacity(0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              transformationController: transformationController,
              minScale: 1.0,
              maxScale: 4.5,
              boundaryMargin: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Base Image or Fallback Schematic
                      _buildBaseImage(context),
                      // Occlusion Masks Overlay
                      ...masks.map((mask) {
                        final isRevealed = revealedMaskIds.value.contains(mask.id);
                        final isActive = mask.id == activeMaskId;

                        final left = mask.rect.left * constraints.maxWidth;
                        final top = mask.rect.top * constraints.maxHeight;
                        final width = mask.rect.width * constraints.maxWidth;
                        final height = mask.rect.height * constraints.maxHeight;

                        return Positioned(
                          left: left,
                          top: top,
                          width: width,
                          height: height,
                          child: Semantics(
                            label: isRevealed
                                ? 'Revealed answer: ${mask.answerText}'
                                : 'Hidden occlusion mask, double tap to reveal',
                            button: true,
                            child: GestureDetector(
                              onTap: () => toggleMask(mask.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isRevealed
                                      ? colors.primary.withOpacity(0.2)
                                      : isActive
                                          ? colors.syllabotAccent
                                          : colors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isRevealed
                                        ? colors.primary
                                        : Colors.white.withOpacity(0.8),
                                    width: isActive ? 2.5 : 1.5,
                                  ),
                                  boxShadow: isRevealed
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.25),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Center(
                                  child: isRevealed
                                      ? Text(
                                          mask.answerText,
                                          textAlign: TextAlign.center,
                                          style: typography.caption.regular.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : Icon(
                                          Icons.help_outline_rounded,
                                          size: 14,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildBaseImage(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackSchematic(context),
      );
    }

    return _buildFallbackSchematic(context);
  }

  Widget _buildFallbackSchematic(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      color: colors.surfaceSecondary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.biotech_rounded, size: 56, color: colors.primary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              'STEM / Anatomical Diagram Canvas',
              style: typography.body.medium.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
