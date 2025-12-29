import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/thread.dart';
import '../../models/message.dart';
import 'threads_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Thread thread;

  const ChatScreen({super.key, required this.thread});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.thread.id));

    // Scroll to bottom when new messages arrive
    ref.listen(chatProvider(widget.thread.id), (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.streamingContent != next.streamingContent) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.thread.projectHint ?? 'General'),
            if (chatState.currentStep != null)
              Text(
                chatState.currentStep!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
          ],
        ),
        actions: [
          if (widget.thread.llmOverride != null)
            Chip(
              label: Text(
                widget.thread.llmOverride!,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(chatState),
          ),
          if (chatState.pendingConfirmation != null)
            _buildConfirmationBar(chatState),
          _buildInputBar(chatState),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatState chatState) {
    final messages = chatState.messages;
    final hasStreamingContent =
        chatState.isStreaming && chatState.streamingContent != null;

    if (messages.isEmpty && !hasStreamingContent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Start the conversation',
              style: TextStyle(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (hasStreamingContent ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && hasStreamingContent) {
          return _MessageBubble(
            message: Message(
              id: 'streaming',
              threadId: widget.thread.id,
              role: MessageRole.assistant,
              content: chatState.streamingContent!,
              status: MessageStatus.streaming,
              createdAt: DateTime.now(),
            ),
            isStreaming: true,
          );
        }
        return _MessageBubble(message: messages[index]);
      },
    );
  }

  Widget _buildConfirmationBar(ChatState chatState) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.withAlpha(51),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chatState.pendingConfirmation!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              ref.read(chatProvider(widget.thread.id).notifier).confirmAction(false);
            },
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              ref.read(chatProvider(widget.thread.id).notifier).confirmAction(true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatState chatState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey[800]!,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !chatState.isStreaming,
                maxLines: null,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: chatState.isStreaming
                      ? 'Waiting for response...'
                      : 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[850],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: chatState.isStreaming ? null : _sendMessage,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatProvider(widget.thread.id).notifier).sendMessage(text);
    _controller.clear();
    _focusNode.requestFocus();
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isStreaming;

  const _MessageBubble({
    required this.message,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isError = message.status == MessageStatus.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isError
                  ? Colors.red.withAlpha(51)
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                isError ? Icons.error_outline : Icons.smart_toy,
                size: 18,
                color: isError
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : isError
                        ? Colors.red.withAlpha(51)
                        : Colors.grey[850],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : null,
                    ),
                  ),
                  if (isStreaming) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(
                Icons.person,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
