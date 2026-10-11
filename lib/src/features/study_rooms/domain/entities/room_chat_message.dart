/// Ephemeral chat message exchanged in a live study room.
class RoomChatMessage {
  const RoomChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.timestamp,
    this.isReaction = false,
  });

  factory RoomChatMessage.fromJson(Map<String, dynamic> json) {
    return RoomChatMessage(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? 'Scholar',
      senderAvatar: json['senderAvatar'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isReaction: json['isReaction'] as bool? ?? false,
    );
  }

  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final DateTime timestamp;
  final bool isReaction;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isReaction': isReaction,
    };
  }
}
