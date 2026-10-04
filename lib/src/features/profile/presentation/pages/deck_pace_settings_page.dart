import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/models/fsrs_user_settings.dart';
import 'package:kortex/src/features/decks/domain/services/fsrs_settings_sync_service.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Dedicated profile page for configuring Deck Pace and FSRS-6 algorithm parameters.
@RoutePage()
class DeckPaceSettingsPage extends StatefulWidget {
  const DeckPaceSettingsPage({super.key});

  @override
  State<DeckPaceSettingsPage> createState() => _DeckPaceSettingsPageState();
}

class _DeckPaceSettingsPageState extends State<DeckPaceSettingsPage> {
  final _syncService = const FsrsSettingsSyncService();

  late DeckPacePreset _selectedPreset;
  late double _desiredRetention;
  late TimeOfDay _reminderTime;
  late int _newCardsPerDay;
  late int _maxReviewsPerDay;
  late bool _isSoftCatchUpEnabled;
  late bool _remindersEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final current = _syncService.load();
    _selectedPreset = current.pacePreset;
    _desiredRetention = current.clampedRetention;
    _reminderTime = current.preferredReminderTime;
    _newCardsPerDay = current.newCardsPerDay;
    _maxReviewsPerDay = current.maxReviewsPerDay;
    _isSoftCatchUpEnabled = current.isSoftCatchUpEnabled;
    _remindersEnabled = current.remindersEnabled;
  }

  void _applyPreset(DeckPacePreset preset) {
    AppFeedback.selection();
    setState(() {
      _selectedPreset = preset;
      if (preset != DeckPacePreset.custom) {
        _desiredRetention = preset.targetRetention;
        _newCardsPerDay = preset.defaultNewCards;
        _maxReviewsPerDay = preset.defaultMaxReviews;
      }
    });
  }

  Future<void> _saveSettings() async {
    AppFeedback.medium();
    setState(() => _isSaving = true);

    final settings = FsrsUserSettings(
      pacePreset: _selectedPreset,
      desiredRetention: _desiredRetention,
      preferredReminderHour: _reminderTime.hour,
      preferredReminderMinute: _reminderTime.minute,
      newCardsPerDay: _newCardsPerDay,
      maxReviewsPerDay: _maxReviewsPerDay,
      isSoftCatchUpEnabled: _isSoftCatchUpEnabled,
      remindersEnabled: _remindersEnabled,
    );

    final success = await _syncService.save(settings);

    if (!mounted) return;
    setState(() => _isSaving = false);

    context.showSnackBar(
      message: success
          ? 'Deck Study Pace updated & synced across devices! 🎯'
          : 'Deck Study Pace saved locally.',
      type: success ? SnackBarType.success : SnackBarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final retentionPercent = (_desiredRetention * 100).round();
    final intervalMultiplier =
        (0.90 / _desiredRetention).clamp(0.5, 2.0).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Deck Study Pace',
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [colors.surfaceSecondary, colors.surfaceTertiary]
                          : [colors.surfacePrimary, colors.surfaceSecondary],
                    ),
                    borderRadius: AppRadius.radiusPanel,
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withValues(alpha: 0.18),
                        ),
                        child: Icon(
                          Icons.speed_rounded,
                          color: colors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Memory Spacing & Review Limits',
                              style: typography.body.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Configure daily review workload, target memory retention, and study reminder schedules in one place.',
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Pace Profile Selector Label
                Text(
                  'PACING PRESETS',
                  style: typography.caption.bold.copyWith(
                    color: colors.textMuted,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Preset Cards Grid
                ...DeckPacePreset.values.map((preset) {
                  final isSelected = _selectedPreset == preset;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return AnimatedScale(
                          scale: isHovered ? 1.01 : 1.0,
                          duration: AppMotion.snappy,
                          curve: Curves.easeOutCubic,
                          child: child,
                        );
                      },
                      child: ShrinkableButton(
                        onTap: () => _applyPreset(preset),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                                : colors.surfacePrimary,
                            borderRadius: AppRadius.radiusCard,
                            border: Border.all(
                              color: isSelected
                                  ? colors.primary
                                  : colors.surfaceBorder.withValues(alpha: 0.5),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: isSelected
                                    ? colors.primary
                                    : colors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      preset.displayName,
                                      style: typography.body.bold.copyWith(
                                        color: isSelected
                                            ? colors.primary
                                            : colors.textPrimary,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      preset.description,
                                      style: typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),

                // 4. Detailed Tuning Section
                Text(
                  'ALGORITHM & WORKLOAD BOUNDS',
                  style: typography.caption.bold.copyWith(
                    color: colors.textMuted,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surfacePrimary,
                    borderRadius: AppRadius.radiusPanel,
                    border: Border.all(color: colors.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target Retention Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Target Recall Retention Rate',
                              style: typography.body.medium.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$retentionPercent%',
                            style: typography.title3.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Slider(
                        value: _desiredRetention,
                        min: 0.80,
                        max: 0.97,
                        divisions: 17,
                        label: '$retentionPercent%',
                        activeColor: colors.primary,
                        onChanged: (val) {
                          setState(() {
                            _desiredRetention = val;
                            _selectedPreset = DeckPacePreset.custom;
                          });
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '80% (Fewer Reviews)',
                            style: typography.caption.medium.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          Text(
                            '97% (Maximum Mastery)',
                            style: typography.caption.medium.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Review Frequency: ${intervalMultiplier}x of standard pace',
                        style: typography.footnote.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const Divider(height: 28),

                      // New Cards Per Day
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily New Cards Target',
                            style: typography.body.medium.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'New flashcards introduced daily per deck',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSecondary,
                              borderRadius: AppRadius.radiusCard,
                              border: Border.all(
                                color: colors.surfaceBorder.withValues(alpha: 0.5),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _newCardsPerDay,
                                isExpanded: true,
                                dropdownColor: colors.surfacePrimary,
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: colors.textSecondary,
                                ),
                                items: [5, 10, 15, 20, 30, 40, 50, 100].map((count) {
                                  return DropdownMenuItem<int>(
                                    value: count,
                                    child: Text(
                                      '$count / day',
                                      style: typography.body.medium.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _newCardsPerDay = val;
                                      _selectedPreset = DeckPacePreset.custom;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),

                      // Max Reviews Per Day
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Review Cap',
                            style: typography.body.medium.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Maximum review cards due per deck daily',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSecondary,
                              borderRadius: AppRadius.radiusCard,
                              border: Border.all(
                                color: colors.surfaceBorder.withValues(alpha: 0.5),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _maxReviewsPerDay,
                                isExpanded: true,
                                dropdownColor: colors.surfacePrimary,
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: colors.textSecondary,
                                ),
                                items: [25, 50, 100, 150, 200, 300, 500].map((cap) {
                                  return DropdownMenuItem<int>(
                                    value: cap,
                                    child: Text(
                                      '$cap / day',
                                      style: typography.body.medium.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _maxReviewsPerDay = val;
                                      _selectedPreset = DeckPacePreset.custom;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),

                      // Soft Catch-up Toggle
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Soft Catch-Up Rescuer',
                                  style: typography.body.medium.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '60% easy wins + 40% priority cards to prevent backlog paralysis',
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _isSoftCatchUpEnabled,
                            activeTrackColor: colors.primary,
                            onChanged: (v) {
                              AppFeedback.selection();
                              setState(() => _isSoftCatchUpEnabled = v);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Daily Reminder Schedule
                Text(
                  'DAILY REMINDER SCHEDULE',
                  style: typography.caption.bold.copyWith(
                    color: colors.textMuted,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfacePrimary,
                    borderRadius: AppRadius.radiusPanel,
                    border: Border.all(color: colors.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Review Reminders',
                                  style: typography.body.medium.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Receive study push notifications when flashcards are due',
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _remindersEnabled,
                            activeTrackColor: colors.primary,
                            onChanged: (v) {
                              AppFeedback.selection();
                              setState(() => _remindersEnabled = v);
                            },
                          ),
                        ],
                      ),
                      if (_remindersEnabled) ...[
                        const Divider(height: 20),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.schedule_rounded,
                            color: colors.primary,
                          ),
                          title: Text(
                            'Preferred Reminder Time',
                            style: typography.body.medium.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _reminderTime.format(context),
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                          ),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _reminderTime,
                            );
                            if (picked != null) {
                              setState(() => _reminderTime = picked);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 6. Save Action Button
                ShrinkableButton(
                  key: const Key('save_deck_pace_button'),
                  onTap: _isSaving ? null : _saveSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: AppRadius.radiusCard,
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withValues(
                            alpha: isDark ? 0.3 : 0.1,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save & Sync Deck Pace',
                            style: typography.body.bold.copyWith(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
