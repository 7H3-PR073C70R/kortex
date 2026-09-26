import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/presentation/widgets/fsrs_rating_action_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Decks & FSRS Engine Unit Tests', () {
    test('FsrsRatingActionBar formatPreview formats intervals correctly', () {
      expect(FsrsRatingActionBar.formatPreview(0), equals('<10m'));
      expect(FsrsRatingActionBar.formatPreview(1), equals('1d'));
      expect(FsrsRatingActionBar.formatPreview(7), equals('7d'));
      expect(FsrsRatingActionBar.formatPreview(45), equals('2mo'));
      expect(FsrsRatingActionBar.formatPreview(400), equals('1y'));
    });

    test('FsrsRating maps correctly between value and enum', () {
      expect(FsrsRating.fromValue(1), equals(FsrsRating.again));
      expect(FsrsRating.fromValue(2), equals(FsrsRating.hard));
      expect(FsrsRating.fromValue(3), equals(FsrsRating.good));
      expect(FsrsRating.fromValue(4), equals(FsrsRating.easy));
    });
  });
}
