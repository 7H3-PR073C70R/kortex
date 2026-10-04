import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/dynamic_link_service.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';

void main() {
  late DynamicLinkService dynamicLinkService;
  late LinkSharingService linkSharingService;

  setUp(() {
    dynamicLinkService = DynamicLinkService();
    linkSharingService = LinkSharingService(dynamicLinkService: dynamicLinkService);
  });

  group('DynamicLinkService - Link Generation', () {
    test('generates valid HTTPS web dynamic link for Flashcard Deck', () {
      final uri = dynamicLinkService.generateDynamicLink(
        type: DynamicLinkType.deck,
        targetId: 'deck-123',
        title: 'Physics Formulas',
        description: 'STEM Formulas for WAEC',
      );

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('kortex-study-app-2026.web.app'));
      expect(uri.path, equals('/share'));
      expect(uri.queryParameters['type'], equals('deck'));
      expect(uri.queryParameters['id'], equals('deck-123'));
      expect(uri.queryParameters['title'], equals('Physics Formulas'));
      expect(uri.queryParameters['desc'], equals('STEM Formulas for WAEC'));
      expect(uri.queryParameters['apn'], equals('com.kortexify.app'));
    });

    test('generates valid custom scheme deep link', () {
      final uri = dynamicLinkService.generateCustomSchemeLink(
        type: DynamicLinkType.quizDuel,
        targetId: 'duel-999',
        parameters: {'deckId': 'deck-math'},
      );

      expect(uri.scheme, equals('kortex'));
      expect(uri.host, equals('share'));
      expect(uri.queryParameters['type'], equals('quiz_duel'));
      expect(uri.queryParameters['id'], equals('duel-999'));
      expect(uri.queryParameters['deckId'], equals('deck-math'));
    });
  });

  group('DynamicLinkService - Link Parsing', () {
    test('parses web dynamic link correctly into DynamicLinkPayload', () {
      final uri = Uri.parse(
        'https://kortex-study-app-2026.web.app/share?type=forum&id=post-456&title=Organic+Chemistry&authorName=Alice',
      );

      final payload = dynamicLinkService.parseUri(uri);

      expect(payload, isNotNull);
      expect(payload!.type, equals(DynamicLinkType.forum));
      expect(payload.targetId, equals('post-456'));
      expect(payload.title, equals('Organic Chemistry'));
      expect(payload.parameters['authorName'], equals('Alice'));
    });

    test('parses custom scheme link kortex://share?type=study_room&id=room-789', () {
      final uri = Uri.parse('kortex://share?type=study_room&id=room-789');

      final payload = dynamicLinkService.parseUri(uri);

      expect(payload, isNotNull);
      expect(payload!.type, equals(DynamicLinkType.studyRoom));
      expect(payload.targetId, equals('room-789'));
    });

    test('parses custom scheme path link kortex://deck/deck-abc', () {
      final uri = Uri.parse('kortex://deck/deck-abc');

      final payload = dynamicLinkService.parseUri(uri);

      expect(payload, isNotNull);
      expect(payload!.type, equals(DynamicLinkType.deck));
      expect(payload.targetId, equals('deck-abc'));
    });

    test('returns null for unknown/invalid URIs', () {
      final uri = Uri.parse('https://example.com/other');
      final payload = dynamicLinkService.parseUri(uri);
      expect(payload, isNull);
    });
  });

  group('DynamicLinkService - Stream Emission', () {
    test('emits payload via onLinkReceived stream when raw URI handled', () async {
      final uri = Uri.parse('https://kortex-study-app-2026.web.app/share?type=promo&id=SAVE50');

      expect(
        dynamicLinkService.onLinkReceived,
        emits(predicate<DynamicLinkPayload>((p) => p.type == DynamicLinkType.promo && p.targetId == 'SAVE50')),
      );

      dynamicLinkService.handleRawUri(uri);
    });
  });

  group('LinkSharingService - Verification', () {
    test('instantiates with dynamic link service dependency', () {
      expect(linkSharingService, isNotNull);
    });
  });
}
