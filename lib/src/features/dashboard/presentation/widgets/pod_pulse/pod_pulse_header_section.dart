import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/navigation/app_tab_navigation.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/pod_pulse/pod_metric_chip.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_animated_entrance.dart';

/// Header section with pulsing live indicator, target track shortcut, and metrics summary row.
class PodPulseHeaderSection extends StatelessWidget {
  const PodPulseHeaderSection({
    required this.trackLabel,
    required this.activeScholarsStr,
    required this.focusMinutesStr,
    required this.karmaStr,
    super.key,
  });

  final String trackLabel;
  final String activeScholarsStr;
  final String focusMinutesStr;
  final String karmaStr;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppPulsingBeacon(
                      color: neural.emerald,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.podPulseTitle,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.bold.copyWith(
                          color: neural.emerald400,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: neural.emerald.withAlpha(38),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: neural.emerald.withAlpha(77),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: neural.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE SYNC',
                            style: typography.caption.bold.copyWith(
                              color: neural.emerald400,
                              fontSize: 9,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  AppTabNavigation.navigateTo(
                    context,
                    AppMainTab.forum,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        trackLabel,
                        style: typography.caption.medium.copyWith(
                          color: neural.slate300,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: neural.slate400,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Metrics Summary Row
          Row(
            children: [
              Expanded(
                child: PodMetricChip(
                  icon: Icons.groups_rounded,
                  iconColor: neural.emerald400,
                  value: activeScholarsStr,
                  label: l10n.activeToday,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PodMetricChip(
                  icon: Icons.timer_outlined,
                  iconColor: neural.amber400,
                  value: focusMinutesStr,
                  label: l10n.groupFocus,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PodMetricChip(
                  icon: Icons.bolt_rounded,
                  iconColor: neural.cyan400,
                  value: karmaStr,
                  valueColor: neural.cyan300,
                  label: l10n.podKarma,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
