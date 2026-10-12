import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Step 1 card displaying the generated TOTP QR code for authenticator apps.
class TwoFactorQrCodeCard extends StatelessWidget {
  const TwoFactorQrCodeCard({
    required this.totpUri,
    super.key,
  });

  final String totpUri;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: AppRadius.radiusDialog,
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(90),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '1',
                    style: typography.caption.bold.copyWith(
                      color: colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Scan QR Code with Authenticator App',
                  style: typography.body.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.white,
              borderRadius: AppRadius.radiusPanel,
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: totpUri.isNotEmpty
                ? QrImageView(
                    data: totpUri,
                    size: 190,
                    gapless: false,
                    errorStateBuilder: (cxt, err) {
                      return const SizedBox(
                        height: 190,
                        child: Center(
                          child: Text(
                            'Could not generate QR',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  )
                : const SizedBox(
                    height: 190,
                    child: Center(
                      child: AppLogoLoader(size: 48),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'Compatible with Google Authenticator, Authy, '
            '1Password, Microsoft Authenticator',
            textAlign: TextAlign.center,
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
