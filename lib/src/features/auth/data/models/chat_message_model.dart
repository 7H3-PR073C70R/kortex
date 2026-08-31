import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/auth/domain/entities/chat_auth_message.dart';

part 'chat_message_model.freezed.dart';
part 'chat_message_model.g.dart';

@freezed
abstract class ChatMessageModel with _$ChatMessageModel {
  const factory ChatMessageModel({
    required String id,
    required String sender,
    required String text,
    required String timestamp,
    @Default('initial') String step,
    @Default(false) bool isPasswordInput,
  }) = _ChatMessageModel;

  const ChatMessageModel._();

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageModelFromJson(json);

  ChatAuthMessage toEntity() {
    return ChatAuthMessage(
      id: id,
      sender: sender == 'syllabot'
          ? ChatAuthSender.syllabot
          : ChatAuthSender.user,
      text: text,
      timestamp: DateTime.tryParse(timestamp) ?? DateTime.now(),
      step: ChatAuthStep.values.firstWhere(
        (e) => e.name == step,
        orElse: () => ChatAuthStep.initial,
      ),
      isPasswordInput: isPasswordInput,
    );
  }
}
