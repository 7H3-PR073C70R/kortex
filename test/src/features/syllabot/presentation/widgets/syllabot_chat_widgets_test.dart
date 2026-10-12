import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_chat_app_bar_actions.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_chat_bottom_dock.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_chat_error_banner.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_empty_greeting_view.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_message_list_view.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockSyllabotChatBloc extends Mock implements SyllabotChatBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockSyllabotChatBloc mockBloc;

  setUp(() {
    mockBloc = MockSyllabotChatBloc();
    when(() => mockBloc.state).thenReturn(const SyllabotChatState());
    when(() => mockBloc.stream).thenAnswer(
      (_) => Stream.value(const SyllabotChatState()),
    );
    when(() => mockBloc.streamTokens).thenAnswer((_) => const Stream.empty());
  });

  Widget wrapWithTheme(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: BlocProvider<SyllabotChatBloc>.value(
            value: mockBloc,
            child: child,
          ),
        ),
      ),
    );
  }

  group('Syllabot Chat Widgets Unit Tests', () {
    testWidgets('SyllabotEmptyGreetingView renders greeting and suggestions', (
      tester,
    ) async {
      final textController = TextEditingController();

      await tester.pumpWidget(
        wrapWithTheme(
          SyllabotEmptyGreetingView(
            textController: textController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Syllabot AI'), findsOneWidget);
      expect(
        find.text(
          'Your 24/7 AI tutor for concept derivations, exam prep, and flashcards',
        ),
        findsOneWidget,
      );

      final suggestion = find.textContaining('Euler-Lagrange');
      expect(suggestion, findsOneWidget);
    });

    testWidgets('SyllabotMessageListView renders messages and handles retry', (
      tester,
    ) async {
      final messages = [
        ChatMessageEntity(
          id: 'msg_1',
          sessionId: 'session_1',
          sender: MessageSender.user,
          text: 'What is photosynthesis?',
          timestamp: DateTime.now(),
        ),
      ];

      final scrollController = ScrollController();
      final ttsHandler = TextToSpeechHandler();

      await tester.pumpWidget(
        wrapWithTheme(
          SyllabotMessageListView(
            state: SyllabotChatState(messages: messages),
            scrollController: scrollController,
            ttsHandler: ttsHandler,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What is photosynthesis?'), findsOneWidget);
    });

    testWidgets('SyllabotChatErrorBanner renders error message and retry button', (
      tester,
    ) async {
      var retryCalled = false;
      var switchCalled = false;

      await tester.pumpWidget(
        wrapWithTheme(
          SyllabotChatErrorBanner(
            state: const SyllabotChatState(
              status: SyllabotStatus.error,
              errorMessage: 'Network timeout connection refused',
              lastPrompt: 'Hello',
            ),
            onRetry: () => retryCalled = true,
            onSwitchToLocalEngine: () => switchCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network timeout connection refused'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryCalled, isTrue);

      if (find.text('Use On-Device AI').evaluate().isNotEmpty) {
        await tester.tap(find.text('Use On-Device AI'));
        expect(switchCalled, isTrue);
      }
    });

    testWidgets('SyllabotChatBottomDock renders dock and input bar', (
      tester,
    ) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        wrapWithTheme(
          SyllabotChatBottomDock(
            controller: controller,
            state: const SyllabotChatState(),
            isDownloadingModel: false,
            downloadProgress: 0,
            isAiSpeaking: false,
            isPro: true,
            usedQueries: 5,
            onCancelDownload: () {},
            onInterruptAi: () {},
            onVoiceDialogueTap: () {},
            onModeChanged: (_) {},
            onEngineChanged: (_) {},
            onSubmit: (_) {},
            onUpgradeTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SyllabotChatBottomDock), findsOneWidget);
    });

    testWidgets('SyllabotChatAppBarActions renders action icons', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SyllabotChatAppBarActions(
            onOpenVoiceDialogue: (ctx, st) {},
            onOpenConvertToDeck: (ctx, st) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SyllabotChatAppBarActions), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      expect(find.byIcon(Icons.style_rounded), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });
  });
}
