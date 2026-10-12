import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';

/// Shimmer loading skeleton displayed while initializing TOTP enrollment.
class TwoFactorShimmerSkeleton extends StatelessWidget {
  const TwoFactorShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description skeleton
              const ShimmerPlaceholder(height: 14, width: 280, borderRadius: 6),
              const SizedBox(height: 6),
              const ShimmerPlaceholder(height: 14, width: 200, borderRadius: 6),
              const SizedBox(height: 20),

              // Step 1: QR Code Card Skeleton
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: AppRadius.radiusDialog,
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(90),
                  ),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        ShimmerPlaceholder(
                          height: 24,
                          width: 24,
                          borderRadius: 12,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ShimmerPlaceholder(
                            height: 16,
                            width: 200,
                            borderRadius: 6,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    ShimmerPlaceholder(
                      height: 190,
                      width: 190,
                      borderRadius: 16,
                    ),
                    SizedBox(height: 14),
                    ShimmerPlaceholder(
                      height: 12,
                      width: 220,
                      borderRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Step 2: Copy Secret Key Skeleton
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: AppRadius.radiusDialog,
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(90),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShimmerPlaceholder(
                          height: 24,
                          width: 24,
                          borderRadius: 12,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ShimmerPlaceholder(
                            height: 16,
                            width: 180,
                            borderRadius: 6,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    ShimmerPlaceholder(height: 48, borderRadius: 14),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Step 3: Verify Code Skeleton
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: AppRadius.radiusDialog,
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(90),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShimmerPlaceholder(
                          height: 24,
                          width: 24,
                          borderRadius: 12,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ShimmerPlaceholder(
                            height: 16,
                            width: 160,
                            borderRadius: 6,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    ShimmerPlaceholder(height: 50, borderRadius: 14),
                    SizedBox(height: 16),
                    ShimmerPlaceholder(height: 52, borderRadius: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
