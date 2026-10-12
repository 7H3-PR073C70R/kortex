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
import 'package:kortex/src/features/syllabot/presentation/pages/syllabot_chat_page.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat/syllabot_empty_greeting_view.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_bubble_widget.dart';
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

  Widget createTestWidget({SyllabotChatState? state}) {
    if (state != null) {
      when(() => mockBloc.state).thenReturn(state);
      when(() => mockBloc.stream).thenAnswer((_) => Stream.value(state));
    }

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.darkTheme,
        home: BlocProvider<SyllabotChatBloc>.value(
          value: mockBloc,
          child: SyllabotChatPage(
            chatBloc: mockBloc,
          ),
        ),
      ),
    );
  }

  group('SyllabotChatPage Widget Tests', () {
    testWidgets('renders empty state greeting when messages are empty', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SyllabotEmptyGreetingView), findsOneWidget);
      expect(find.text('Syllabot AI'), findsWidgets);
    });

    testWidgets('renders active message list when messages exist', (
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
        ChatMessageEntity(
          id: 'msg_2',
          sessionId: 'session_1',
          sender: MessageSender.syllabot,
          text: 'Photosynthesis is the process used by plants...',
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          state: SyllabotChatState(
            messages: messages,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChatBubbleWidget), findsNWidgets(2));
      expect(find.text('What is photosynthesis?'), findsOneWidget);
      expect(
        find.text('Photosynthesis is the process used by plants...'),
        findsOneWidget,
      );
    });
  });
}
