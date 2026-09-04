import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// An interactive Floating Action Button that seamlessly expands into a full
/// modal composer for creating community forum posts, and collapses smoothly
/// back into the floating action button when dismissed or submitted.
class ExpandableCreatePostFab extends HookWidget {
  const ExpandableCreatePostFab({
    required this.onSubmit,
    this.bottomOffset = 96,
    super.key,
  });

  final void Function({
    required String title,
    required String content,
    required String track,
    String? latexContent,
  })
  onSubmit;

  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isExpanded = useState<bool>(false);
    final expandController = useAnimationController(
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 250),
    );

    final expandAnimation = useMemoized(
      () => CurvedAnimation(
        parent: expandController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      [expandController],
    );

    final titleController = useTextEditingController();
    final contentController = useTextEditingController();
    final latexController = useTextEditingController();
    final selectedTrack = useState<String>('WAEC');

    const tracks = [
      'WAEC',
      'JAMB',
      'SAT',
      'Engineering',
      'Medicine',
      'General',
    ];

    void expand() {
      unawaited(HapticFeedback.mediumImpact());
      isExpanded.value = true;
      unawaited(expandController.forward());
    }

    void collapse() {
      unawaited(HapticFeedback.lightImpact());
      unawaited(
        expandController.reverse().then((_) {
          isExpanded.value = false;
          titleController.clear();
          contentController.clear();
          latexController.clear();
        }),
      );
    }

    return Stack(
      children: [
        // 1. Backdrop Filter Overlay (Active when expanded)
        if (isExpanded.value)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: expandAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: expandAnimation.value,
                  child: GestureDetector(
                    onTap: collapse,
                    behavior: HitTestBehavior.opaque,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 8 * expandAnimation.value,
                        sigmaY: 8 * expandAnimation.value,
                      ),
                      child: Container(
                        color: Colors.black.withAlpha(
                          (isDark ? 140 : 90 * expandAnimation.value).toInt(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // 2. Collapsed Floating Action Button
        if (!isExpanded.value || expandAnimation.value < 0.9)
          Positioned(
            right: 18,
            bottom: bottomOffset,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(
                CurvedAnimation(
                  parent: expandController,
                  curve: const Interval(0, 0.4, curve: Curves.easeOut),
                ),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 1, end: 0.7).animate(
                  CurvedAnimation(
                    parent: expandController,
                    curve: const Interval(0, 0.4, curve: Curves.easeOut),
                  ),
                ),
                child: ShrinkableButton(
                  onTap: expand,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          colors.primary.withAlpha(220),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withAlpha(isDark ? 90 : 60),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 70 : 25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withAlpha(40),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.createPostButton,
                          style: typography.footnote.bold.copyWith(
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 3. Expanded Modal Composer (Morphs smoothly into view)
        if (isExpanded.value)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            child: AnimatedBuilder(
              animation: expandAnimation,
              builder: (context, child) {
                final scale = Tween<double>(
                  begin: 0.85,
                  end: 1,
                ).evaluate(expandAnimation);
                final opacity = Tween<double>(
                  begin: 0,
                  end: 1,
                ).evaluate(expandAnimation);
                final slideY = Tween<double>(
                  begin: 40,
                  end: 0,
                ).evaluate(expandAnimation);

                return Transform.translate(
                  offset: Offset(0, slideY),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.bottomRight,
                    child: Opacity(
                      opacity: opacity,
                      child: child,
                    ),
                  ),
                );
              },
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.78,
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfacePrimary.withAlpha(245)
                      : colors.surfacePrimary,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 80 : 50),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 120 : 40),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grabber & Header Row
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
                                  Icons.edit_note_rounded,
                                  color: colors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.createPostButton,
                                style: typography.title3.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: colors.textSecondary,
                            ),
                            onPressed: collapse,
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Track Selection Chips
                      Text(
                        l10n.selectTrackHint,
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: tracks.map((track) {
                          final isSelected = selectedTrack.value == track;
                          return ChoiceChip(
                            label: Text(track),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) {
                                unawaited(HapticFeedback.lightImpact());
                                selectedTrack.value = track;
                              }
                            },
                            selectedColor: colors.primary.withAlpha(40),
                            labelStyle: typography.caption.bold.copyWith(
                              color: isSelected
                                  ? colors.primary
                                  : colors.textSecondary,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Title Field
                      AppTextField(
                        controller: titleController,
                        hintText: l10n.postTitleHint,
                      ),
                      const SizedBox(height: 10),

                      // Content Field
                      AppTextField(
                        controller: contentController,
                        hintText: l10n.postContentHint,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 10),

                      // Optional LaTeX Field
                      AppTextField(
                        controller: latexController,
                        hintText:
                            r'Optional LaTeX formula (e.g. \int x^2 dx = \frac{x^3}{3})',
                      ),
                      const SizedBox(height: 18),

                      // Action Row: Cancel & Submit
                      Row(
                        children: [
                          Expanded(
                            child: ShrinkableButton(
                              onTap: collapse,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: colors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colors.primary.withAlpha(20),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    l10n.cancelAction,
                                    style: typography.footnote.bold.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ShrinkableButton(
                              onTap: () {
                                final title = titleController.text.trim();
                                final content = contentController.text.trim();
                                if (title.isEmpty || content.isEmpty) return;

                                unawaited(HapticFeedback.mediumImpact());
                                onSubmit(
                                  title: title,
                                  content: content,
                                  track: selectedTrack.value,
                                  latexContent:
                                      latexController.text.trim().isNotEmpty
                                          ? latexController.text.trim()
                                          : null,
                                );
                                collapse();
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.primary,
                                      colors.primary.withAlpha(220),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary
                                          .withAlpha(isDark ? 80 : 50),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.createPostButton,
                                        style:
                                            typography.footnote.bold.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
