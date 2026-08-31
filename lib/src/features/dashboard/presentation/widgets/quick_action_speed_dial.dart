import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class QuickActionSpeedDial extends StatelessWidget {
  const QuickActionSpeedDial({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Semantics(
      container: true,
      label:
          'Quick action bar: Upload PDF, create active recall deck, '
          'or start AI study chat',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(190)
                  : colors.surfacePrimary.withAlpha(225),
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(80)
                    : colors.surfaceBorder.withAlpha(140),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 50 : 12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionItem(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload Notes',
                  color: colors.primary,
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    _showUploadBottomSheet(context);
                  },
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: isDark
                      ? colors.surfaceBorderHighlight.withAlpha(60)
                      : colors.surfaceBorder.withAlpha(120),
                ),
                _ActionItem(
                  icon: Icons.add_to_photos_rounded,
                  label: 'New Deck',
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    unawaited(context.router.push(const DecksRoute()));
                  },
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: isDark
                      ? colors.surfaceBorderHighlight.withAlpha(60)
                      : colors.surfaceBorder.withAlpha(120),
                ),
                _ActionItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Partner',
                  color: colors.syllabotAccent,
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    unawaited(context.router.push(SyllabotChatRoute()));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUploadBottomSheet(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(240)
                      : colors.surfacePrimary.withAlpha(245),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(80)
                        : colors.surfaceBorder.withAlpha(140),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textMuted.withAlpha(100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'Ingest Study Material',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Drop lecture slides, PDFs or handwritten past papers. '
                      'Syllabot will parse STEM OCR & generate flashcards.',
                      textAlign: TextAlign.center,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Upload options
                    Row(
                      children: [
                        Expanded(
                          child: _UploadOptionCard(
                            icon: Icons.picture_as_pdf_rounded,
                            title: 'Upload PDF',
                            subtitle: 'Lecture Slides',
                            onTap: () {
                              Navigator.of(context).pop();
                              unawaited(
                                context.router.push(
                                  SyllabotChatRoute(
                                    initialPrompt:
                                        'I want to parse a PDF lecture slide.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _UploadOptionCard(
                            icon: Icons.camera_alt_rounded,
                            title: 'Scan Notes',
                            subtitle: 'STEM OCR',
                            onTap: () {
                              Navigator.of(context).pop();
                              unawaited(
                                context.router.push(
                                  SyllabotChatRoute(
                                    initialPrompt:
                                        'I want to scan handwritten notes.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Semantics(
      button: true,
      label: label,
      child: ShrinkableButton(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadOptionCard extends StatelessWidget {
  const _UploadOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfacePrimary.withAlpha(160)
              : colors.surfaceSecondary.withAlpha(160),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 80 : 50),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: colors.primary),
            const SizedBox(height: 8),
            Text(
              title,
              style: typography.caption.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: typography.footnote.regular.copyWith(
                color: colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
