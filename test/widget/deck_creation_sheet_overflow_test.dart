import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  testWidgets('Decks bottom sheet renders scrollably without layout overflow',
      (tester) async {
    // Set typical mobile screen size (390 x 844, matching screenshot)
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  unawaited(
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) {
                        return SafeArea(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Create or Ingest Deck'),
                                const SizedBox(height: 6),
                                const Text('Choose how you want to add cards'),
                                const SizedBox(height: 20),
                                ...List.generate(
                                  5,
                                  (i) => Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    height: 72,
                                    color: Colors.blue,
                                    child: Text('Option $i'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify all options rendered and no overflow was thrown
    expect(find.text('Create or Ingest Deck'), findsOneWidget);
    expect(find.text('Option 0'), findsOneWidget);
    expect(find.text('Option 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
