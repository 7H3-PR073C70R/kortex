import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/decks/presentation/widgets/collaborative_editor_badge.dart';

import '../helpers/pump_app.dart';

void main() {
  group('CollaborativeEditorBadge Widget Test Suite', () {
    testWidgets('renders empty space when editors list is empty', (
      tester,
    ) async {
      await tester.pumpApp(
        const Scaffold(
          body: CollaborativeEditorBadge(editors: []),
        ),
      );

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('Live Editing'), findsNothing);
    });

    testWidgets(
      'renders avatar stack and live editing label with active peers',
      (tester) async {
        final editors = [
          const EphemeralParticipant(
            userId: 'u1',
            displayName: 'Adeola',
            avatarUrl: '',
          ),
          const EphemeralParticipant(
            userId: 'u2',
            displayName: 'Chukwudi',
            avatarUrl: '',
          ),
          const EphemeralParticipant(
            userId: 'u3',
            displayName: 'Elena',
            avatarUrl: '',
          ),
          const EphemeralParticipant(
            userId: 'u4',
            displayName: 'Tariq',
            avatarUrl: '',
          ),
        ];

        await tester.pumpApp(
          Scaffold(
            body: CollaborativeEditorBadge(editors: editors),
          ),
        );

        expect(find.text('Live Editing'), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
        expect(find.text('C'), findsOneWidget);
        expect(find.text('E'), findsOneWidget);
        expect(find.text('+1'), findsOneWidget);
      },
    );
  });
}
