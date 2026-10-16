import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Floating bottom dock presenting course count summary and curriculum save action.
class CurateCoursesSaveDock extends StatelessWidget {
  const CurateCoursesSaveDock({
    required this.selectedCount,
    required this.isSubmitting,
    required this.onSave,
    required this.colors,
    required this.typography,
    required this.isDark,
    super.key,
  });

  final int selectedCount;
  final bool isSubmitting;
  final VoidCallback onSave;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.backgroundPrimary.withAlpha(200)
                  : colors.surfacePrimary.withAlpha(220),
              border: Border(
                top: BorderSide(
                  color: colors.surfaceBorder.withAlpha(100),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: ShrinkableButton(
                onTap: isSubmitting ? null : onSave,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(
                      AppRadius.card,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(
                          isDark ? 60 : 25,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isSubmitting
                        ? AppLogoLoader(
                            size: 20,
                            color: colors.white,
                            showMessage: false,
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: colors.white,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedCount == 0
                                    ? 'Save Curriculum'
                                    : 'Save $selectedCount Course${selectedCount == 1 ? '' : 's'}',
                                style: typography.callout.bold.copyWith(
                                  color: colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
