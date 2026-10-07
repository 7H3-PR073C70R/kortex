import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/kortex_logo_assembly_widget.dart';

/// Production-ready animated brand loader widget featuring the
/// deconstructing and forming Kortex neural vector logo.
class AppLogoLoader extends StatelessWidget {
  const AppLogoLoader({
    super.key,
    this.size = 64,
    this.message,
    this.showMessage = true,
    this.color,
  });

  final double size;
  final String? message;
  final bool showMessage;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Semantics(
      label: message ?? 'Loading, please wait...',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          KortexLogoAssemblyWidget(
            size: size,
            mode: LogoAssemblyMode.looping,
          ),
          if (showMessage && message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: typography.footnote.medium.copyWith(
                color: colors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
