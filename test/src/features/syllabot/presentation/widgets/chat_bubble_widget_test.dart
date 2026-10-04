import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_bubble_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget buildTestWidget({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }

  group('ChatBubbleWidget Table Rendering Tests', () {
    testWidgets('renders markdown table correctly without crashing or collapsing columns', (tester) async {
      const markdownWithTable = '''
## 📊 Your WAEC/WASSCE Physics Diagnostic Score

| # | Your answer | Correct answer | Result |
|---|-------------|----------------|--------|
| 1 | **A** | *≈ 5 m/s²* (≈ 5 m/s² – not listed; closest is **D** 4 m/s²) | ❌ |
| 2 | **B** | **D** (11 Ω) | ❌ |
| 3 | **A** | **A** (340 m/s) | ✅ |

**Total correct:** 1 out of 3
''';

      final message = ChatMessageEntity(
        id: 'msg_1',
        sessionId: 'session_1',
        sender: MessageSender.syllabot,
        text: markdownWithTable,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: ChatBubbleWidget(message: message),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that MarkdownBody and Table exist in widget hierarchy
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);

      // Verify preceding text rendered with LatexRichViewer
      expect(find.byType(LatexRichViewer), findsNWidgets(2)); // heading & trailing summary

      // Verify table text is found
      expect(find.textContaining('Your answer'), findsOneWidget);
      expect(find.textContaining('Correct answer'), findsOneWidget);
      expect(find.textContaining('Result'), findsOneWidget);

      // Verify table dimensions: Table width must be non-zero and reasonable
      final tableRenderBox = tester.renderObject<RenderBox>(find.byType(Table));
      expect(tableRenderBox.size.width, greaterThan(200.0));
      expect(tableRenderBox.size.height, greaterThan(50.0));
    });

    testWidgets('renders multiple tables interspersed with explanation text', (tester) async {
      const multipleTablesText = '''
First table:

| Topic | Status |
|-------|--------|
| Mechanics | Needs review |

Second table:

| Week | Focus |
|------|-------|
| 1 | Vectors |
''';

      final message = ChatMessageEntity(
        id: 'msg_2',
        sessionId: 'session_1',
        sender: MessageSender.syllabot,
        text: multipleTablesText,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: ChatBubbleWidget(message: message),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownBody), findsNWidgets(2));
      expect(find.byType(Table), findsNWidgets(2));
      expect(find.textContaining('Mechanics'), findsOneWidget);
      expect(find.textContaining('Vectors'), findsOneWidget);
    });
  });
}
