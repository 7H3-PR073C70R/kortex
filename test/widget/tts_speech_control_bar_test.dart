import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/audio/bloc/audio_workspace_cubit.dart';
import 'package:kortex/src/shared/audio/widgets/tts_speech_control_bar.dart';

void main() {
  group('TtsSpeechControlBar Widget Test Suite', () {
    late AudioWorkspaceCubit cubit;

    setUp(() {
      cubit = AudioWorkspaceCubit();
    });

    tearDown(() async {
      await cubit.stopPlayback();
      await cubit.close();
    });

    Widget createTestApp(Widget child) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AudioWorkspaceCubit>.value(
          value: cubit,
          child: Scaffold(
            body: Center(child: child),
          ),
        ),
      );
    }

    testWidgets('renders Read Aloud button and speed selector', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const TtsSpeechControlBar(
            textToRead: 'Mitochondria is the powerhouse of the cell',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Read Aloud'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);

      await tester.tap(find.text('Read Aloud'));
      await tester.pump();

      expect(find.text('Stop'), findsOneWidget);

      await cubit.stopPlayback();
      await tester.pump();
    });
  });
}
