import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Card allowing users to specify a subject or concept and trigger offline card synthesis.
class OfflineTopicInputCard extends StatelessWidget {
  const OfflineTopicInputCard({
    required this.controller,
    required this.isGenerating,
    required this.onGenerate,
    super.key,
  });

  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(color: colors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Study Subject / Concept',
            style: typography.subhead.medium.copyWith(
              color: colors.textSecondary,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 8.h),
          AppTextField(
            controller: controller,
            hintText: 'e.g. Navier-Stokes Equations',
          ),
          SizedBox(height: 16.h),
          AppButton(
            text: isGenerating
                ? 'Synthesizing On-Device...'
                : 'Generate Flashcards',
            isLoading: isGenerating,
            onPressed: isGenerating ? null : onGenerate,
          ),
        ],
      ),
    );
  }
}
