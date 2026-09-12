import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/presentation/widgets/whiteboard_canvas_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';

Widget _wrapWithTheme(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(800, 1000),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhiteboardCanvasWidget (COM-05)', () {
    testWidgets(
      'renders canvas surface with initial strokes and tool controls',
      (tester) async {
        const strokes = [
          WhiteboardStroke(
            id: 'stroke-1',
            userId: 'user_1',
            userName: 'Scholar Alice',
            colorHex: 0xFF6366F1,
            strokeWidth: 3.5,
            points: [
              WhiteboardPoint(x: 0.1, y: 0.1),
              WhiteboardPoint(x: 0.5, y: 0.5),
            ],
          ),
        ];

        await tester.pumpWidget(
          _wrapWithTheme(
            const SizedBox(
              width: 800,
              height: 600,
              child: WhiteboardCanvasWidget(
                strokes: strokes,
                canUndo: true,
                canRedo: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(WhiteboardCanvasWidget), findsOneWidget);
        expect(find.text('Live Whiteboard (1 stroke)'), findsOneWidget);
        expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
        expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
        expect(find.byIcon(Icons.cleaning_services_rounded), findsOneWidget);
        expect(find.byIcon(Icons.crop_square_rounded), findsOneWidget);
        expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
        expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
        expect(find.byIcon(Icons.redo_rounded), findsOneWidget);
        expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'drawing a freehand stroke calls onStrokeDrawn with simplified points',
      (tester) async {
        WhiteboardStroke? drawnStroke;

        await tester.pumpWidget(
          _wrapWithTheme(
            SizedBox(
              width: 500,
              height: 500,
              child: WhiteboardCanvasWidget(
                strokes: const [],
                currentUserId: 'user_tester_1',
                currentUserName: 'Test User',
                onStrokeDrawn: (stroke) {
                  drawnStroke = stroke;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Perform a drag gesture on the CustomPaint canvas
        final canvasFinder = find.byType(CustomPaint).first;
        final gesture = await tester.startGesture(
          tester.getCenter(canvasFinder),
        );
        await gesture.moveBy(const Offset(50, 50));
        await gesture.moveBy(const Offset(50, 0));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(drawnStroke, isNotNull);
        expect(drawnStroke!.userId, equals('user_tester_1'));
        expect(drawnStroke!.userName, equals('Test User'));
        expect(drawnStroke!.points.isNotEmpty, isTrue);
        expect(drawnStroke!.elementType, equals('stroke'));
        expect(drawnStroke!.isEraser, isFalse);
      },
    );

    testWidgets('selecting shape tool and dragging creates a shape stroke', (
      tester,
    ) async {
      WhiteboardStroke? drawnStroke;

      await tester.pumpWidget(
        _wrapWithTheme(
          SizedBox(
            width: 500,
            height: 500,
            child: WhiteboardCanvasWidget(
              strokes: const [],
              onStrokeDrawn: (stroke) {
                drawnStroke = stroke;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Rectangle shape
      await tester.tap(find.byIcon(Icons.crop_square_rounded));
      await tester.pumpAndSettle();

      // Draw rectangle
      final canvasFinder = find.byType(CustomPaint).first;
      final gesture = await tester.startGesture(tester.getCenter(canvasFinder));
      await gesture.moveBy(const Offset(100, 80));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(drawnStroke, isNotNull);
      expect(drawnStroke!.isShape, isTrue);
      expect(drawnStroke!.shapeType, equals('rectangle'));
      expect(drawnStroke!.points.length, equals(2));
    });

    testWidgets('tapping undo, redo, and clear buttons invokes callbacks', (
      tester,
    ) async {
      var undoCalled = false;
      var redoCalled = false;
      var clearCalled = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          SizedBox(
            width: 600,
            height: 600,
            child: WhiteboardCanvasWidget(
              strokes: const [],
              canUndo: true,
              canRedo: true,
              onUndo: () => undoCalled = true,
              onRedo: () => redoCalled = true,
              onClear: () => clearCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Undo
      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pumpAndSettle();
      expect(undoCalled, isTrue);

      // Tap Redo
      await tester.tap(find.byIcon(Icons.redo_rounded));
      await tester.pumpAndSettle();
      expect(redoCalled, isTrue);

      // Tap Clear and confirm dialog
      await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Clear Whiteboard'), findsOneWidget);
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      expect(clearCalled, isTrue);
    });

    testWidgets('toggling grid button cycles through dots, lines, and blank', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const SizedBox(
            width: 600,
            height: 600,
            child: WhiteboardCanvasWidget(
              strokes: [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dots'), findsOneWidget);

      // Tap grid toggle
      await tester.tap(find.text('Dots'));
      await tester.pumpAndSettle();
      expect(find.text('Lines'), findsOneWidget);

      // Tap again
      await tester.tap(find.text('Lines'));
      await tester.pumpAndSettle();
      expect(find.text('Blank'), findsOneWidget);
    });

    testWidgets('readOnly mode hides interactive tools and ignores gestures', (
      tester,
    ) async {
      var strokeDrawn = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          SizedBox(
            width: 500,
            height: 500,
            child: WhiteboardCanvasWidget(
              strokes: const [],
              readOnly: true,
              onStrokeDrawn: (_) => strokeDrawn = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_rounded), findsNothing);
      expect(find.byIcon(Icons.delete_sweep_rounded), findsNothing);

      // Gesture should not emit
      final canvasFinder = find.byType(CustomPaint).first;
      final gesture = await tester.startGesture(tester.getCenter(canvasFinder));
      await gesture.moveBy(const Offset(40, 40));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(strokeDrawn, isFalse);
    });
  });
}
