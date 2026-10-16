import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// KPI metric chip displayed inside the Pod Pulse header.
class PodMetricChip extends StatelessWidget {
  const PodMetricChip({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.valueColor,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: neural.obsidian850.withAlpha(153),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neural.hairlineSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.bold.copyWith(
                    color: valueColor ?? neural.slate300,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.caption.regular.copyWith(
              color: neural.slate400,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
