import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Push Notification Payload Route Parsing Suite', () {
    String resolveRouteFromPayload(String payload) {
      final clean = payload.trim();
      if (clean == '/planner' ||
          clean == 'planner' ||
          clean.startsWith('/exam') ||
          clean.startsWith('exam:')) {
        return 'ExamTimetableRoute';
      }

      if (clean == '/decks' || clean == 'decks') {
        return 'DecksRoute';
      }

      if (clean == '/past-questions' || clean == 'past-questions') {
        return 'PastQuestionsBoardRoute';
      }

      if (clean == '/chat' || clean == 'syllabot' || clean == '/syllabot') {
        return 'SyllabotChatRoute';
      }

      if (clean.startsWith('deck:')) {
        final parts = clean.substring(5).split(':');
        final deckId = parts.first;
        final mode = parts.length > 1 ? parts[1] : '';
        if (mode == 'study') {
          return 'StudySessionRoute($deckId)';
        } else {
          return 'DeckDetailRoute($deckId)';
        }
      }

      if (clean.startsWith('study:')) {
        final deckId = clean.substring(6);
        return 'StudySessionRoute($deckId)';
      }

      if (clean.startsWith('/')) {
        return 'PathRoute($clean)';
      }

      return 'Unknown';
    }

    test('parses planner and exam payloads correctly', () {
      expect(resolveRouteFromPayload('/planner'), equals('ExamTimetableRoute'));
      expect(resolveRouteFromPayload('planner'), equals('ExamTimetableRoute'));
      expect(resolveRouteFromPayload('/exam/123'), equals('ExamTimetableRoute'));
      expect(resolveRouteFromPayload('exam:waec'), equals('ExamTimetableRoute'));
    });

    test('parses deck navigation and study session payloads correctly', () {
      expect(resolveRouteFromPayload('/decks'), equals('DecksRoute'));
      expect(resolveRouteFromPayload('deck:bio-101'), equals('DeckDetailRoute(bio-101)'));
      expect(resolveRouteFromPayload('deck:bio-101:study'), equals('StudySessionRoute(bio-101)'));
      expect(resolveRouteFromPayload('study:chem-202'), equals('StudySessionRoute(chem-202)'));
    });

    test('parses past questions and chat payloads correctly', () {
      expect(resolveRouteFromPayload('/past-questions'), equals('PastQuestionsBoardRoute'));
      expect(resolveRouteFromPayload('past-questions'), equals('PastQuestionsBoardRoute'));
      expect(resolveRouteFromPayload('/chat'), equals('SyllabotChatRoute'));
      expect(resolveRouteFromPayload('syllabot'), equals('SyllabotChatRoute'));
    });

    test('parses generic paths or falls back gracefully', () {
      expect(resolveRouteFromPayload('/custom/route'), equals('PathRoute(/custom/route)'));
      expect(resolveRouteFromPayload('unsupported-raw-string'), equals('Unknown'));
    });
  });
}
