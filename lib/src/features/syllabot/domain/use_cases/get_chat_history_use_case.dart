import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/conversation_session_entity.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/syllabot_repository.dart';

class GetChatHistoryUseCase {
  const GetChatHistoryUseCase(this._repository);

  final SyllabotRepository _repository;

  Future<Either<Failure, List<ConversationSessionEntity>>> getSessions() {
    return _repository.getChatSessions();
  }

  Future<Either<Failure, List<ChatMessageEntity>>> getMessages({
    required String sessionId,
  }) {
    return _repository.getSessionMessages(sessionId: sessionId);
  }

  Future<Either<Failure, void>> deleteSession({required String sessionId}) {
    return _repository.deleteChatSession(sessionId: sessionId);
  }

  Future<Either<Failure, void>> clearAll() {
    return _repository.clearAllChatSessions();
  }
}
