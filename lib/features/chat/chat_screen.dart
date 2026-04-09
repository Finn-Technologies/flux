import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/flux_drawer.dart';
import '../../core/services/inference_service.dart';

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<_Message>>((ref) {
  return ChatMessagesNotifier();
});

final isStreamingProvider = StateProvider<bool>((ref) => false);

class ChatMessagesNotifier extends StateNotifier<List<_Message>> {
  ChatMessagesNotifier() : super([]);

  void addMessage(_Message msg) {
    state = [...state, msg];
  }

  void updateLastMessage(_Message msg) {
    if (state.isNotEmpty && !state.last.fromUser) {
      state = [...state.sublist(0, state.length - 1), msg];
    } else {
      state = [...state, msg];
    }
  }

  void clear() => state = [];
}

class _Message {
  final String text;
  final bool fromUser;
  final DateTime time;
  _Message({required this.text, required this.fromUser, required this.time});
}

class ChatScreen extends ConsumerStatefulWidget {
  final String? modelId;
  const ChatScreen({super.key, this.modelId}) : super();

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatMessagesProvider.notifier).addMessage(
          _Message(text: text, fromUser: true, time: DateTime.now()),
        );
    _controller.clear();
    _focusNode.unfocus();
    _scrollToBottom();

    final model = widget.modelId ?? 'Gemma 4 E2B';
    ref.read(isStreamingProvider.notifier).state = true;
    String accumulated = '';
    final stream = InferenceService().streamChat(modelId: model, prompt: text);

    await for (final token in stream) {
      if (!mounted) break;
      accumulated += token;
      ref.read(chatMessagesProvider.notifier).updateLastMessage(
            _Message(text: accumulated, fromUser: false, time: DateTime.now()),
          );
      _scrollToBottom();
    }
    if (mounted) ref.read(isStreamingProvider.notifier).state = false;
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

  void _newChat() {
    ref.read(chatMessagesProvider.notifier).clear();
    ref.read(isStreamingProvider.notifier).state = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final messages = ref.watch(chatMessagesProvider);
    final isStreaming = ref.watch(isStreamingProvider);
    final currentModel = widget.modelId ?? 'Gemma 4 E2B';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: colorScheme.onSurface),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(Icons.smart_toy, size: 16, color: colorScheme.onPrimary),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentModel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon:
                Icon(Icons.edit_outlined, color: colorScheme.onSurfaceVariant),
            onPressed: _newChat,
            tooltip: 'New chat',
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const FluxDrawer(currentItem: NavItem.chat),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !isStreaming
                ? _WelcomeView()
                : _MessageList(
                    messages: messages,
                    scrollController: _scrollController,
                    isStreaming: isStreaming,
                  ),
          ),
          if (isStreaming) _StreamingBar(colorScheme: colorScheme),
          _ChatInputBar(
            controller: _controller,
            focusNode: _focusNode,
            onSend: _sendMessage,
            isStreaming: isStreaming,
          ),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child:
                  Icon(Icons.smart_toy, size: 40, color: colorScheme.onPrimary),
            ),
            const SizedBox(height: 28),
            Text(
              'Hello, I\'m Flux',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything. All conversations stay on your device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final List<_Message> messages;
  final ScrollController scrollController;
  final bool isStreaming;

  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.isStreaming,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final showAvatar = index == messages.length - 1 ||
            (index < messages.length - 1 && messages[index + 1].fromUser);
        return _ChatBubble(
          message: message,
          showAvatar: showAvatar,
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _Message message;
  final bool showAvatar;

  const _ChatBubble({required this.message, required this.showAvatar});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.fromUser)
            AnimatedOpacity(
              opacity: showAvatar ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 10, top: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.smart_toy,
                  size: 18,
                  color: colorScheme.onPrimary,
                ),
              ),
            )
          else
            const SizedBox(width: 42),
          Expanded(
            child: Column(
              crossAxisAlignment: message.fromUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.fromUser
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: message.fromUser
                          ? const Radius.circular(20)
                          : Radius.zero,
                      bottomRight: message.fromUser
                          ? Radius.zero
                          : const Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: message.fromUser
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4),
                  child: Text(
                    _formatTime(message.time),
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.fromUser) const SizedBox(width: 42),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _StreamingBar extends StatelessWidget {
  final ColorScheme colorScheme;
  const _StreamingBar({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _DotsIndicator(color: colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            'Generating',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              // Stop streaming - would need to cancel the stream
            },
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              'Stop',
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatefulWidget {
  final Color color;
  const _DotsIndicator({required this.color});

  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (i - 1) * 0.2;
            final animValue = (((_ctrl.value + offset) % 1.0));
            final scale = 0.5 +
                (animValue < 0.5 ? animValue * 2 : (1 - animValue) * 2) * 0.5;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: scale),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isStreaming;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isStreaming,
  });

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding + 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {},
              iconSize: 22,
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  maxLines: null,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Message Flux...',
                    hintStyle: TextStyle(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                  ),
                ),
              ),
            ),
            _MicButton(hasText: _hasText, colorScheme: colorScheme),
            _SendButton(
              hasText: _hasText,
              isStreaming: widget.isStreaming,
              colorScheme: colorScheme,
              onPressed: widget.onSend,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool hasText;
  final ColorScheme colorScheme;

  const _MicButton({required this.hasText, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.mic_none,
        color: colorScheme.onSurfaceVariant,
      ),
      onPressed: () {},
      iconSize: 22,
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool hasText;
  final bool isStreaming;
  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  const _SendButton({
    required this.hasText,
    required this.isStreaming,
    required this.colorScheme,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: hasText ? 42 : 0,
      curve: Curves.easeOut,
      child: hasText
          ? Container(
              margin: const EdgeInsets.only(right: 4, bottom: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_upward,
                  color: colorScheme.onPrimary,
                ),
                onPressed: isStreaming ? null : onPressed,
                iconSize: 20,
                padding: EdgeInsets.zero,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
