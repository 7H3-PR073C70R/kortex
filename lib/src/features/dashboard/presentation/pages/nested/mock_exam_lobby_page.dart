import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

@RoutePage()
class MockExamLobbyPage extends HookWidget {
  const MockExamLobbyPage({
    @PathParam('examId') required this.examId,
    required this.examName,
    super.key,
  });

  final String examId;
  final String examName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedMode = useState<String>('Standard Timed (CBT)');
    final isStarting = useState<bool>(false);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF090D16)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: 'Back to Dashboard',
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            onPressed: () => context.router.pop(),
          ),
        ),
        title: Text(
          'Exam Simulator Lobby',
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Exam Header Card
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(190)
                          : colors.surfacePrimary.withAlpha(230),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 100 : 70),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SyllabotAvatar(size: 36),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                examName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: typography.title3.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Simulate computer-based testing with dynamic '
                          'negative marking, question timers, and Syllabot AI '
                          'error diagnostics.',
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Select Simulation Mode',
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              _ModeOptionTile(
                title: 'Standard Timed (CBT)',
                subtitle:
                    '50 Questions · 60 Mins · Live Timer & Negative Marking',
                isSelected: selectedMode.value == 'Standard Timed (CBT)',
                onTap: () => selectedMode.value = 'Standard Timed (CBT)',
              ),
              const SizedBox(height: 10),

              _ModeOptionTile(
                title: 'Socratic Practice Mode',
                subtitle:
                    'Untimed · Instant Step-by-Step AI Solutions per question',
                isSelected: selectedMode.value == 'Socratic Practice Mode',
                onTap: () => selectedMode.value = 'Socratic Practice Mode',
              ),
              const SizedBox(height: 10),

              _ModeOptionTile(
                title: 'Weak Areas Targeted Drill',
                subtitle:
                    'Focused on concepts where your retention score is < 80%',
                isSelected: selectedMode.value == 'Weak Areas Targeted Drill',
                onTap: () => selectedMode.value = 'Weak Areas Targeted Drill',
              ),

              const Spacer(),

              // Start Button
              Semantics(
                button: true,
                label: 'Begin Exam Simulation',
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    isStarting.value = true;
                    Timer(const Duration(milliseconds: 700), () {
                      if (context.mounted) {
                        isStarting.value = false;
                        context.router.pop();
                      }
                    });
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.primary.withAlpha(200)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withAlpha(90),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: isStarting.value
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            'Begin Simulation Session',
                            style: typography.caption.bold.copyWith(
                              color: Colors.white,
                              fontSize: 14.5,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeOptionTile extends StatelessWidget {
  const _ModeOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title. $subtitle',
      child: ShrinkableButton(
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withAlpha(isDark ? 50 : 25)
                : (isDark
                      ? colors.surfaceSecondary.withAlpha(140)
                      : colors.surfacePrimary.withAlpha(200)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : (isDark
                        ? colors.surfaceBorderHighlight.withAlpha(60)
                        : colors.surfaceBorder.withAlpha(120)),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? colors.primary : colors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
