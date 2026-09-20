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

      if (clean == '/study-session' || clean.startsWith('/study-session?')) {
        final uri = Uri.tryParse(clean);
        final deckId = uri?.queryParameters['deckId'];
        if (deckId != null && deckId.isNotEmpty) {
          return 'StudySessionRoute($deckId)';
        }
        return 'DecksRoute';
      }

      if (clean == '/quiz-duel' || clean.startsWith('/quiz-duel?')) {
        return 'CommunityHubRoute';
      }

      if (clean == '/deck-detail' || clean.startsWith('/deck-detail?')) {
        final uri = Uri.tryParse(clean);
        final deckId = uri?.queryParameters['deckId'];
        if (deckId != null && deckId.isNotEmpty) {
          return 'DeckDetailRoute($deckId)';
        }
        return 'DecksRoute';
      }

      if (clean == '/dashboard' || clean == 'dashboard') {
        return 'DashboardRoot';
      }

      if (clean == '/community' || clean == 'community') {
        return 'CommunityHubRoute';
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
      expect(
        resolveRouteFromPayload('/study-session?deckId=deck-42'),
        equals('StudySessionRoute(deck-42)'),
      );
      expect(resolveRouteFromPayload('/study-session'), equals('DecksRoute'));
      expect(
        resolveRouteFromPayload('/deck-detail?deckId=math-99'),
        equals('DeckDetailRoute(math-99)'),
      );
    });

    test('parses past questions, quiz duel, and chat payloads correctly', () {
      expect(resolveRouteFromPayload('/past-questions'), equals('PastQuestionsBoardRoute'));
      expect(resolveRouteFromPayload('past-questions'), equals('PastQuestionsBoardRoute'));
      expect(resolveRouteFromPayload('/chat'), equals('SyllabotChatRoute'));
      expect(resolveRouteFromPayload('syllabot'), equals('SyllabotChatRoute'));
      expect(resolveRouteFromPayload('/quiz-duel'), equals('CommunityHubRoute'));
      expect(resolveRouteFromPayload('/quiz-duel?duelId=duel-101'), equals('CommunityHubRoute'));
    });

    test('parses dashboard and community routes correctly', () {
      expect(resolveRouteFromPayload('/dashboard'), equals('DashboardRoot'));
      expect(resolveRouteFromPayload('dashboard'), equals('DashboardRoot'));
      expect(resolveRouteFromPayload('/community'), equals('CommunityHubRoute'));
      expect(resolveRouteFromPayload('community'), equals('CommunityHubRoute'));
    });

    test('parses generic paths or falls back gracefully', () {
      expect(resolveRouteFromPayload('/subscription'), equals('PathRoute(/subscription)'));
      expect(resolveRouteFromPayload('/custom/route'), equals('PathRoute(/custom/route)'));
      expect(resolveRouteFromPayload('unsupported-raw-string'), equals('Unknown'));
    });
  });
}
