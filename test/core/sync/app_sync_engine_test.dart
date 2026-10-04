import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/sync/app_sync_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AppSyncEngine CRDT & Network Resilience Tests', () {
    test('mergeCrdtPayload merges fields recursively without overwriting unrelated fields', () {
      final engine = AppSyncEngine();
      final payload1 = AppSyncPayload(
        id: 'deck-101',
        type: 'deck_update',
        data: {
          'title': 'Original Title',
          'category': 'General',
          'settings': {'cardLimit': 50, 'isPublic': false},
        },
        timestampEpoch: 1000,
      );

      final payload2 = AppSyncPayload(
        id: 'deck-101',
        type: 'deck_update',
        data: {
          'title': 'New Updated Title',
          'settings': {'isPublic': true},
        },
        timestampEpoch: 2000,
      );

      final merged = engine.mergeCrdtPayload(payload1, payload2);

      expect(merged.id, equals('deck-101'));
      expect(merged.data['title'], equals('New Updated Title'));
      expect(merged.data['category'], equals('General')); // Retained
      final settings = merged.data['settings'] as Map<String, dynamic>;
      expect(settings['cardLimit'], equals(50)); // Retained
      expect(settings['isPublic'], equals(true)); // Updated
      expect(merged.timestampEpoch, equals(2000));
    });
  });
}
