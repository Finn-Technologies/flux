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

  void addMessage(_Message msg) => state = [...state, msg];

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
  const ChatScreen({super.key, this.modelId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _isStreaming = false;

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
    setState(() => _isStreaming = true);
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
    if (mounted) setState(() => _isStreaming = false);
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
    final currentModel = widget.modelId ?? 'Gemma 4 E2B';

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: colorScheme.onSurface),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title:
            _ModelSelector(modelName: currentModel, colorScheme: colorScheme),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: colorScheme.onSurfaceVariant),
              tooltip: 'Clear chat',
              onPressed: () {
                ref.read(chatMessagesProvider.notifier).clear();
                setState(() => _isStreaming = false);
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const FluxDrawer(currentItem: NavItem.chat),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _WelcomeView(
                    colorScheme: colorScheme,
                    onPresetTap: (preset) {
                      _controller.text = preset;
                      _sendMessage();
                    })
                : _MessagesList(
                    messages: messages,
                    scrollController: _scrollController,
                    colorScheme: colorScheme,
                  ),
          ),
          if (_isStreaming)
            _StreamingBanner(
                colorScheme: colorScheme,
                onStop: () => setState(() => _isStreaming = false)),
          _ChatInputBar(
            controller: _controller,
            focusNode: _focusNode,
            onSend: _sendMessage,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

class _ModelSelector extends StatelessWidget {
  final String modelName;
  final ColorScheme colorScheme;

  const _ModelSelector({required this.modelName, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Icon(Icons.smart_toy, size: 16, color: colorScheme.onPrimary),
          ),
          const SizedBox(width: 10),
          Text(modelName,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(Icons.unfold_more,
              size: 18, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  final ColorScheme colorScheme;
  final void Function(String) onPresetTap;

  const _WelcomeView({required this.colorScheme, required this.onPresetTap});

  @override
  Widget build(BuildContext context) {
    final presets = [
      'Explain quantum computing simply',
      'Write a Python script to sort a list',
      'Summarize this article for me',
      'Help me plan a weekend trip',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.smart_toy,
                size: 32, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text(
            'What can I help you with?',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'All conversations stay on your device.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          ...presets.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PresetCard(
                    preset: p,
                    onTap: () => onPresetTap(p),
                    colorScheme: colorScheme),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final String preset;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _PresetCard(
      {required this.preset, required this.onTap, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(preset, style: const TextStyle(fontSize: 14)),
              ),
              Icon(Icons.north_west,
                  size: 16, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesList extends StatelessWidget {
  final List<_Message> messages;
  final ScrollController scrollController;
  final ColorScheme colorScheme;

  const _MessagesList({
    required this.messages,
    required this.scrollController,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final showModelAvatar = index == messages.length - 1 ||
            (index < messages.length - 1 && messages[index + 1].fromUser);
        return _Bubble(
            msg: msg,
            showModelAvatar: showModelAvatar,
            colorScheme: colorScheme);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Message msg;
  final bool showModelAvatar;
  final ColorScheme colorScheme;

  const _Bubble(
      {required this.msg,
      required this.showModelAvatar,
      required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.fromUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            AnimatedOpacity(
              opacity: showModelAvatar ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.smart_toy,
                    size: 14, color: colorScheme.onPrimary),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          isUser ? const Radius.circular(18) : Radius.zero,
                      bottomRight:
                          isUser ? Radius.zero : const Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isUser
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
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
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _StreamingBanner extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onStop;

  const _StreamingBanner({required this.colorScheme, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _WaveDots(color: colorScheme.primary),
          const SizedBox(width: 10),
          Text('Generating',
              style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          TextButton(
            onPressed: onStop,
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text('Stop',
                style: TextStyle(fontSize: 12, color: colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

class _WaveDots extends StatefulWidget {
  final Color color;
  const _WaveDots({required this.color});

  @override
  State<_WaveDots> createState() => _WaveDotsState();
}

class _WaveDotsState extends State<_WaveDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
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
            final t = ((_ctrl.value + i * 0.33) % 1.0);
            final scale = 0.4 + (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.6;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 5,
              height: 5,
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
  final ColorScheme colorScheme;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.colorScheme,
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
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _showAttachmentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.image_outlined,
                      color: widget.colorScheme.onPrimaryContainer),
                ),
                title: const Text('Photo'),
                subtitle: const Text('Attach from gallery'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.document_scanner_outlined,
                      color: widget.colorScheme.onPrimaryContainer),
                ),
                title: const Text('Document'),
                subtitle: const Text('Attach a PDF or text file'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt_outlined,
                      color: widget.colorScheme.onPrimaryContainer),
                ),
                title: const Text('Camera'),
                subtitle: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottom + 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(Icons.add_circle_outline,
                color: colorScheme.onSurfaceVariant),
            onPressed: () => _showAttachmentSheet(context),
            iconSize: 22,
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Message Flux…',
                  hintStyle: TextStyle(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _SendButton(
              hasText: _hasText,
              colorScheme: colorScheme,
              onSend: widget.onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool hasText;
  final ColorScheme colorScheme;
  final VoidCallback onSend;

  const _SendButton(
      {required this.hasText, required this.colorScheme, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: hasText ? 40 : 0,
      curve: Curves.easeOut,
      child: hasText
          ? Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_upward, color: colorScheme.onPrimary),
                onPressed: onSend,
                iconSize: 20,
                padding: EdgeInsets.zero,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
