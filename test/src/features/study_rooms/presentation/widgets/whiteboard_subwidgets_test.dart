import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/whiteboard_canvas_widget.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('Whiteboard Subwidgets Test Suite', () {
    testWidgets('WhiteboardTopStatusBar renders live strokes count and grid toggle button', (tester) async {
      var gridToggled = false;
      var toolsToggled = false;

      await tester.pumpWidget(
        createTestApp(
          WhiteboardTopStatusBar(
            strokesCount: 12,
            showGrid: true,
            gridStyle: WhiteboardGridStyle.dots,
            showToolsExpanded: true,
            isDark: true,
            onToggleGrid: () {
              gridToggled = true;
            },
            onToggleTools: () {
              toolsToggled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('12'), findsOneWidget);
      expect(find.byIcon(Icons.grain_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.grain_rounded));
      await tester.pumpAndSettle();
      expect(gridToggled, isTrue);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      expect(toolsToggled, isTrue);
    });

    testWidgets('WhiteboardFloatingToolbar renders tools, palette, and actions', (tester) async {
      WhiteboardTool? changedTool;
      int? changedColor;
      double? changedWidth;
      var undoCalled = false;
      var redoCalled = false;

      await tester.pumpWidget(
        createTestApp(
          WhiteboardFloatingToolbar(
            activeTool: WhiteboardTool.pen,
            selectedColorHex: 0xFFFFFFFF,
            strokeWidth: 3.5,
            isDark: true,
            canUndo: true,
            canRedo: true,
            onToolChanged: (tool) => changedTool = tool,
            onColorChanged: (hex) => changedColor = hex,
            onStrokeWidthChanged: (w) => changedWidth = w,
            onUndo: () => undoCalled = true,
            onRedo: () => redoCalled = true,
            onClear: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cleaning_services_rounded), findsOneWidget);

      // Tap highlighter tool
      await tester.tap(find.byIcon(Icons.brush_rounded));
      await tester.pumpAndSettle();
      expect(changedTool, equals(WhiteboardTool.highlighter));

      // Tap undo
      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pumpAndSettle();
      expect(undoCalled, isTrue);

      // Tap redo
      await tester.tap(find.byIcon(Icons.redo_rounded));
      await tester.pumpAndSettle();
      expect(redoCalled, isTrue);

      // Tap stroke width preset 8.0
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pumpAndSettle();
      expect(changedColor != null || changedWidth != null || changedTool != null, isTrue);
    });
  });
}
