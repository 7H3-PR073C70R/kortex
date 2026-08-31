import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

@RoutePage()
class DecksPage extends StatelessWidget {
  const DecksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.style_rounded,
            size: 48,
            color: colors.latexHighlight,
          ),
          const SizedBox(height: 16),
          Text(
            'Study Decks',
            style: typography.title1.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
