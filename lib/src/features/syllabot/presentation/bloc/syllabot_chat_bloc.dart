import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/generate_deck_from_chat_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/get_chat_history_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/query_document_context_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';

class SyllabotChatBloc extends Bloc<SyllabotChatEvent, SyllabotChatState> {
  SyllabotChatBloc({
    required StreamSyllabotResponseUseCase streamResponseUseCase,
    required GetChatHistoryUseCase getChatHistoryUseCase,
    required GenerateDeckFromChatUseCase generateDeckUseCase,
    QueryDocumentContextUseCase? queryDocumentContextUseCase,
    LocalStorageService? localStorageService,
  }) : _streamResponse = streamResponseUseCase,
       _getChatHistory = getChatHistoryUseCase,
       _generateDeck = generateDeckUseCase,
       _queryDocumentContext = queryDocumentContextUseCase,
       _localStorageService = localStorageService,
       super(const SyllabotChatState()) {
    on<SubmitPromptEvent>(_onSubmitPrompt);
    on<StreamTokenReceivedEvent>(_onStreamTokenReceived);
    on<StreamCompletedEvent>(_onStreamCompleted);
    on<StreamErrorEvent>(_onStreamError);
    on<RetryLastMessageEvent>(_onRetryLastMessage);
    on<ChangeSocraticModeEvent>(_onChangeSocraticMode);
    on<ChangeEngineTypeEvent>(_onChangeEngineType);
    on<LoadChatMessagesEvent>(_onLoadChatMessages);
    on<StartNewSessionEvent>(_onStartNewSession);
    on<ClearAllHistoryEvent>(_onClearAllHistory);
    on<ConvertToDeckEvent>(_onConvertToDeck);
  }

  final StreamSyllabotResponseUseCase _streamResponse;
  final GetChatHistoryUseCase _getChatHistory;
  final GenerateDeckUseCase _generateDeck;
  final QueryDocumentContextUseCase? _queryDocumentContext;
  final LocalStorageService? _localStorageService;

  StreamSubscription<String>? _streamSubscription;

  Future<void> _onSubmitPrompt(
    SubmitPromptEvent event,
    Emitter<SyllabotChatState> emit,
  ) async {
    await _streamSubscription?.cancel();

    final effectiveSessionId = event.sessionId.isNotEmpty
        ? event.sessionId
        : (state.sessionId.isNotEmpty ? state.sessionId : UuidUtils.generate());

    final userMessage = ChatMessageEntity(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: effectiveSessionId,
      sender: MessageSender.user,
      text: event.prompt,
      timestamp: DateTime.now(),
      engineType: event.engineType,
    );

    final updatedMessages = [...state.messages, userMessage];

    final isOffline = event.engineType == ExecutionEngineType.localOnDevice;

    // Automatically create and register conversation session if starting new dialogue
    if (state.messages.isEmpty) {
      unawaited(
        _getChatHistory.createSession(
          title: event.prompt,
          socraticMode: event.socraticMode,
          id: effectiveSessionId,
          isOffline: isOffline,
        ),
      );
    }

    if (isOffline) {
      unawaited(_getChatHistory.cacheMessage(userMessage));
    }

    emit(
      state.copyWith(
        status: SyllabotStatus.streaming,
        messages: updatedMessages,
        sessionId: effectiveSessionId,
        socraticMode: event.socraticMode,
        engineType: event.engineType,
        lastPrompt: event.prompt,
        lastEngine: event.engineType,
        lastSocraticMode: event.socraticMode,
      ),
    );

    var contextWithRag = updatedMessages;
    if (_queryDocumentContext != null && !isOffline) {
      final ragRes = await _queryDocumentContext(
        query: event.prompt,
      );
      ragRes.fold(
        (_) {},
        (chunks) {
          if (chunks.isNotEmpty) {
            final snippets = chunks.map((c) => c.content).join('\n---\n');
            final ragContextMsg = ChatMessageEntity(
              id: 'rag_${DateTime.now().millisecondsSinceEpoch}',
              sessionId: effectiveSessionId,
              sender: MessageSender.syllabot,
              text:
                  'Use the following retrieved course material to answer '
                  "the student's question accurately:\n$snippets",
              timestamp: DateTime.now(),
              engineType: event.engineType,
            );
            contextWithRag = [ragContextMsg, ...updatedMessages];
          }
        },
      );
    }

    final stream = _streamResponse(
      prompt: event.prompt,
      sessionId: effectiveSessionId,
      socraticMode: event.socraticMode,
      preferredEngine: event.engineType,
      contextHistory: contextWithRag,
    );

    _streamSubscription = stream.listen(
      (token) => add(StreamTokenReceivedEvent(token)),
      onError: (Object err) => add(StreamErrorEvent(err.toString())),
      onDone: () => add(const StreamCompletedEvent()),
      cancelOnError: true,
    );
  }

  void _onStreamTokenReceived(
    StreamTokenReceivedEvent event,
    Emitter<SyllabotChatState> emit,
  ) {
    emit(
      state.copyWith(
        streamingText: state.streamingText + event.token,
      ),
    );
  }

  void _onStreamCompleted(
    StreamCompletedEvent event,
    Emitter<SyllabotChatState> emit,
  ) {
    if (state.streamingText.trim().isEmpty) {
      emit(state.copyWith(status: SyllabotStatus.idle));
      return;
    }

    final botMessage = ChatMessageEntity(
      id: 'msg_bot_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: state.sessionId,
      sender: MessageSender.syllabot,
      text: state.streamingText,
      timestamp: DateTime.now(),
      engineType: state.engineType,
    );

    if (state.engineType == ExecutionEngineType.localOnDevice) {
      unawaited(_getChatHistory.cacheMessage(botMessage));
    }

    emit(
      state.copyWith(
        status: SyllabotStatus.idle,
        messages: [...state.messages, botMessage],
        streamingText: '',
      ),
    );
  }

  void _onStreamError(
    StreamErrorEvent event,
    Emitter<SyllabotChatState> emit,
  ) {
    final errorMessage = ChatMessageEntity(
      id: 'msg_err_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: state.sessionId,
      sender: MessageSender.syllabot,
      text: state.streamingText.isNotEmpty
          ? state.streamingText
          : 'Failed to complete Syllabot response. Tap retry to reconnect.',
      timestamp: DateTime.now(),
      engineType: state.engineType,
      isError: true,
      onRetry: () => add(const RetryLastMessageEvent()),
    );

    emit(
      state.copyWith(
        status: SyllabotStatus.error,
        messages: [...state.messages, errorMessage],
        streamingText: '',
        errorMessage: event.message,
      ),
    );
  }

  void _onRetryLastMessage(
    RetryLastMessageEvent event,
    Emitter<SyllabotChatState> emit,
  ) {
    if (state.lastPrompt == null) return;

    // Remove last error message if present
    final cleanedMessages = List<ChatMessageEntity>.from(state.messages);
    if (cleanedMessages.isNotEmpty && cleanedMessages.last.isError) {
      cleanedMessages.removeLast();
    }

    add(
      SubmitPromptEvent(
        prompt: state.lastPrompt!,
        sessionId: state.sessionId,
        socraticMode: state.lastSocraticMode ?? state.socraticMode,
        engineType: state.lastEngine ?? state.engineType,
        contextHistory: cleanedMessages,
      ),
    );
  }

  void _onChangeSocraticMode(
    ChangeSocraticModeEvent event,
    Emitter<SyllabotChatState> emit,
  ) {
    emit(state.copyWith(socraticMode: event.mode));
  }

  void _onChangeEngineType(
    ChangeEngineTypeEvent event,
    Emitter<SyllabotChatState> emit,
  ) {
    emit(
      state.copyWith(
        engineType: event.engine,
        status: state.status == SyllabotStatus.error
            ? SyllabotStatus.idle
            : state.status,
      ),
    );
  }

  Future<void> _onLoadChatMessages(
    LoadChatMessagesEvent event,
    Emitter<SyllabotChatState> emit,
  ) async {
    var isConverted = false;
    try {
      final storage = _localStorageService ??
          (locator.isRegistered<LocalStorageService>()
              ? locator<LocalStorageService>()
              : null);
      if (storage != null) {
        isConverted =
            storage.getPreference(
              key: 'syllabot_converted_${event.sessionId}',
            ) !=
            null;
      }
    } on Object catch (_) {}

    emit(
      state.copyWith(
        status: SyllabotStatus.loading,
        sessionId: event.sessionId,
        isConvertedToDeck: isConverted,
      ),
    );
    final result = await _getChatHistory.getMessages(
      sessionId: event.sessionId,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SyllabotStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (messages) => emit(
        state.copyWith(
          status: SyllabotStatus.idle,
          messages: messages,
        ),
      ),
    );
  }

  void _onStartNewSession(
    StartNewSessionEvent event,
    Emitter<SyllabotChatState> emit,
  ) {
    emit(
      state.copyWith(
        status: SyllabotStatus.idle,
        sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
        messages: [],
        streamingText: '',
        isConvertedToDeck: false,
      ),
    );
  }

  Future<void> _onClearAllHistory(
    ClearAllHistoryEvent event,
    Emitter<SyllabotChatState> emit,
  ) async {
    await _getChatHistory.clearAll();
    emit(const SyllabotChatState());
  }

  Future<void> _onConvertToDeck(
    ConvertToDeckEvent event,
    Emitter<SyllabotChatState> emit,
  ) async {
    emit(state.copyWith(status: SyllabotStatus.generatingDeck));
    final result = await _generateDeck(
      sessionId: event.sessionId,
      deckTitle: event.deckTitle,
      courseCode: event.courseCode,
      messages: state.messages,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SyllabotStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (deck) {
        try {
          final storage = _localStorageService ??
              (locator.isRegistered<LocalStorageService>()
                  ? locator<LocalStorageService>()
                  : null);
          if (storage != null) {
            unawaited(
              storage.savePreference(
                key: 'syllabot_converted_${event.sessionId}',
                data: deck.id,
              ),
            );
          }
        } on Object catch (_) {}

        emit(
          state.copyWith(
            status: SyllabotStatus.deckGenerated,
            generatedDeck: deck,
            isConvertedToDeck: true,
          ),
        );
      },
    );
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}

typedef GenerateDeckUseCase = GenerateDeckFromChatUseCase;
