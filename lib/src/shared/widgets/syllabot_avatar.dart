import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/gen/assets.gen.dart';

/// Unique, iconic Syllabot AI avatar mascot with vibrant ambient glow.
class SyllabotAvatar extends StatelessWidget {
  const SyllabotAvatar({
    super.key,
    this.size = 38,
    this.isError = false,
  });

  final double size;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isError
              ? colors.error
              : colors.syllabotAccent.withAlpha(isDark ? 220 : 180),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isError
                ? colors.error.withAlpha(isDark ? 100 : 50)
                : colors.syllabotAccent.withAlpha(isDark ? 110 : 70),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: isError
            ? Container(
                color: colors.error.withAlpha(isDark ? 60 : 30),
                alignment: Alignment.center,
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: size * 0.55,
                  color: colors.error,
                ),
              )
            : Image(
                image: AppAssets.images.syllabotAvatar.provider(),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: colors.primary.withAlpha(isDark ? 80 : 40),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.auto_awesome,
                    size: size * 0.55,
                    color: colors.syllabotAccent,
                  ),
                ),
              ),
      ),
    );
  }
}
