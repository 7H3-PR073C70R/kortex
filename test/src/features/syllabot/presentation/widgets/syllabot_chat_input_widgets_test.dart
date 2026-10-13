import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/input/syllabot_input_mode_pills.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/input/syllabot_socratic_mode_sheet.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/input/syllabot_voice_send_action.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/syllabot_chat_input_bar.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget wrapWithTheme(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('SyllabotChatInputBar & Decomposed Sub-Widgets Tests', () {
    testWidgets('SyllabotChatInputBar renders input textfield, mode pills, and send action', (tester) async {
      final controller = TextEditingController();
      String? submitted;
      var currentMode = SocraticMode.stepByStep;
      var currentEngine = ExecutionEngineType.cloudRemote;

      await tester.pumpWidget(
        wrapWithTheme(
          SyllabotChatInputBar(
            controller: controller,
            socraticMode: currentMode,
            engineType: currentEngine,
            onModeChanged: (m) => currentMode = m,
            onEngineChanged: (e) => currentEngine = e,
            onSubmit: (t) => submitted = t,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SyllabotChatInputBar), findsOneWidget);
      expect(find.byType(SyllabotInputModePills), findsOneWidget);
      expect(find.byType(SyllabotVoiceSendAction), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Enter text and verify Send button triggers submit
      await tester.enterText(find.byType(TextField), 'Explain entropy');
      await tester.pumpAndSettle();

      final sendIconFinder = find.byIcon(Icons.arrow_upward_rounded);
      expect(sendIconFinder, findsOneWidget);

      await tester.tap(sendIconFinder);
      await tester.pumpAndSettle();

      expect(submitted, 'Explain entropy');
      expect(controller.text, isEmpty);
    });

    testWidgets('SyllabotSocraticModeSheet shows options and updates mode', (tester) async {
      var selected = SocraticMode.stepByStep;

      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  unawaited(
                    SyllabotSocraticModeSheet.show(
                      context: context,
                      currentMode: selected,
                      onModeChanged: (m) => selected = m,
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(SyllabotSocraticModeSheet), findsOneWidget);

      // Select direct answer mode
      await tester.tap(find.text('Direct Answer').first);
      await tester.pumpAndSettle();

      expect(selected, SocraticMode.directAnswer);
      expect(find.byType(SyllabotSocraticModeSheet), findsNothing);
    });

    testWidgets('SyllabotInputModePills triggers onEngineChanged when toggled', (tester) async {
      var engine = ExecutionEngineType.cloudRemote;

      await tester.pumpWidget(
        wrapWithTheme(
          SyllabotInputModePills(
            socraticMode: SocraticMode.feynmanTeachBack,
            engineType: engine,
            onOpenModeSheet: () {},
            onEngineChanged: (e) => engine = e,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Feynman Mode'), findsOneWidget);

      // Tap engine pill to toggle to local on-device
      await tester.tap(find.text('Cloud AI'));
      await tester.pumpAndSettle();

      expect(engine, ExecutionEngineType.localOnDevice);
    });
  });
}
