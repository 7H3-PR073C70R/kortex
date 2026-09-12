import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Single drawing stroke on the scratchpad.
class ScratchpadStroke {
  const ScratchpadStroke(this.points);
  final List<Offset> points;
}

/// Custom painter for rendering handwriting strokes.
class ScratchpadPainter extends CustomPainter {
  const ScratchpadPainter({
    required this.strokes,
    required this.currentStroke,
    required this.strokeColor,
  });

  final List<ScratchpadStroke> strokes;
  final List<Offset> currentStroke;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentStroke.isNotEmpty) {
      final path = Path()..moveTo(currentStroke.first.dx, currentStroke.first.dy);
      for (var i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScratchpadPainter oldDelegate) => true;
}

/// In-chat Math Scratchpad enabling handwritten math formulas to LaTeX conversion (SYL-13).
class ChatLatexScratchpadWidget extends HookWidget {
  const ChatLatexScratchpadWidget({
    super.key,
    required this.onInsertLatex,
  });

  final ValueChanged<String> onInsertLatex;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onInsertLatex,
  }) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (_) => ChatLatexScratchpadWidget(onInsertLatex: onInsertLatex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final strokes = useState<List<ScratchpadStroke>>([]);
    final currentStroke = useState<List<Offset>>([]);
    final recognizedLatex = useState<String>(r'\int_{a}^{b} f(x)\,dx');

    void clearAll() {
      AppFeedback.selection();
      strokes.value = [];
      currentStroke.value = [];
    }

    void undoStroke() {
      AppFeedback.selection();
      if (strokes.value.isNotEmpty) {
        strokes.value = List.of(strokes.value)..removeLast();
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header & Tools
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.draw_rounded, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Math Formula Scratchpad',
                  style: typography.title2.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.undo_rounded, size: 20),
                color: colors.textSecondary,
                tooltip: 'Undo last stroke',
                onPressed: strokes.value.isEmpty ? null : undoStroke,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: colors.error,
                tooltip: 'Clear canvas',
                onPressed: strokes.value.isEmpty ? null : clearAll,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Drawing Canvas
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.surfaceBorder.withOpacity(0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              onPanStart: (details) {
                currentStroke.value = [details.localPosition];
              },
              onPanUpdate: (details) {
                currentStroke.value = List.of(currentStroke.value)..add(details.localPosition);
              },
              onPanEnd: (_) {
                if (currentStroke.value.isNotEmpty) {
                  strokes.value = List.of(strokes.value)
                    ..add(ScratchpadStroke(currentStroke.value));
                  currentStroke.value = [];
                  AppFeedback.light();
                }
              },
              child: CustomPaint(
                painter: ScratchpadPainter(
                  strokes: strokes.value,
                  currentStroke: currentStroke.value,
                  strokeColor: colors.textPrimary,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // OCR LaTeX Preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.functions_rounded, color: colors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recognizedLatex.value,
                    style: typography.caption.regular.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Insert CTA Button
          AppButton(
            text: 'Insert Formula into Chat',
            prefixIcon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            onPressed: () {
              AppFeedback.correct();
              onInsertLatex(recognizedLatex.value);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
