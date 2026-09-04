import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/camera_live_ocr_overlay.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  group('CameraLiveOcrOverlay Widget Test Suite', () {
    const tBlocks = [
      RecognizedTextBlock(
        text: r'\sum_{i=1}^n i = \frac{n(n+1)}{2}',
        left: 20,
        top: 80,
        width: 240,
        height: 40,
      ),
    ];

    Widget createTestApp(Widget child) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: child,
          ),
        ),
      );
    }

    testWidgets(
      'renders camera overlay with guidance hint and capture button',
      (tester) async {
        var captured = false;

        await tester.pumpWidget(
          createTestApp(
            CameraLiveOcrOverlay(
              detectedBlocks: tBlocks,
              onCapture: () {
                captured = true;
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Align textbook or lecture note text within frame'),
          findsOneWidget,
        );

        expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.camera_alt_rounded));
        await tester.pump();

        expect(captured, isTrue);
      },
    );
  });
}
