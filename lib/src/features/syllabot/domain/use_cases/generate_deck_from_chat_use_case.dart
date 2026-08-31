import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/syllabot_repository.dart';

class GenerateDeckFromChatUseCase {
  const GenerateDeckFromChatUseCase(this._repository);

  final SyllabotRepository _repository;

  Future<Either<Failure, DeckEntity>> call({
    required String sessionId,
    required String deckTitle,
    required String courseCode,
    List<ChatMessageEntity> messages = const [],
  }) {
    return _repository.generateDeckFromChat(
      sessionId: sessionId,
      deckTitle: deckTitle,
      courseCode: courseCode,
      messages: messages,
    );
  }
}
