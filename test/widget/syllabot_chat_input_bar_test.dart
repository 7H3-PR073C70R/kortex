import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/syllabot_chat_input_bar.dart';
import '../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('SyllabotChatInputBar Widget Tests', () {
    testWidgets('renders input bar, mode selector, and mic button when empty',
        (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: SyllabotChatInputBar(
            controller: controller,
            socraticMode: SocraticMode.stepByStep,
            engineType: ExecutionEngineType.cloudRemote,
            onModeChanged: (_) {},
            onEngineChanged: (_) {},
            onSubmit: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SyllabotChatInputBar), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.text('Step-by-Step'), findsOneWidget);
      expect(find.text('Cloud AI'), findsOneWidget);
    });

    testWidgets('switches from mic button to send button when text is entered',
        (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: SyllabotChatInputBar(
            controller: controller,
            socraticMode: SocraticMode.stepByStep,
            engineType: ExecutionEngineType.cloudRemote,
            onModeChanged: (_) {},
            onEngineChanged: (_) {},
            onSubmit: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);

      controller.text = 'Derive Euler-Lagrange equations';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    });

    testWidgets('tapping send calls onSubmit and clears controller',
        (tester) async {
      var submitted = '';

      await tester.pumpApp(
        Scaffold(
          body: SyllabotChatInputBar(
            controller: controller,
            socraticMode: SocraticMode.stepByStep,
            engineType: ExecutionEngineType.cloudRemote,
            onModeChanged: (_) {},
            onEngineChanged: (_) {},
            onSubmit: (val) {
              submitted = val;
            },
          ),
        ),
      );
      await tester.pump();

      controller.text = 'Hello Syllabot!';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      expect(submitted, 'Hello Syllabot!');
      expect(controller.text, isEmpty);
    });

    testWidgets('tapping engine pill triggers onEngineChanged', (tester) async {
      ExecutionEngineType? changedEngine;

      await tester.pumpApp(
        Scaffold(
          body: SyllabotChatInputBar(
            controller: controller,
            socraticMode: SocraticMode.stepByStep,
            engineType: ExecutionEngineType.cloudRemote,
            onModeChanged: (_) {},
            onEngineChanged: (engine) {
              changedEngine = engine;
            },
            onSubmit: (_) {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Cloud AI'));
      await tester.pump();

      expect(changedEngine, ExecutionEngineType.localOnDevice);
    });

    testWidgets('long press on mic triggers onVoiceDialogueTap', (tester) async {
      var voiceDialogueTapped = false;

      await tester.pumpApp(
        Scaffold(
          body: SyllabotChatInputBar(
            controller: controller,
            socraticMode: SocraticMode.stepByStep,
            engineType: ExecutionEngineType.cloudRemote,
            onModeChanged: (_) {},
            onEngineChanged: (_) {},
            onSubmit: (_) {},
            onVoiceDialogueTap: () {
              voiceDialogueTapped = true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final micFinder = find.byIcon(Icons.mic_none_rounded);
      expect(micFinder, findsOneWidget);

      await tester.longPress(micFinder);
      await tester.pump(const Duration(milliseconds: 100));

      expect(voiceDialogueTapped, isTrue);
    });

    testWidgets('tapping mic triggers onVoiceDialogueTap directly when empty', (tester) async {
      var voiceDialogueTapped = false;

      await tester.pumpApp(
        Scaffold(
          body: SyllabotChatInputBar(
            controller: controller,
            socraticMode: SocraticMode.stepByStep,
            engineType: ExecutionEngineType.cloudRemote,
            onModeChanged: (_) {},
            onEngineChanged: (_) {},
            onSubmit: (_) {},
            onVoiceDialogueTap: () {
              voiceDialogueTapped = true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final micFinder = find.byIcon(Icons.mic_none_rounded);
      expect(micFinder, findsOneWidget);

      await tester.tap(micFinder);
      await tester.pump(const Duration(milliseconds: 100));

      expect(voiceDialogueTapped, isTrue);
    });
  });
}
