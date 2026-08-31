import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/data/models/study_room_model.dart';
import 'package:kortex/src/features/community/data/repositories/community_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRemoteDataSource extends Mock
    implements CommunityRemoteDataSource {}

void main() {
  late MockCommunityRemoteDataSource mockDataSource;
  late CommunityRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockCommunityRemoteDataSource();
    repository = CommunityRepositoryImpl(mockDataSource);
  });

  group('CommunityRepositoryImpl', () {
    test('fetchStudyRooms returns mapped entities on success', () async {
      const roomModel = StudyRoomModel(
        id: 'room_1',
        title: 'WAEC Math Focus',
        subject: 'Math',
        category: 'WAEC',
      );
      when(
        () => mockDataSource.fetchStudyRooms(
          category: any(named: 'category'),
        ),
      ).thenAnswer((_) async => [roomModel]);

      final result = await repository.fetchStudyRooms();

      expect(result.isRight, isTrue);
      result.fold(
        (l) => fail('Should succeed'),
        (rooms) {
          expect(rooms.length, 1);
          expect(rooms.first.id, 'room_1');
          expect(rooms.first.title, 'WAEC Math Focus');
        },
      );
    });

    test('cloneSharedDeck calls data source and returns cloned deck', () async {
      when(() => mockDataSource.cloneSharedDeck('deck_100')).thenAnswer(
        (_) async => {
          'success': true,
          'new_deck_id': 'new_deck_555',
          'cloned_cards_count': 12,
        },
      );

      final result = await repository.cloneSharedDeck('deck_100');

      expect(result.isRight, isTrue);
      result.fold(
        (l) => fail('Should succeed'),
        (deck) {
          expect(deck.id, 'new_deck_555');
          expect(deck.totalCards, 12);
        },
      );
    });
  });
}
