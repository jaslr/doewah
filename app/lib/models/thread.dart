/// Thread model representing a conversation
class Thread {
  final String id;
  final String? projectHint;
  final String? llmOverride;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final String? lastMessage;

  Thread({
    required this.id,
    this.projectHint,
    this.llmOverride,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.lastMessage,
  });

  Thread copyWith({
    String? id,
    String? projectHint,
    String? llmOverride,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    String? lastMessage,
  }) {
    return Thread(
      id: id ?? this.id,
      projectHint: projectHint ?? this.projectHint,
      llmOverride: llmOverride ?? this.llmOverride,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      id: json['id'] as String,
      projectHint: json['projectHint'] as String?,
      llmOverride: json['llmOverride'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isArchived: json['isArchived'] as bool? ?? false,
      lastMessage: json['lastMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectHint': projectHint,
      'llmOverride': llmOverride,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isArchived': isArchived,
      'lastMessage': lastMessage,
    };
  }
}
