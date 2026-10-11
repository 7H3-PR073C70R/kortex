import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/monetization/data/datasources/revenuecat_service.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_features_timeline_section.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_footer_links.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Screen content shown when user is already an active Pro subscriber.
class PaywallActiveProView extends StatelessWidget {
  const PaywallActiveProView({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.isDark,
    required this.authState,
    required this.onReturnToKortex,
    required this.onManageSubscription,
    required this.onOpenPrivacyPolicy,
    required this.onOpenTermsOfService,
    this.customerInfo,
    super.key,
  });

  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final bool isDark;
  final AuthState authState;
  final VoidCallback onReturnToKortex;
  final VoidCallback onManageSubscription;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenTermsOfService;
  final CustomerInfo? customerInfo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActiveProHeader(),
              const SizedBox(height: 16),
              _buildActiveSubscriptionCard(),
              const SizedBox(height: 18),
              _buildActiveUnlockedFeaturesGrid(),
              const SizedBox(height: 20),
              _buildActiveProActions(),
              const SizedBox(height: 18),
              PaywallFooter(
                colors: colors,
                typography: typography,
                l10n: l10n,
                onOpenPrivacyPolicy: onOpenPrivacyPolicy,
                onOpenTermsOfService: onOpenTermsOfService,
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveProHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.success.withAlpha(90),
                colors.primary.withAlpha(70),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.success.withAlpha(160),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.success.withAlpha(isDark ? 50 : 25),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: colors.warning,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'KORTEXIFY PRO MEMBER',
                style: typography.caption.bold.copyWith(
                  color: colors.white,
                  fontSize: 11.5,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              delay: 1200.ms,
              duration: 2200.ms,
              color: colors.white.withAlpha(80),
              angle: 45,
            ),
        const SizedBox(height: 12),
        Text(
          'You are on Kortexify Pro',
          textAlign: TextAlign.center,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enjoy unlimited Socratic AI tutoring, 200MB file drops, voice dialogue, and cognitive study diagnostics.',
          textAlign: TextAlign.center,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSubscriptionCard() {
    final email = authState.userProfile?.email ??
        authState.user?.email ??
        'Subscribed Account';
    final entitlement =
        customerInfo?.entitlements.all[RevenueCatService.proEntitlementId];
    var statusDetail = 'Active Access';
    if (entitlement != null && entitlement.expirationDate != null) {
      try {
        final date = DateTime.parse(entitlement.expirationDate!);
        statusDetail =
            'Renews ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    } else if (entitlement?.willRenew == false) {
      statusDetail = 'Cancels at end of period';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(210)
            : colors.surfacePrimary.withAlpha(240),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: colors.success.withAlpha(isDark ? 100 : 70),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.success.withAlpha(isDark ? 30 : 15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.success.withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: colors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pro Unlimited Pass',
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.success.withAlpha(35),
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: colors.success.withAlpha(100),
                  ),
                ),
                child: Text(
                  'ACTIVE',
                  style: typography.caption.bold.copyWith(
                    color: colors.success,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: colors.surfaceBorder.withAlpha(70),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_repeat_rounded,
                    size: 15,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Billing Status',
                    style: typography.footnote.medium.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                statusDetail,
                style: typography.footnote.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveUnlockedFeaturesGrid() {
    final unlockedFeatures = [
      const ProFeatureItem(
        icon: Icons.psychology_rounded,
        title: 'Unlimited Syllabot AI',
        subtitle: 'Unrestricted 24/7 Socratic problem-solving & derivations',
      ),
      const ProFeatureItem(
        icon: Icons.document_scanner_rounded,
        title: '200MB Multimodal OCR Drop',
        subtitle: 'High-capacity PDF, PPTX, image & lecture transcript drops',
      ),
      const ProFeatureItem(
        icon: Icons.mic_rounded,
        title: 'Real-Time Voice Dialogue',
        subtitle: 'Hands-free interactive voice study sessions with AI',
      ),
      const ProFeatureItem(
        icon: Icons.auto_graph_rounded,
        title: 'AI Cognitive Diagnostics',
        subtitle: 'Exam readiness, weakness breakdown & retention radar',
      ),
      const ProFeatureItem(
        icon: Icons.download_rounded,
        title: 'Full Deck Exports',
        subtitle: 'Export to Anki, CSV, and high-density printable PDFs',
      ),
      const ProFeatureItem(
        icon: Icons.cloud_sync_rounded,
        title: 'Cloud Backup & Multi-Device',
        subtitle: 'Instant multi-device sync with zero-latency offline cache',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'UNLOCKED PRO CAPABILITIES',
            style: typography.caption.bold.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(180)
                : colors.surfacePrimary.withAlpha(220),
            borderRadius: AppRadius.radiusPanel,
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(isDark ? 80 : 50),
            ),
          ),
          child: Column(
            children: unlockedFeatures
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(30),
                            borderRadius: AppRadius.radiusCard,
                          ),
                          child: Icon(
                            f.icon,
                            color: colors.primary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.title,
                                style: typography.body.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                f.subtitle,
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 10.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.check_circle_rounded,
                          color: colors.success,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveProActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return ShrinkableButton(
              onTap: onReturnToKortex,
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      if (isHovered)
                        colors.syllabotAccent.withAlpha(240)
                      else
                        colors.syllabotAccent,
                    ],
                  ),
                  borderRadius: AppRadius.radiusPanel,
                  boxShadow: [
                    BoxShadow(
                      color: colors.black.withAlpha(
                        isDark ? (isHovered ? 80 : 55) : (isHovered ? 45 : 25),
                      ),
                      blurRadius: isHovered ? 20 : 16,
                      offset: Offset(0, isHovered ? 6 : 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rocket_launch_rounded,
                        color: colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Return to Kortex',
                        style: typography.body.bold.copyWith(
                          color: colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onManageSubscription,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            side: BorderSide(
              color: colors.primary.withAlpha(120),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.radiusPanel,
            ),
          ),
          icon: Icon(
            Icons.settings_outlined,
            size: 16,
            color: colors.primary,
          ),
          label: Text(
            'Manage Store Subscription',
            style: typography.caption.bold.copyWith(
              color: colors.primary,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
