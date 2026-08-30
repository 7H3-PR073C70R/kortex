import 'package:flutter/material.dart';
import 'package:kortex/src/core/constants/app_spacing.dart';
import 'package:kortex/src/core/extensions/num_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

extension BuildContextExtension on BuildContext {
  void showSnackBar({
    required String message,
    SnackBarType type = SnackBarType.success,
  }) {
    return showTopSnackBar(
      Overlay.of(this),
      switch (type) {
        SnackBarType.error => CustomSnackBar.error(
            message: message,
            backgroundColor: colors.error,
            textStyle: TextStyle(
              fontSize: 12.fontSize,
              fontWeight: FontWeight.w500,
              color: colors.white,
            ),
            borderRadius: BorderRadius.circular(8.radius),
          ),
        SnackBarType.success => CustomSnackBar.success(
            message: message,
            backgroundColor: colors.success,
            textStyle: TextStyle(
              fontSize: 12.fontSize,
              fontWeight: FontWeight.w500,
              color: colors.white,
            ),
            borderRadius: BorderRadius.circular(8.radius),
          ),
        SnackBarType.info => UnconstrainedBox(
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: 12.height,
                horizontal: 16.width,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.radius),
                color: colors.surfaceTertiary,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: textTheme.body.bold.copyWith(
                      fontSize: 12.fontSize,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  AppSpacing.horizontalSpaceMedium,
                ],
              ),
            ),
          ),
      },
    );
  }
}

enum SnackBarType {
  error,
  success,
  info,
}
