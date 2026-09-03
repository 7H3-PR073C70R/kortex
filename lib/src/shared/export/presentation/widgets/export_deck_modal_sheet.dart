import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/export/services/anki_export_service.dart';
import 'package:kortex/src/shared/export/services/notion_csv_formatter.dart';
import 'package:kortex/src/shared/export/services/pdf_printable_generator.dart';
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
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
            subject: 'Anki Export: ${widget.deck.title}',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    setState(() {
      _isExporting = true;
      _exportMessage = 'Rendering printable A4 sheet...';
    });

    try {
      final pdfBytes = await widget.pdfGenerator.generatePrintableDeckPdf(
        widget.deck,
      );
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = widget.deck.title.replaceAll(RegExp(r'\W+'), '_');
      final file = File('${tempDir.path}/${sanitizedTitle}_cards.pdf');
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        Navigator.of(context).pop();
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Printable Flashcards: ${widget.deck.title}',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportNotion() async {
    setState(() {
      _isExporting = true;
      _exportMessage = 'Formatting Notion database CSV...';
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
            subject: 'Notion Database CSV: ${widget.deck.title}',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
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
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _exportMessage ?? l10n.exportingFile,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _ExportOptionTile(
              icon: Icons.flash_on_rounded,
              iconColor: Colors.blueAccent,
              title: l10n.exportAnkiTitle,
              subtitle: l10n.exportAnkiSubtitle,
              onTap: () {
                unawaited(_exportAnki());
              },
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              icon: Icons.print_rounded,
              iconColor: Colors.greenAccent,
              title: l10n.exportPdfTitle,
              subtitle: l10n.exportPdfSubtitle,
              onTap: () {
                unawaited(_exportPdf());
              },
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              icon: Icons.view_headline_rounded,
              iconColor: Colors.amberAccent,
              title: l10n.exportNotionTitle,
              subtitle: l10n.exportNotionSubtitle,
              onTap: () {
                unawaited(_exportNotion());
              },
            ),
          ],
        ],
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
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
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
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
