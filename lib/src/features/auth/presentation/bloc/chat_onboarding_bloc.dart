import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

enum ChatSender {
  ai,
  user,
}

enum EmbeddedWidgetType {
  trackPicker,
  goalSlider,
  summaryReady,
}

class ChatOnboardingMessage extends Equatable {
  const ChatOnboardingMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.embeddedWidgetType,
  });

  final String id;
  final ChatSender sender;
  final String text;
  final DateTime timestamp;
  final EmbeddedWidgetType? embeddedWidgetType;

  @override
  List<Object?> get props => [id, sender, text, timestamp, embeddedWidgetType];
}

abstract class ChatOnboardingEvent extends Equatable {
  const ChatOnboardingEvent();

  @override
  List<Object?> get props => [];
}

class ChatOnboardingStarted extends ChatOnboardingEvent {
  const ChatOnboardingStarted();
}

class ChatOnboardingUserMessageSent extends ChatOnboardingEvent {
  const ChatOnboardingUserMessageSent(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

class ChatOnboardingTrackChosen extends ChatOnboardingEvent {
  const ChatOnboardingTrackChosen(this.trackName);

  final String trackName;

  @override
  List<Object?> get props => [trackName];
}

class ChatOnboardingGoalChosen extends ChatOnboardingEvent {
  const ChatOnboardingGoalChosen({
    required this.dailyTarget,
    required this.retentionPercent,
  });

  final int dailyTarget;
  final int retentionPercent;

  @override
  List<Object?> get props => [dailyTarget, retentionPercent];
}

class ChatOnboardingState extends Equatable {
  const ChatOnboardingState({
    this.messages = const [],
    this.isThinking = false,
    this.currentStep = 0,
  });

  final List<ChatOnboardingMessage> messages;
  final bool isThinking;
  final int currentStep;

  ChatOnboardingState copyWith({
    List<ChatOnboardingMessage>? messages,
    bool? isThinking,
    int? currentStep,
  }) {
    return ChatOnboardingState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  @override
  List<Object?> get props => [messages, isThinking, currentStep];
}

class ChatOnboardingBloc
    extends Bloc<ChatOnboardingEvent, ChatOnboardingState> {
  ChatOnboardingBloc() : super(const ChatOnboardingState()) {
    on<ChatOnboardingStarted>(_onStarted);
    on<ChatOnboardingUserMessageSent>(_onUserMessageSent);
    on<ChatOnboardingTrackChosen>(_onTrackChosen);
    on<ChatOnboardingGoalChosen>(_onGoalChosen);
  }

  Future<void> _onStarted(
    ChatOnboardingStarted event,
    Emitter<ChatOnboardingState> emit,
  ) async {
    if (state.messages.isNotEmpty) return;

    final initialMessages = [
      ChatOnboardingMessage(
        id: 'msg_welcome',
        sender: ChatSender.ai,
        text: 'Hello! I am Syllabot, your AI Academic Guide. '
            'I will help configure your optimal study plan, spaced repetition '
            'intervals, and target curriculum.',
        timestamp: DateTime.now(),
      ),
      ChatOnboardingMessage(
        id: 'msg_pick_track',
        sender: ChatSender.ai,
        text: 'First, which examination or academic track are you preparing '
            'for?',
        timestamp: DateTime.now().add(const Duration(milliseconds: 200)),
        embeddedWidgetType: EmbeddedWidgetType.trackPicker,
      ),
    ];

    emit(state.copyWith(messages: initialMessages, currentStep: 0));
  }

  Future<void> _onTrackChosen(
    ChatOnboardingTrackChosen event,
    Emitter<ChatOnboardingState> emit,
  ) async {
    final userMsg = ChatOnboardingMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      sender: ChatSender.user,
      text: 'I choose the ${event.trackName} track.',
      timestamp: DateTime.now(),
    );

    final updated = List<ChatOnboardingMessage>.from(state.messages)
      ..add(userMsg);
    emit(state.copyWith(messages: updated, isThinking: true));

    await Future<void>.delayed(const Duration(milliseconds: 400));

    final aiResponse = ChatOnboardingMessage(
      id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
      sender: ChatSender.ai,
      text: 'Excellent choice! ${event.trackName} is aligned with our '
          'AI-curated question banks and dynamic mock schedules. '
          'Now, calibrate your daily spaced-repetition target cards:',
      timestamp: DateTime.now(),
      embeddedWidgetType: EmbeddedWidgetType.goalSlider,
    );

    emit(
      state.copyWith(
        messages: List<ChatOnboardingMessage>.from(updated)..add(aiResponse),
        isThinking: false,
        currentStep: 1,
      ),
    );
  }

  Future<void> _onGoalChosen(
    ChatOnboardingGoalChosen event,
    Emitter<ChatOnboardingState> emit,
  ) async {
    final userMsg = ChatOnboardingMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      sender: ChatSender.user,
      text: 'Target set: ${event.dailyTarget} cards/day '
          '(${event.retentionPercent}% retention).',
      timestamp: DateTime.now(),
    );

    final updated = List<ChatOnboardingMessage>.from(state.messages)
      ..add(userMsg);
    emit(state.copyWith(messages: updated, isThinking: true));

    await Future<void>.delayed(const Duration(milliseconds: 400));

    final aiResponse = ChatOnboardingMessage(
      id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
      sender: ChatSender.ai,
      text: 'Great commitment! Your personalized Ebbinghaus retention curve is '
          'calibrated. You are ready to launch your learning workspace:',
      timestamp: DateTime.now(),
      embeddedWidgetType: EmbeddedWidgetType.summaryReady,
    );

    emit(
      state.copyWith(
        messages: List<ChatOnboardingMessage>.from(updated)..add(aiResponse),
        isThinking: false,
        currentStep: 2,
      ),
    );
  }

  Future<void> _onUserMessageSent(
    ChatOnboardingUserMessageSent event,
    Emitter<ChatOnboardingState> emit,
  ) async {
    if (event.text.trim().isEmpty) return;

    final userMsg = ChatOnboardingMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      sender: ChatSender.user,
      text: event.text.trim(),
      timestamp: DateTime.now(),
    );

    final updated = List<ChatOnboardingMessage>.from(state.messages)
      ..add(userMsg);
    emit(state.copyWith(messages: updated, isThinking: true));

    await Future<void>.delayed(const Duration(milliseconds: 600));

    final aiResponse = ChatOnboardingMessage(
      id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
      sender: ChatSender.ai,
      text: 'Got it! I will adapt your curriculum accordingly. '
          'Please confirm your selections to complete the onboarding.',
      timestamp: DateTime.now(),
    );

    emit(
      state.copyWith(
        messages: List<ChatOnboardingMessage>.from(updated)..add(aiResponse),
        isThinking: false,
      ),
    );
  }
}
