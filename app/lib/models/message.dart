/// Message status
enum MessageStatus { pending, streaming, complete, error }

/// Message role
enum MessageRole { user, assistant, system }

/// Message model representing a chat message
class Message {
  final String id;
  final String threadId;
  final MessageRole role;
  final String content;
  final String? stepLabel;
  final MessageStatus status;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.threadId,
    required this.role,
    required this.content,
    this.stepLabel,
    required this.status,
    required this.createdAt,
  });

  Message copyWith({
    String? id,
    String? threadId,
    MessageRole? role,
    String? content,
    String? stepLabel,
    MessageStatus? status,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      role: role ?? this.role,
      content: content ?? this.content,
      stepLabel: stepLabel ?? this.stepLabel,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      role: MessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MessageRole.user,
      ),
      content: json['content'] as String,
      stepLabel: json['stepLabel'] as String?,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.complete,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'threadId': threadId,
      'role': role.name,
      'content': content,
      'stepLabel': stepLabel,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
