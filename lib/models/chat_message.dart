enum MessageRole { user, assistant }

class ChatMessage {
  final String content;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.role,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'],
      role: MessageRole.values.firstWhere((e) => e.name == json['role']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
