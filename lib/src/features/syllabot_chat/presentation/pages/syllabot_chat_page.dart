import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

@RoutePage()
class SyllabotChatPage extends StatelessWidget {
  const SyllabotChatPage({this.initialPrompt, super.key});

  final String? initialPrompt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 48,
            color: colors.syllabotAccent,
          ),
          const SizedBox(height: 16),
          Text(
            'Syllabot AI',
            style: typography.title1.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
