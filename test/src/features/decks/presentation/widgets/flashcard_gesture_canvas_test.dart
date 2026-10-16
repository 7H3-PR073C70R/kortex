import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/flashcard_gesture_canvas.dart';
import 'package:kortex/src/features/decks/presentation/widgets/gesture_canvas/card_drag_route_indicator.dart';
import 'package:kortex/src/features/decks/presentation/widgets/gesture_canvas/card_entrance_widget.dart';
import 'package:kortex/src/features/decks/presentation/widgets/gesture_canvas/card_face_content_resolver.dart';
import 'package:kortex/src/features/decks/presentation/widgets/gesture_canvas/card_face_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  const sampleCard = FlashcardEntity(
    id: 'card-1',
    deckId: 'deck-1',
    front: 'What is the powerhouse of the cell?',
    back: 'Mitochondria',
  );

  group('CardFaceContentResolver Tests', () {
    test('returns front and back as-is when front already has options', () {
      const front = 'Question?\n\n**Options:**\n• A. Opt 1\n• B. Opt 2';
      const back = 'Mitochondria';
      final (resFront, resBack) = CardFaceContentResolver.resolve(front, back);
      expect(resFront, front);
      expect(resBack, back);
    });

    test('migrates legacy options block from back to front', () {
      const front = 'Question?';
      const back =
          '**Options:**\n• A. Option A\n• B. Option B\n\nCorrect Answer: Option A';
      final (resFront, resBack) = CardFaceContentResolver.resolve(front, back);
      expect(resFront, contains('**Options:**'));
      expect(resFront, contains('• A. Option A'));
      expect(resBack, equals('Correct Answer: Option A'));
    });
  });

  group('CardEntranceWidget Tests', () {
    testWidgets('renders child widget with entrance animation', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const CardEntranceWidget(
            child: Text('Card Entrance Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Card Entrance Content'), findsOneWidget);
    });
  });

  group('CardDragRouteIndicator Tests', () {
    testWidgets('renders route badge with given label and icon', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Stack(
            children: [
              CardDragRouteIndicator(
                routeColor: Colors.green,
                routeLabel: 'Good Recall',
                routeIcon: Icons.thumb_up_rounded,
                dragProgress: 0.8,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Good Recall'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_rounded), findsOneWidget);
    });
  });

  group('CardFaceWidget Tests', () {
    testWidgets('renders front face correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          CardFaceWidget(
            badgeText: 'FRONT',
            badgeColor: Colors.blue,
            mainText: sampleCard.front,
            isBackFace: false,
            card: sampleCard,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FRONT'), findsOneWidget);
      expect(find.text('What is the powerhouse of the cell?'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
    });

    testWidgets('renders back face correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          CardFaceWidget(
            badgeText: 'BACK',
            badgeColor: Colors.green,
            mainText: sampleCard.back,
            isBackFace: true,
            card: sampleCard,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('Mitochondria'), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
    });
  });

  group('FlashcardGestureCanvas Tests', () {
    testWidgets('renders and handles tap flip', (tester) async {
      var flipTapped = false;
      var swipedLeft = false;
      var swipedRight = false;

      await tester.pumpWidget(
        _buildTestApp(
          FlashcardGestureCanvas(
            card: sampleCard,
            isFlipped: false,
            onTapFlip: () => flipTapped = true,
            onSwipeLeft: () => swipedLeft = true,
            onSwipeRight: () => swipedRight = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What is the powerhouse of the cell?'), findsOneWidget);

      await tester.tap(find.byType(FlashcardGestureCanvas));
      await tester.pumpAndSettle();

      expect(flipTapped, isTrue);
      expect(swipedLeft, isFalse);
      expect(swipedRight, isFalse);
    });
  });
}
