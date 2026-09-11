import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/focus_session_config.dart';
import 'package:kortex/src/features/decks/presentation/pages/focus_workspace_page.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class FocusModeSetupModal extends StatefulWidget {
  const FocusModeSetupModal({
    required this.decks,
    this.initialDeck,
    super.key,
  });

  final List<DeckEntity> decks;
  final DeckEntity? initialDeck;

  static Future<void> show(
    BuildContext context, {
    required List<DeckEntity> decks,
    DeckEntity? initialDeck,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FocusModeSetupModal(
        decks: decks,
        initialDeck: initialDeck,
      ),
    );
  }

  @override
  State<FocusModeSetupModal> createState() => _FocusModeSetupModalState();
}

class _FocusModeSetupModalState extends State<FocusModeSetupModal> {
  late DeckEntity? _selectedDeck;
  FocusSessionType _type = FocusSessionType.cardCount;
  int _cardCount = 10;
  int _durationMinutes = 10;
  bool _isSoftCatchUp = true;
  bool _ttsAutoRead = false;
  bool _hideCardCounter = false;

  @override
  void initState() {
    super.initState();
    _selectedDeck = widget.initialDeck ??
        (widget.decks.isNotEmpty ? widget.decks.first : null);
  }

  void _launchSession() {
    if (_selectedDeck == null) return;
    AppFeedback.celebration();

    final config = FocusSessionConfig(
      type: _type,
      targetCardCount: _cardCount,
      targetDurationMinutes: _durationMinutes,
      isSoftCatchUp: _isSoftCatchUp,
      ttsAutoRead: _ttsAutoRead,
      hideCardCounter: _hideCardCounter,
    );

    Navigator.of(context).pop();

    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FocusWorkspacePage(
            deckId: _selectedDeck!.id,
            deckTitle: _selectedDeck!.title,
            config: config,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hyperdrive Focus Mode',
                      style: typography.headline.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'ADHD-calibrated micro-sprints to beat task paralysis.',
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Deck Selector
          if (widget.decks.length > 1) ...[
            Text(
              'Select Deck',
              style: typography.caption.bold.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.surfaceBorder.withValues(alpha: 0.4),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DeckEntity>(
                  value: _selectedDeck,
                  isExpanded: true,
                  dropdownColor: colors.surfacePrimary,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colors.textSecondary,
                  ),
                  items: widget.decks.map((deck) {
                    return DropdownMenuItem<DeckEntity>(
                      value: deck,
                      child: Text(
                        '${deck.title} (${deck.totalCards} cards)',
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (deck) {
                    if (deck != null) setState(() => _selectedDeck = deck);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Sprint Type Selector (Cards vs Timed)
          Row(
            children: [
              Expanded(
                child: _OptionChip(
                  label: 'Card Sprint',
                  icon: Icons.layers_rounded,
                  isSelected: _type == FocusSessionType.cardCount,
                  onTap: () => setState(() => _type = FocusSessionType.cardCount),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OptionChip(
                  label: 'Timed Focus',
                  icon: Icons.timer_outlined,
                  isSelected: _type == FocusSessionType.timed,
                  onTap: () => setState(() => _type = FocusSessionType.timed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sizing choices (5 / 10 / 15)
          if (_type == FocusSessionType.cardCount) ...[
            Row(
              children: [5, 10, 15].map((count) {
                final isSelected = _cardCount == count;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ShrinkableButton(
                      onTap: () {
                        AppFeedback.selection();
                        setState(() => _cardCount = count);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : colors.surfaceBorder.withValues(alpha: 0.4),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$count Cards',
                          style: typography.caption.bold.copyWith(
                            color: isSelected ? Colors.white : colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Row(
              children: [5, 10, 15].map((mins) {
                final isSelected = _durationMinutes == mins;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ShrinkableButton(
                      onTap: () {
                        AppFeedback.selection();
                        setState(() => _durationMinutes = mins);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : colors.surfaceBorder.withValues(alpha: 0.4),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$mins Mins',
                          style: typography.caption.bold.copyWith(
                            color: isSelected ? Colors.white : colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),

          // ADHD Enhancements Toggles
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _FeatureSwitchTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Soft Catch-Up Rescuer',
                  subtitle: '60% quick dopamine wins + 40% priority cards to eliminate paralysis.',
                  value: _isSoftCatchUp,
                  onChanged: (v) => setState(() => _isSoftCatchUp = v),
                ),
                const Divider(height: 16),
                _FeatureSwitchTile(
                  icon: Icons.record_voice_over_rounded,
                  title: 'Read Aloud (TTS)',
                  subtitle: 'Engage multi-sensory attention with spoken card prompts.',
                  value: _ttsAutoRead,
                  onChanged: (v) => setState(() => _ttsAutoRead = v),
                ),
                const Divider(height: 16),
                _FeatureSwitchTile(
                  icon: Icons.visibility_off_rounded,
                  title: 'Hide Clock / Counter',
                  subtitle: 'Alleviate timer panic and rejection-sensitivity anxiety.',
                  value: _hideCardCounter,
                  onChanged: (v) => setState(() => _hideCardCounter = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Launch Button
          ShrinkableButton(
            onTap: _selectedDeck != null ? _launchSession : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Start Hyperdrive Sprint',
                    style: typography.body.medium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return ShrinkableButton(
      onTap: () {
        AppFeedback.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.15)
              : colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: isSelected ? colors.primary : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureSwitchTile extends StatelessWidget {
  const _FeatureSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typography.caption.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: colors.primary,
          onChanged: (v) {
            AppFeedback.selection();
            onChanged(v);
          },
        ),
      ],
    );
  }
}
