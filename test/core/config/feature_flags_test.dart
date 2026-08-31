import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/config/feature_flags.dart';

void main() {
  group('FeatureFlags Launch Configuration Test Suite', () {
    late FeatureFlags flags;

    setUp(() {
      flags = FeatureFlags.instance..resetToDefaults();
    });

    test('Initial MVP launch defaults match launch matrix', () {
      expect(flags.enableSocialRooms, isFalse);
      expect(flags.enableOfflineGGUF, isFalse);
      expect(flags.enableSyllabusImport, isTrue);
      expect(flags.enableFSRSFlashcards, isTrue);
    });

    test('setOverrides dynamically updates flag values', () {
      flags.setOverrides(
        enableSocialRooms: true,
        enableOfflineGGUF: true,
      );

      expect(flags.enableSocialRooms, isTrue);
      expect(flags.enableOfflineGGUF, isTrue);
      expect(flags.enableSyllabusImport, isTrue);

      flags.resetToDefaults();
      expect(flags.enableSocialRooms, isFalse);
      expect(flags.enableOfflineGGUF, isFalse);
    });

    test('toMap and fromMap properly serialize and deserialize flags', () {
      final map = {
        'enableSocialRooms': true,
        'enableOfflineGGUF': false,
        'enableSyllabusImport': false,
        'enableFSRSFlashcards': true,
      };

      flags.fromMap(map);

      expect(flags.enableSocialRooms, isTrue);
      expect(flags.enableOfflineGGUF, isFalse);
      expect(flags.enableSyllabusImport, isFalse);
      expect(flags.enableFSRSFlashcards, isTrue);

      final exported = flags.toMap();
      expect(exported['enableSocialRooms'], isTrue);
      expect(exported['enableSyllabusImport'], isFalse);
    });
  });
}
