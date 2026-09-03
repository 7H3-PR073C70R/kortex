import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

class StreamingTextTypingIndicator extends HookWidget {
  const StreamingTextTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );

    useEffect(() {
      unawaited(controller.repeat());
      return null;
    }, [controller]);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          children: [
            const SyllabotAvatar(size: 28),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(200)
                        : colors.surfacePrimary.withAlpha(220),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 50 : 30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: controller,
                        builder: (context, child) {
                          final progress =
                              (controller.value + (index * 0.2)) % 1.0;
                          final opacity = (progress < 0.5)
                              ? 0.3 + (progress * 1.4)
                              : 1.0 - ((progress - 0.5) * 1.4);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.syllabotAccent.withAlpha(
                                (opacity.clamp(0.2, 1.0) * 255).toInt(),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
