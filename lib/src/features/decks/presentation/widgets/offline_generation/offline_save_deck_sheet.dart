import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Modal sheet for saving synthesized offline cards to user's study deck repository.
Future<void> showOfflineSaveDeckSheet({
  required BuildContext context,
  required String defaultTitle,
  required String defaultSubject,
  required int cardCount,
  required Future<void> Function({required String title, required String subject}) onConfirm,
}) {
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;

  final titleController = TextEditingController(text: defaultTitle);
  final subjectController = TextEditingController(text: defaultSubject);

  return AppAdaptiveSheet.showModal<void>(
    context: context,
    builder: (sheetContext) {
      final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(sheetContext);
      return SafeArea(
        top: false,
        child: Align(
          alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary
                    : colors.surfacePrimary,
                borderRadius: isDesktop
                    ? BorderRadius.circular(AppRadius.dialog)
                    : const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.dialog),
                      ),
                boxShadow: isDesktop
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: isDesktop
                      ? 0
                      : MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isDesktop) ...[
                        Center(
                          child: Container(
                            width: 40.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: colors.surfaceBorder,
                              borderRadius: AppRadius.radiusMicro,
                            ),
                          ),
                        ),
                        SizedBox(height: 18.h),
                      ],
                      Text(
                        'Save to Study Decks',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Save $cardCount generated flashcards to your active recall study deck.',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 20.h),
                      AppTextField(
                        controller: titleController,
                        hintText: 'Deck Title (e.g. $defaultTitle)',
                      ),
                      SizedBox(height: 14.h),
                      AppTextField(
                        controller: subjectController,
                        hintText:
                            'Subject / Category (e.g. Physics, Mathematics)',
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.radiusCard,
                                ),
                                side: BorderSide(color: colors.surfaceBorder),
                              ),
                              child: Text(
                                'Cancel',
                                style: typography.body.semiBold.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: AppButton(
                              text: 'Confirm & Save',
                              onPressed: () {
                                final title = titleController.text.trim().isNotEmpty
                                    ? titleController.text.trim()
                                    : defaultTitle;
                                final subject = subjectController.text.trim().isNotEmpty
                                    ? subjectController.text.trim()
                                    : 'General Studies';
                                Navigator.of(sheetContext).pop();
                                unawaited(
                                  onConfirm(title: title, subject: subject),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
