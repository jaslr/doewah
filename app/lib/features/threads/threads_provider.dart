import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/thread.dart';
import '../../models/message.dart';
import '../../core/websocket/websocket_service.dart';

/// State for managing threads
class ThreadsState {
  final List<Thread> threads;
  final bool isLoading;
  final String? error;

  const ThreadsState({
    this.threads = const [],
    this.isLoading = false,
    this.error,
  });

  ThreadsState copyWith({
    List<Thread>? threads,
    bool? isLoading,
    String? error,
  }) {
    return ThreadsState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Threads state notifier
class ThreadsNotifier extends StateNotifier<ThreadsState> {
  final WebSocketService _wsService;

  ThreadsNotifier(this._wsService) : super(const ThreadsState()) {
    _listenToMessages();
  }

  void _listenToMessages() {
    _wsService.messages.listen((message) {
      switch (message.type) {
        case 'thread.created':
          _handleThreadCreated(message.data);
          break;
        case 'thread.updated':
          _handleThreadUpdated(message.data);
          break;
        case 'thread.deleted':
          _handleThreadDeleted(message.data);
          break;
        case 'error':
          _handleError(message.data);
          break;
      }
    });
  }

  void _handleError(Map<String, dynamic> data) {
    final error = data['error'] as String? ?? 'Unknown error';
    debugPrint('[Threads] Server error: $error');
    state = state.copyWith(error: error, isLoading: false);
  }

  void _handleThreadCreated(Map<String, dynamic> data) {
    final thread = Thread.fromJson(data);
    state = state.copyWith(
      threads: [thread, ...state.threads],
    );
  }

  void _handleThreadUpdated(Map<String, dynamic> data) {
    final updatedThread = Thread.fromJson(data);
    state = state.copyWith(
      threads: state.threads.map((t) {
        return t.id == updatedThread.id ? updatedThread : t;
      }).toList(),
    );
  }

  void _handleThreadDeleted(Map<String, dynamic> data) {
    final threadId = data['threadId'] as String;
    state = state.copyWith(
      threads: state.threads.where((t) => t.id != threadId).toList(),
    );
  }

  void createThread({String? projectHint}) {
    _wsService.createThread(projectHint: projectHint);
  }

  void closeThread(String threadId) {
    _wsService.closeThread(threadId);
    state = state.copyWith(
      threads: state.threads.where((t) => t.id != threadId).toList(),
    );
  }
}

/// Provider for threads state
final threadsProvider =
    StateNotifierProvider<ThreadsNotifier, ThreadsState>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return ThreadsNotifier(wsService);
});

/// State for a single thread's messages
class ChatState {
  final List<Message> messages;
  final bool isStreaming;
  final String? currentStep;
  final String? streamingContent;
  final String? pendingConfirmation;
  final String? pendingActionId;

  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.currentStep,
    this.streamingContent,
    this.pendingConfirmation,
    this.pendingActionId,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isStreaming,
    String? currentStep,
    String? streamingContent,
    String? pendingConfirmation,
    String? pendingActionId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      currentStep: currentStep,
      streamingContent: streamingContent,
      pendingConfirmation: pendingConfirmation,
      pendingActionId: pendingActionId,
    );
  }
}

/// Chat state notifier for a specific thread
class ChatNotifier extends StateNotifier<ChatState> {
  final String threadId;
  final WebSocketService _wsService;
  String? _currentMessageId;

  ChatNotifier(this.threadId, this._wsService) : super(const ChatState()) {
    _listenToMessages();
  }

  void _listenToMessages() {
    _wsService.messages.listen((message) {
      if (message.threadId != threadId) return;

      switch (message.type) {
        case 'stream.start':
          _handleStreamStart(message);
          break;
        case 'stream.chunk':
          _handleStreamChunk(message);
          break;
        case 'stream.step':
          _handleStreamStep(message);
          break;
        case 'stream.end':
          _handleStreamEnd();
          break;
        case 'action.confirm':
          _handleActionConfirm(message);
          break;
        case 'action.complete':
          _handleActionComplete(message);
          break;
        case 'action.error':
          _handleActionError(message);
          break;
      }
    });
  }

  void _handleStreamStart(ServerMessage message) {
    _currentMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    state = state.copyWith(
      isStreaming: true,
      streamingContent: '',
    );
  }

  void _handleStreamChunk(ServerMessage message) {
    final newContent = (state.streamingContent ?? '') + (message.text ?? '');
    state = state.copyWith(streamingContent: newContent);
  }

  void _handleStreamStep(ServerMessage message) {
    state = state.copyWith(currentStep: message.step);
  }

  void _handleStreamEnd() {
    if (state.streamingContent != null && state.streamingContent!.isNotEmpty) {
      final newMessage = Message(
        id: _currentMessageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        threadId: threadId,
        role: MessageRole.assistant,
        content: state.streamingContent!,
        status: MessageStatus.complete,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, newMessage],
        isStreaming: false,
        streamingContent: null,
        currentStep: null,
      );
    } else {
      state = state.copyWith(
        isStreaming: false,
        streamingContent: null,
        currentStep: null,
      );
    }
    _currentMessageId = null;
  }

  void _handleActionConfirm(ServerMessage message) {
    state = state.copyWith(
      pendingConfirmation: message.prompt,
      pendingActionId: message.actionId,
    );
  }

  void _handleActionComplete(ServerMessage message) {
    state = state.copyWith(
      pendingConfirmation: null,
      pendingActionId: null,
    );
  }

  void _handleActionError(ServerMessage message) {
    final errorMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      threadId: threadId,
      role: MessageRole.system,
      content: message.error ?? 'An error occurred',
      status: MessageStatus.error,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, errorMessage],
      isStreaming: false,
      streamingContent: null,
      currentStep: null,
    );
  }

  void sendMessage(String content, {String? llm}) {
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      threadId: threadId,
      role: MessageRole.user,
      content: content,
      status: MessageStatus.complete,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, userMessage]);
    _wsService.sendMessage(threadId, content, llm: llm);
  }

  void confirmAction(bool confirmed) {
    if (state.pendingActionId != null) {
      _wsService.confirmAction(state.pendingActionId!, confirmed);
      state = state.copyWith(
        pendingConfirmation: null,
        pendingActionId: null,
      );
    }
  }
}

/// Provider family for chat state per thread
final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, threadId) {
  final wsService = ref.watch(webSocketServiceProvider);
  return ChatNotifier(threadId, wsService);
});
