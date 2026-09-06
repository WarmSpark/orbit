class ChatMessage {
  final String id;
  final String roomId;
  final String senderHandle;
  final String message;
  final String type;
  final DateTime timestamp;
  final String? replyToId;
  final String? replyToText;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderHandle,
    required this.message,
    required this.type,
    required this.timestamp,
    this.replyToId,
    this.replyToText,
  });

  bool get isSystem => type == 'system';

  String get displayName =>
      senderHandle.startsWith('@') ? senderHandle.substring(1) : senderHandle;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: (json['id'] ?? '').toString(),
    roomId: (json['room_id'] ?? '').toString(),
    senderHandle: (json['sender_handle'] ?? '') as String,
    message: (json['message'] ?? '') as String,
    type: (json['type'] ?? 'chat') as String,
    timestamp:
        DateTime.tryParse('${json['time_stamp'] ?? ''}')?.toLocal() ??
        DateTime.now(),
    replyToId: (json['reply_to_id'] as String?)?.isEmpty ?? true
        ? null
        : json['reply_to_id'] as String?,
    replyToText: (json['reply_to_text'] as String?)?.isEmpty ?? true
        ? null
        : json['reply_to_text'] as String?,
  );
}
