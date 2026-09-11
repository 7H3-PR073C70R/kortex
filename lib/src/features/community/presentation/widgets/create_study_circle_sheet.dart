import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CreateStudyCircleSheet extends HookWidget {
  const CreateStudyCircleSheet({
    required this.onSubmit,
    this.initialTrack = 'General',
    super.key,
  });

  final void Function({
    required String name,
    required String track,
    required int targetWeeklyMinutes,
  }) onSubmit;
  final String initialTrack;

  static Future<void> show(
    BuildContext context, {
    required void Function({
      required String name,
      required String track,
      required int targetWeeklyMinutes,
    }) onSubmit,
    String initialTrack = 'General',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateStudyCircleSheet(
        onSubmit: onSubmit,
        initialTrack: initialTrack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    final nameController = useTextEditingController();
    final selectedTrack = useState<String>(initialTrack);
    final targetMinutes = useState<int>(600);

    const tracks = ['WAEC', 'JAMB', 'SAT', 'University', 'STEM', 'General'];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? colors.surfacePrimary : colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.diversity_3_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.createStudyCircleTitle,
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.studyCircleMicroPodsSubtitle,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Pod Name input
            Text(
              l10n.circleNameLabel,
              style: typography.caption.bold.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: l10n.circleNameHint,
                hintStyle: typography.body.regular.copyWith(
                  color: colors.textSecondary.withAlpha(120),
                ),
                filled: true,
                fillColor: isDark
                    ? colors.surfaceSecondary
                    : colors.surfaceSecondary.withAlpha(50),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Track Selection Chips
            Text(
              l10n.academicTrackLabel,
              style: typography.caption.bold.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: tracks.map((track) {
                final isSelected = selectedTrack.value == track;
                return ChoiceChip(
                  label: Text(track),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) selectedTrack.value = track;
                  },
                  selectedColor: colors.primary,
                  labelStyle: typography.caption.bold.copyWith(
                    color: isSelected ? colors.white : colors.textPrimary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Target Hours Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.weeklyTargetLabel,
                  style: typography.caption.bold.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  l10n.weeklyTargetHoursAndMins(
                    (targetMinutes.value / 60).toStringAsFixed(1),
                    targetMinutes.value,
                  ),
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: targetMinutes.value.toDouble(),
              min: 120,
              max: 1800,
              divisions: 14,
              activeColor: colors.primary,
              onChanged: (val) => targetMinutes.value = val.toInt(),
            ),
            const SizedBox(height: 20),

            // Submit Button
            ShrinkableButton(
              onTap: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  onSubmit(
                    name: name,
                    track: selectedTrack.value,
                    targetWeeklyMinutes: targetMinutes.value,
                  );
                  Navigator.pop(context);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    l10n.launchStudyCircleAction,
                    style: typography.footnote.bold.copyWith(
                      color: colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
