import 'dart:typed_data';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfPrintableGenerator {
  const PdfPrintableGenerator();

  /// Builds a print-ready A4 PDF with 8 flashcards per page
  /// (2 columns x 4 rows). Double-sided alignment: Fronts on odd pages,
  /// Backs on even pages.
  Future<Uint8List> generatePrintableDeckPdf(DeckEntity deck) async {
    final pdf = pw.Document(
      title: '${deck.title} - Printable Flashcards',
      author: 'Kortex Academic Workspace',
    );

    const cardsPerPage = 8;
    final totalCards = deck.cards.length;

    for (var i = 0; i < totalCards; i += cardsPerPage) {
      final pageCards = deck.cards.sublist(
        i,
        (i + cardsPerPage > totalCards) ? totalCards : i + cardsPerPage,
      );

      final paddedCards = List<FlashcardEntity?>.from(pageCards);
      while (paddedCards.length < cardsPerPage) {
        paddedCards.add(null);
      }

      // Page 1: Fronts (8 cards in 2x4 grid)
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (context) {
            return _buildCardGrid(
              cards: paddedCards,
              isFront: true,
              deckTitle: deck.title,
            );
          },
        ),
      );

      // Page 2: Backs (mirrored columns for double-sided flip on long edge)
      final mirroredBackCards = <FlashcardEntity?>[
        paddedCards[1], paddedCards[0],
        paddedCards[3], paddedCards[2],
        paddedCards[5], paddedCards[4],
        paddedCards[7], paddedCards[6],
      ];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (context) {
            return _buildCardGrid(
              cards: mirroredBackCards,
              isFront: false,
              deckTitle: deck.title,
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _buildCardGrid({
    required List<FlashcardEntity?> cards,
    required bool isFront,
    required String deckTitle,
  }) {
    return pw.GridView(
      crossAxisCount: 2,
      childAspectRatio: 1.45,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: cards.map((card) {
        if (card == null) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.grey300,
                style: pw.BorderStyle.dashed,
              ),
              borderRadius: pw.BorderRadius.circular(8),
            ),
          );
        }

        return pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: PdfColors.grey600,
            ),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    deckTitle,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    isFront ? 'FRONT' : 'BACK',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: isFront ? PdfColors.blue800 : PdfColors.green800,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text(
                    isFront ? card.front : card.back,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isFront ? pw.FontWeight.bold : pw.FontWeight.normal,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: pw.Text(
                  'Kortex Academic',
                  style: const pw.TextStyle(
                    fontSize: 6,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
