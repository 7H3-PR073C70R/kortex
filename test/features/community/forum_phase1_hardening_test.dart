import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/services/content_moderation_service.dart';
import 'package:kortex/src/features/community/domain/services/forum_offline_sync_queue.dart';
import 'package:kortex/src/features/community/domain/services/forum_socratic_hint_service.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRepository extends Mock implements CommunityRepository {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  group('Phase 1: ContentModerationService Hardening Tests', () {
    const moderation = ContentModerationService();

    test('Valid post with academic content and LaTeX passes moderation', () {
      final result = moderation.validatePost(
        title: 'How do you derive the quadratic formula?',
        content: r'Can someone explain the steps to get to $$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$?',
      );
      expect(result.isValid, isTrue);
      expect(result.reason, isNull);
    });

    test('Post with <script> tag is blocked as malicious', () {
      final result = moderation.validatePost(
        title: 'Check this link',
        content: '<script>alert("xss")</script> How do I solve this?',
      );
      expect(result.isValid, isFalse);
      expect(result.reason, contains('Potentially malicious'));
    });

    test('Post with iframe or inline event handlers is blocked', () {
      final result = moderation.validatePost(
        title: 'Check math problem',
        content: '<img src="invalid.png" onerror="stealData()" /> Is this correct?',
      );
      expect(result.isValid, isFalse);
      expect(result.reason, contains('Potentially malicious'));
    });

    test('Post with profanity is blocked', () {
      final result = moderation.validatePost(
        title: 'This is bullshit problem',
        content: 'I hate this shit topic so much',
      );
      expect(result.isValid, isFalse);
      expect(result.reason, contains('Inappropriate language'));
    });

    test('Reply with malicious script is blocked by validateReply', () {
      final result = moderation.validateReply(
        content: 'javascript:void(window.location="http://evil.com")',
      );
      expect(result.isValid, isFalse);
      expect(result.reason, contains('Potentially malicious'));
    });

    test('Clean reply with math passes validateReply', () {
      final result = moderation.validateReply(
        content: r'Use the power rule: $\frac{d}{dx}[x^n] = n x^{n-1}$ to solve the first term.',
      );
      expect(result.isValid, isTrue);
    });

    test('sanitizeText strips dangerous tags while preserving LaTeX equations', () {
      const malicious = r'<script>bad()</script>Solve: $$\int x dx = \frac{x^2}{2} + C$$<iframe src="evil.com"></iframe>';
      final sanitized = ContentModerationService.sanitizeText(malicious);

      expect(sanitized, isNot(contains('<script>')));
      expect(sanitized, isNot(contains('<iframe>')));
      expect(sanitized, contains(r'$$\int x dx = \frac{x^2}{2} + C$$'));
    });
  });

  group('Phase 1: ForumOfflineSyncQueue Resilience Tests', () {
    late MockCommunityRepository mockRepo;
    late MockLocalStorageService mockStorage;
    late ForumOfflineSyncQueue queue;

    setUp(() {
      mockRepo = MockCommunityRepository();
      mockStorage = MockLocalStorageService();
      when(() => mockStorage.getPreference(key: any(named: 'key'))).thenReturn(null);
      when(() => mockStorage.savePreference(
            key: any(named: 'key'),
            data: any(named: 'data'),
          )).thenAnswer((_) async {});
      when(() => mockStorage.deletePreference(key: any(named: 'key')))
          .thenAnswer((_) async {});

      queue = ForumOfflineSyncQueue(localStorageService: mockStorage);
    });

    test('Calculates exponential backoff correctly', () {
      expect(ForumOfflineSyncQueue.calculateBackoffSeconds(0), 0);
      expect(ForumOfflineSyncQueue.calculateBackoffSeconds(1), 4);
      expect(ForumOfflineSyncQueue.calculateBackoffSeconds(2), 8);
      expect(ForumOfflineSyncQueue.calculateBackoffSeconds(3), 16);
      expect(ForumOfflineSyncQueue.calculateBackoffSeconds(10), 60); // capped at 60s
    });

    test('Enqueuing an action persists to local storage', () {
      final post = ForumPostEntity(
        id: 'post-123',
        authorId: 'user-1',
        authorName: 'Test Student',
        track: 'WAEC',
        title: 'Physics Wave Question',
        content: 'What is the period of this oscillation?',
        createdAt: DateTime.now(),
      );

      queue.enqueuePost(post);

      expect(queue.queueLength, 1);
      expect(queue.hasPendingActions, isTrue);
      verify(() => mockStorage.savePreference(
            key: any(named: 'key'),
            data: any(named: 'data'),
          )).called(1);
    });

    test('QueuedForumAction serialization roundtrip maintains fields', () {
      final action = QueuedForumAction(
        id: 'action-1',
        actionType: OfflineActionType.upvotePost,
        postId: 'post-999',
        voteDirection: 1,
        retryCount: 2,
        createdAt: DateTime(2026, 10),
        lastError: 'Timeout',
      );

      final json = action.toJson();
      final restored = QueuedForumAction.fromJson(json);

      expect(restored.id, action.id);
      expect(restored.actionType, OfflineActionType.upvotePost);
      expect(restored.postId, 'post-999');
      expect(restored.voteDirection, 1);
      expect(restored.retryCount, 2);
      expect(restored.maxRetries, 3);
      expect(restored.lastError, 'Timeout');
    });

    test('Failed action exceeding maxRetries is discarded to prevent poison pill block', () async {
      final post = ForumPostEntity(
        id: 'post-poison',
        authorId: 'user-1',
        authorName: 'Poison Pill',
        track: 'WAEC',
        title: 'Unprocessable post',
        content: 'This causes permanent 400 error',
        createdAt: DateTime.now(),
      );

      queue.enqueuePost(post);
      expect(queue.queueLength, 1);

      // Simulate repository failing
      when(() => mockRepo.createForumPost(
            track: any(named: 'track'),
            title: any(named: 'title'),
            content: any(named: 'content'),
            isQuestion: any(named: 'isQuestion'),
            syllabusTag: any(named: 'syllabusTag'),
            mediaUrls: any(named: 'mediaUrls'),
            voiceNoteUrl: any(named: 'voiceNoteUrl'),
            voiceNoteDurationSeconds: any(named: 'voiceNoteDurationSeconds'),
          )).thenThrow(Exception('Simulated network error'));

      // Process 3 times to exceed maxRetries (default: 3)
      for (var attempt = 0; attempt < 3; attempt++) {
        await queue.processSyncQueue(mockRepo, forceRetry: true);
      }

      // After 3 failed attempts, action is discarded from pending queue
      expect(queue.queueLength, 0);
      expect(queue.discardedActions.length, 1);
      expect(queue.discardedActions.first.retryCount, 3);
    });
  });

  group('Phase 1: ForumSocraticHintService In-Flight Deduplication Tests', () {
    test('Cached Socratic hint returns immediately without re-generation', () async {
      final post = ForumPostEntity(
        id: 'post-cached',
        authorId: 'user-1',
        authorName: 'Student',
        track: 'WAEC',
        title: 'Photosynthesis dark reactions',
        content: 'What happens in the stroma?',
        socraticHint: '💡 Core Subject Principle: Calvin cycle occurs in stroma.',
        createdAt: DateTime.now(),
      );

      final hint = await ForumSocraticHintService.generateHint(post: post);
      expect(hint, contains('Calvin cycle occurs in stroma'));
    });
  });
}
