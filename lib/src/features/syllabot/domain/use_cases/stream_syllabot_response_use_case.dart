import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/syllabot_repository.dart';

class StreamSyllabotResponseUseCase {
  const StreamSyllabotResponseUseCase(this._repository);

  final SyllabotRepository _repository;

  Stream<String> call({
    required String prompt,
    required String sessionId,
    required SocraticMode socraticMode,
    required ExecutionEngineType preferredEngine,
    List<ChatMessageEntity> contextHistory = const [],
  }) {
    return _repository.streamResponse(
      prompt: prompt,
      sessionId: sessionId,
      socraticMode: socraticMode,
      preferredEngine: preferredEngine,
      contextHistory: contextHistory,
    );
  }
}
