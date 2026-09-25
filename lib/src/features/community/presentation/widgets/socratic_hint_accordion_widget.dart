import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class SocraticHintAccordionWidget extends StatefulWidget {
  const SocraticHintAccordionWidget({
    required this.rawHintText,
    super.key,
  });

  final String rawHintText;

  @override
  State<SocraticHintAccordionWidget> createState() =>
      _SocraticHintAccordionWidgetState();
}

class _SocraticHintAccordionWidgetState
    extends State<SocraticHintAccordionWidget> {
  int _expandedTier = 1; // Level 1 open by default

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    final parsedTiers = _parseHintTiers(widget.rawHintText);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: neural.glassPanel,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: neural.cyan400.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: neural.cyan400.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: neural.cyan400,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYLLABOT SOCRATIC AI HINTS',
                    style: typography.caption.bold.copyWith(
                      color: neural.cyan400,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Progressive disclosure — reveal hints step-by-step',
                    style: typography.caption.regular.copyWith(
                      color: neural.slate400,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Level 1: Core Concept Clue
          _buildAccordionTier(
            tierLevel: 1,
            title: context.l10n.socraticHintLevel1,
            icon: Icons.lightbulb_outline_rounded,
            content: parsedTiers.level1,
            accentColor: neural.cyan400,
          ),
          const SizedBox(height: 8),

          // Level 2: Method & Strategy Direction
          _buildAccordionTier(
            tierLevel: 2,
            title: context.l10n.socraticHintLevel2,
            icon: Icons.explore_outlined,
            content: parsedTiers.level2,
            accentColor: neural.amber400,
          ),
          const SizedBox(height: 8),

          // Level 3: Formula & Pitfall Warning
          _buildAccordionTier(
            tierLevel: 3,
            title: context.l10n.socraticHintLevel3,
            icon: Icons.verified_outlined,
            content: parsedTiers.level3,
            accentColor: neural.emerald400,
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionTier({
    required int tierLevel,
    required String title,
    required IconData icon,
    required String content,
    required Color accentColor,
  }) {
    final neural = context.neural;
    final typography = context.typography;
    final isExpanded = _expandedTier >= tierLevel;

    return Container(
      decoration: BoxDecoration(
        color: neural.obsidian850.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? accentColor.withAlpha(120) : neural.hairlineSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShrinkableButton(
            onTap: () {
              AppFeedback.selection();
              setState(() {
                if (_expandedTier == tierLevel && tierLevel > 1) {
                  _expandedTier = tierLevel - 1;
                } else {
                  _expandedTier = tierLevel;
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: typography.caption.bold.copyWith(
                        color: isExpanded ? neural.slate100 : neural.slate300,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: neural.slate400,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                content,
                style: typography.footnote.regular.copyWith(
                  color: neural.slate200,
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  _ParsedHintTiers _parseHintTiers(String text) {
    var l1 = '';
    var l2 = '';
    var l3 = '';

    final lines = text.split('\n');
    var currentSection = 0;
    final b1 = StringBuffer();
    final b2 = StringBuffer();
    final b3 = StringBuffer();

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('core subject principle') || lower.contains('level 1')) {
        currentSection = 1;
        continue;
      } else if (lower.contains('concept breakdown') || lower.contains('level 2')) {
        currentSection = 2;
        continue;
      } else if (lower.contains('socratic checkpoint') || lower.contains('level 3')) {
        currentSection = 3;
        continue;
      }

      if (currentSection == 1) {
        b1.writeln(line);
      } else if (currentSection == 2) {
        b2.writeln(line);
      } else if (currentSection == 3) {
        b3.writeln(line);
      } else {
        b1.writeln(line);
      }
    }

    l1 = b1.toString().trim();
    l2 = b2.toString().trim();
    l3 = b3.toString().trim();

    if (l1.isEmpty) l1 = text;
    if (l2.isEmpty) l2 = 'Identify key variables and relationships in the problem statement.';
    if (l3.isEmpty) l3 = 'Apply standard formulas and verify units for dimensional consistency.';

    return _ParsedHintTiers(level1: l1, level2: l2, level3: l3);
  }
}

class _ParsedHintTiers {
  const _ParsedHintTiers({
    required this.level1,
    required this.level2,
    required this.level3,
  });

  final String level1;
  final String level2;
  final String level3;
}
