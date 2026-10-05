import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/export/services/anki_export_service.dart';
import 'package:kortex/src/shared/export/services/notion_csv_formatter.dart';
import 'package:kortex/src/shared/export/services/pdf_printable_generator.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportDeckModalSheet extends StatefulWidget {
  const ExportDeckModalSheet({
    required this.deck,
    this.ankiExportService = const AnkiExportService(),
    this.pdfGenerator = const PdfPrintableGenerator(),
    this.notionFormatter = const NotionCsvFormatter(),
    super.key,
  });

  final DeckEntity deck;
  final AnkiExportService ankiExportService;
  final PdfPrintableGenerator pdfGenerator;
  final NotionCsvFormatter notionFormatter;

  static Future<void> show(
    BuildContext context, {
    required DeckEntity deck,
  }) {
    return AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 600,
      builder: (_) => ExportDeckModalSheet(deck: deck),
    );
  }

  @override
  State<ExportDeckModalSheet> createState() => _ExportDeckModalSheetState();
}

class _ExportDeckModalSheetState extends State<ExportDeckModalSheet> {
  bool _isExporting = false;
  String? _exportMessage;

  Future<void> _exportAnki() async {
    final guard = locator.isRegistered<SubscriptionGuard>()
        ? locator<SubscriptionGuard>()
        : SubscriptionGuard();
    if (!guard.canExportDeck(DeckExportFormat.anki)) {
      final canExport = await guard.requirePro(
        context,
        featureName: 'Anki Deck Export',
      );
      if (!canExport || !mounted) return;
    }

    setState(() {
      _isExporting = true;
      _exportMessage = 'Formatting Anki package...';
    });

    try {
      final csv = widget.ankiExportService.generateAnkiCsv(widget.deck);
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = widget.deck.title.replaceAll(RegExp(r'\W+'), '_');
      final file = File('${tempDir.path}/${sanitizedTitle}_anki.txt');
      await file.writeAsString(csv);

      if (mounted) {
        Navigator.of(context).pop();
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: '${widget.deck.title} - Anki Deck',
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        context.showSnackBar(
          message: 'Failed to export to Anki: $e',
          type: SnackBarType.error,
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf() async {
    final guard = locator.isRegistered<SubscriptionGuard>()
        ? locator<SubscriptionGuard>()
        : SubscriptionGuard();
    if (!guard.canExportDeck(DeckExportFormat.pdfPrintable)) {
      final canExport = await guard.requirePro(
        context,
        featureName: 'Printable PDF Cram Sheets',
      );
      if (!canExport || !mounted) return;
    }

    setState(() {
      _isExporting = true;
      _exportMessage = 'Rendering printable flashcards PDF...';
    });

    try {
      final bytes = await widget.pdfGenerator.generatePrintableDeckPdf(
        widget.deck,
      );
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = widget.deck.title.replaceAll(RegExp(r'\W+'), '_');
      final file = File('${tempDir.path}/${sanitizedTitle}_cards.pdf');
      await file.writeAsBytes(bytes);

      if (mounted) {
        Navigator.of(context).pop();
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: '${widget.deck.title} - PDF Cards',
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        context.showSnackBar(
          message: 'Failed to generate PDF: $e',
          type: SnackBarType.error,
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportNotion() async {
    setState(() {
      _isExporting = true;
      _exportMessage = 'Building Notion-compatible table...';
    });

    try {
      final csv = widget.notionFormatter.generateNotionCsv(widget.deck);
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = widget.deck.title.replaceAll(RegExp(r'\W+'), '_');
      final file = File('${tempDir.path}/${sanitizedTitle}_notion.csv');
      await file.writeAsString(csv);

      if (mounted) {
        Navigator.of(context).pop();
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: '${widget.deck.title} - Notion Table',
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        context.showSnackBar(
          message: 'Failed to export Notion CSV: $e',
          type: SnackBarType.error,
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportJson() async {
    final guard = locator.isRegistered<SubscriptionGuard>()
        ? locator<SubscriptionGuard>()
        : SubscriptionGuard();
    if (!guard.canExportDeck(DeckExportFormat.json)) {
      final canExport = await guard.requirePro(
        context,
        featureName: 'Structured JSON Deck Export',
      );
      if (!canExport || !mounted) return;
    }

    setState(() {
      _isExporting = true;
      _exportMessage = 'Packaging structured JSON archive...';
    });

    try {
      final bytes = widget.ankiExportService.generateAnkiJsonExportBytes(widget.deck);
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = widget.deck.title.replaceAll(RegExp(r'\W+'), '_');
      final file = File('${tempDir.path}/${sanitizedTitle}_package.json');
      await file.writeAsBytes(bytes);

      if (mounted) {
        Navigator.of(context).pop();
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: '${widget.deck.title} - Structured Deck Package',
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        context.showSnackBar(
          message: 'Failed to export JSON package: $e',
          type: SnackBarType.error,
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareDynamicLink() async {
    Navigator.of(context).pop();
    await locator<LinkSharingService>().shareDeck(
      deckId: widget.deck.id,
      title: widget.deck.title,
      description: widget.deck.description,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final guard = locator.isRegistered<SubscriptionGuard>()
        ? locator<SubscriptionGuard>()
        : SubscriptionGuard();
    final isPro = guard.isPro;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);
    final isDark = context.isDarkMode;

    return Align(
      alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: isDesktop
                ? BorderRadius.circular(AppRadius.dialog)
                : const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            boxShadow: isDesktop
                ? [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 80 : 30),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.exportDeckTitle,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: colors.textSecondary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isExporting) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const AppLogoLoader(size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _exportMessage ?? l10n.exportingFile,
                    style: typography.body.regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _ExportOptionTile(
              icon: Icons.share_location_rounded,
              iconColor: colors.primary,
              title: 'Share Dynamic Link',
              subtitle: 'Generate cross-platform link to open or study deck directly',
              onTap: () {
                unawaited(_shareDynamicLink());
              },
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              icon: Icons.flash_on_rounded,
              iconColor: colors.info,
              title: l10n.exportAnkiTitle,
              subtitle: l10n.exportAnkiSubtitle,
              isPro: !isPro,
              onTap: () {
                unawaited(_exportAnki());
              },
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              icon: Icons.print_rounded,
              iconColor: colors.success,
              title: l10n.exportPdfTitle,
              subtitle: l10n.exportPdfSubtitle,
              isPro: !isPro,
              onTap: () {
                unawaited(_exportPdf());
              },
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              icon: Icons.view_headline_rounded,
              iconColor: colors.warning,
              title: l10n.exportNotionTitle,
              subtitle: l10n.exportNotionSubtitle,
              onTap: () {
                unawaited(_exportNotion());
              },
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              icon: Icons.code_rounded,
              iconColor: colors.primary,
              title: 'Structured JSON Package',
              subtitle: 'Export complete metadata, formulas, and FSRS metrics',
              isPro: !isPro,
              onTap: () {
                unawaited(_exportJson());
              },
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPro = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = context.colors;
    final typography = context.typography;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.textMuted.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: typography.callout.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (isPro) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primary,
                                colors.primary.withAlpha(200),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PRO',
                            style: typography.caption.bold.copyWith(
                              color: Colors.white,
                              fontSize: 8.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
