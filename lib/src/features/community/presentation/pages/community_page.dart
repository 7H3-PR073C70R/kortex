import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

@RoutePage()
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_alt_rounded,
            size: 48,
            color: colors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Community',
            style: typography.title1.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
