import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/models/fsrs_user_settings.dart';
import 'package:kortex/src/features/decks/domain/services/fsrs_settings_sync_service.dart';

/// Modal bottom sheet allowing scholars to customize FSRS-6 algorithm parameters
/// (target retention rate, daily study reminder time, and interval scaling).
class FsrsParameterTuningSheet extends StatefulWidget {
  const FsrsParameterTuningSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FsrsParameterTuningSheet(),
    );
  }

  @override
  State<FsrsParameterTuningSheet> createState() =>
      _FsrsParameterTuningSheetState();
}

class _FsrsParameterTuningSheetState extends State<FsrsParameterTuningSheet> {
  final _syncService = const FsrsSettingsSyncService();
  late double _desiredRetention;
  late TimeOfDay _reminderTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final current = _syncService.load();
    _desiredRetention = current.clampedRetention;
    _reminderTime = current.preferredReminderTime;
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final settings = FsrsUserSettings(
      desiredRetention: _desiredRetention,
      preferredReminderHour: _reminderTime.hour,
      preferredReminderMinute: _reminderTime.minute,
    );

    final success = await _syncService.save(settings);
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'FSRS parameters updated & synced with server! 🎯'
              : 'FSRS parameters saved locally.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final retentionPercent = (_desiredRetention * 100).round();
    // Approximate FSRS interval multiplier relative to 90% baseline
    final intervalMultiplier =
        (0.90 / _desiredRetention).clamp(0.5, 2.0).toStringAsFixed(2);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 60 : 30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.surfaceBorder,
                borderRadius: BorderRadius.circular(AppRadius.micro),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.tune_rounded, color: colors.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                'FSRS-6 Algorithm Tuning',
                style: typography.title2.bold.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Configure your desired active-recall retention probability and daily review schedule.',
            style: typography.caption.medium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Retention Slider Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceBorder.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: colors.surfaceBorder.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Target Retention Rate',
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      '$retentionPercent%',
                      style: typography.title3.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _desiredRetention,
                  min: 0.80,
                  max: 0.97,
                  divisions: 17,
                  label: '$retentionPercent%',
                  activeColor: colors.primary,
                  onChanged: (val) {
                    setState(() => _desiredRetention = val);
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
                const SizedBox(height: 8),
                Text(
                  'Interval Scale Factor: ${intervalMultiplier}x relative to baseline',
                  style: typography.footnote.medium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daily Review Reminder Time
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: BorderSide(color: colors.surfaceBorder.withAlpha(40)),
            ),
            tileColor: colors.surfaceBorder.withAlpha(isDark ? 30 : 15),
            leading: Icon(Icons.schedule_rounded, color: colors.primary),
            title: Text(
              'Preferred Daily Reminder',
              style: typography.body.medium.copyWith(color: colors.textPrimary),
            ),
            subtitle: Text(
              _reminderTime.format(context),
              style: typography.caption.bold.copyWith(color: colors.primary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Save FSRS Parameters',
                      style: typography.body.bold.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
