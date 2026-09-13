import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

class MockLocalLlmEngineClient extends Mock implements LocalLlmEngineClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocalLlmEngineClient mockClient;

  setUp(() async {
    mockClient = MockLocalLlmEngineClient();
    if (locator.isRegistered<LocalLlmEngineClient>()) {
      await locator.unregister<LocalLlmEngineClient>();
    }
    locator.registerSingleton<LocalLlmEngineClient>(mockClient);
  });

  tearDown(() async {
    if (locator.isRegistered<LocalLlmEngineClient>()) {
      await locator.unregister<LocalLlmEngineClient>();
    }
  });

  testWidgets('showModelDownloadSnackBar renders download button and streams live progress', (tester) async {
    final progressController = StreamController<double>();
    when(() => mockClient.downloadModel()).thenAnswer((_) => progressController.stream);

    var downloadCompleted = false;

    await tester.pumpApp(
      Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  context.showModelDownloadSnackBar(
                    message: 'Could not generate Syllabot hint: LocalLlmNotDownloadedException: On-device neural engine is not downloaded. Please download the 248MB model weights to enable offline reasoning.',
                    onDownloadComplete: () {
                      downloadCompleted = true;
                    },
                  );
                },
                child: const Text('Show Error'),
              ),
            );
          },
        ),
      ),
    );

    // Tap to show the error snackbar
    await tester.tap(find.text('Show Error'));
    await tester.pumpAndSettle();

    // Verify error banner with Download Model button is visible
    expect(find.text('Download Model (248 MB)'), findsOneWidget);
    expect(find.text('On-Device AI Required'), findsOneWidget);

    // Tap "Download Model (248 MB)"
    await tester.tap(find.text('Download Model (248 MB)'));
    await tester.pump();

    // Verify download started
    verify(() => mockClient.downloadModel()).called(1);

    // Emit 50% progress
    progressController.add(0.5);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Downloading weights...'), findsOneWidget);

    // Emit completion
    progressController.add(1);
    await progressController.close();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Engine Ready'), findsOneWidget);
    expect(downloadCompleted, isTrue);
  });
}
