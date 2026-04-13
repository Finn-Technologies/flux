import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/inference_service.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/model_provider.dart';
import '../../core/models/hf_model.dart';

import 'package:hive_flutter/hive_flutter.dart';
import '../../core/models/chat_session.dart';

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier();
});

final isStreamingProvider = StateProvider<bool>((ref) => false);

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, List<ChatSession>>((ref) {
  return ConversationsNotifier();
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier() : super([]);

  void addMessage(ChatMessage msg) => state = [...state, msg];

  void updateLastMessage(ChatMessage msg) {
    if (state.isNotEmpty && !state.last.fromUser) {
      state = [...state.sublist(0, state.length - 1), msg];
    } else {
      state = [...state, msg];
    }
  }

  void clear() => state = [];

  void setMessages(List<ChatMessage> messages) => state = messages;
}

class ConversationsNotifier extends StateNotifier<List<ChatSession>> {
  ConversationsNotifier() : super([]) {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('chats');
    final chats = box.values
        .map((v) => ChatSession.fromJson(Map<String, dynamic>.from(v)))
        .toList();
    // Sort by updatedAt descending
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = chats;
  }

  Future<void> addConversation(ChatSession conv) async {
    state = [conv, ...state];
    final box = Hive.box('chats');
    await box.put(conv.id, conv.toJson());
  }

  Future<void> updateConversation(ChatSession conv) async {
    state = [
      conv,
      ...state.where((c) => c.id != conv.id),
    ];
    final box = Hive.box('chats');
    await box.put(conv.id, conv.toJson());
  }

  Future<void> deleteConversation(String id) async {
    state = state.where((c) => c.id != id).toList();
    final box = Hive.box('chats');
    await box.delete(id);
  }
}

// ChatSession and ChatMessage are now imported from core/models/chat_session.dart

class ChatScreen extends ConsumerStatefulWidget {
  final String? modelId;
  const ChatScreen({super.key, this.modelId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _isStreaming = false;
  bool _hasText = false;
  String? _currentConversationId;

  void _newConversation() {
    if (_currentConversationId != null) {
      final messages = ref.read(chatMessagesProvider);
      if (messages.isNotEmpty) {
        final conv = ChatSession(
          id: _currentConversationId!,
          title: messages.first.text.length > 30
              ? '${messages.first.text.substring(0, 30)}...'
              : messages.first.text,
          messages: messages,
          updatedAt: DateTime.now(),
          modelId: ref.read(selectedModelProvider)?.id,
        );
        ref.read(conversationsProvider.notifier).updateConversation(conv);
      }
    }

    ref.read(chatMessagesProvider.notifier).clear();
    setState(() {
      _isStreaming = false;
      _currentConversationId = DateTime.now().millisecondsSinceEpoch.toString();
    });
  }

  void _showConversationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => _ConversationsSheet(
          scrollController: scrollController,
          onSelect: (conv) {
            Navigator.pop(ctx);
            ref.read(chatMessagesProvider.notifier).setMessages(conv.messages);
            setState(() {
              _currentConversationId = conv.id;
            });
          },
          onNewChat: () {
            Navigator.pop(ctx);
            _newConversation();
          },
        ),
      ),
    );
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    if (_currentConversationId == null) {
      _currentConversationId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    HapticFeedback.lightImpact();

    ref.read(chatMessagesProvider.notifier).addMessage(
        ChatMessage(text: text, fromUser: true, time: DateTime.now()));
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _hasText = false);
    _scrollToBottom();

    final modelId = widget.modelId;
    setState(() => _isStreaming = true);
    String accumulated = '';

    final selectedModel = ref.read(selectedModelProvider);
    final modelName = selectedModel?.id ?? modelId ?? 'default';

    if (selectedModel == null || selectedModel.localPath == null) {
      ref.read(chatMessagesProvider.notifier).updateLastMessage(
            ChatMessage(
              text:
                  "No model is currently selected or downloaded. Please visit the Library to download a model first.",
              fromUser: false,
              time: DateTime.now(),
            ),
          );
      setState(() => _isStreaming = false);
      return;
    }

    final stream = InferenceService().streamChat(
      modelId: modelName,
      prompt: text,
      localPath: selectedModel.localPath,
      systemPrompt:
          "You are Flux, a helpful and friendly AI assistant. Provide detailed and accurate responses.",
    );

    final stopwatch = Stopwatch()..start();
    await for (final token in stream) {
      if (!mounted) break;
      accumulated += token;

      // Update UI only if 50ms have passed OR generation is finished
      if (stopwatch.elapsedMilliseconds > 50) {
        ref.read(chatMessagesProvider.notifier).updateLastMessage(
              ChatMessage(
                  text: accumulated, fromUser: false, time: DateTime.now()),
            );
        _scrollToBottom();
        stopwatch.reset();
      }
    }

    // Final update to ensure everything is yielded
    if (mounted) {
      ref.read(chatMessagesProvider.notifier).updateLastMessage(
            ChatMessage(
                text: accumulated, fromUser: false, time: DateTime.now()),
          );
      _scrollToBottom();
    }
    if (mounted) {
      setState(() => _isStreaming = false);
      // Auto-save conversation state when streaming finishes
      if (_currentConversationId != null) {
        final messages = ref.read(chatMessagesProvider);
        final conv = ChatSession(
          id: _currentConversationId!,
          title: messages.first.text.length > 30
              ? '${messages.first.text.substring(0, 30)}...'
              : messages.first.text,
          messages: messages,
          updatedAt: DateTime.now(),
          modelId: selectedModel.id,
        );
        ref.read(conversationsProvider.notifier).updateConversation(conv);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (_isStreaming) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        }
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
    final selectedModel = ref.watch(selectedModelProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colorScheme.onSurface),
            onPressed: () => _showConversationsSheet(context),
          ),
        ),
        title: _ModelSelector(
          selectedModel: selectedModel,
          colorScheme: colorScheme,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: colorScheme.onSurface),
            tooltip: 'New chat',
            onPressed: _newConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _WelcomeView(
                    colorScheme: colorScheme,
                    onPresetTap: (preset) {
                      _controller.text = preset;
                      _sendMessage();
                    },
                  )
                : _MessagesList(
                    messages: messages,
                    scrollController: _scrollController,
                    colorScheme: colorScheme,
                  ),
          ),
          if (_isStreaming)
            _StreamingBanner(
              colorScheme: colorScheme,
              onStop: () => setState(() => _isStreaming = false),
            ),
          _ChatInputBar(
            controller: _controller,
            focusNode: _focusNode,
            hasText: _hasText,
            onHasTextChanged: (v) => setState(() => _hasText = v),
            onSend: _sendMessage,
            colorScheme: colorScheme,
            canAttach: selectedModel?.id != 'google/gemma-3-1b-it',
          ),
        ],
      ),
    );
  }
}

class _ConversationsSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final void Function(ChatSession) onSelect;
  final VoidCallback onNewChat;

  const _ConversationsSheet({
    required this.scrollController,
    required this.onSelect,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final conversations = ref.watch(conversationsProvider);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Chats',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.add, color: colorScheme.primary),
                  onPressed: onNewChat,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: conversations.length,
                    itemBuilder: (ctx, i) {
                      final conv = conversations[i];
                      return _ConversationTile(
                        conversation: conv,
                        onTap: () => onSelect(conv),
                        onDelete: () {
                          ref
                              .read(conversationsProvider.notifier)
                              .deleteConversation(conv.id);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatSession conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = _formatTime(conversation.updatedAt);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 20, color: colorScheme.secondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style:
                        TextStyle(fontSize: 12, color: colorScheme.secondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: colorScheme.secondary),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

class _ModelSelector extends ConsumerWidget {
  final HFModel? selectedModel;
  final ColorScheme colorScheme;

  const _ModelSelector(
      {required this.selectedModel, required this.colorScheme});

  void _showModelSheet(BuildContext context, WidgetRef ref) {
    final downloadedModels =
        ref.read(downloadProvider).where((m) => m.downloaded).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Select AI Model',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: downloadedModels.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_for_offline_outlined,
                              size: 48, color: colorScheme.secondary),
                          const SizedBox(height: 16),
                          const Text('No local models found',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text('Download a model from the Library first.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: colorScheme.secondary)),
                        ],
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: downloadedModels.length,
                        itemBuilder: (ctx, i) {
                          final m = downloadedModels[i];
                          final isCurrent = m.id == selectedModel?.id;
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.smart_toy_outlined,
                                color: isCurrent
                                    ? colorScheme.onPrimary
                                    : colorScheme.primary,
                              ),
                            ),
                            title: Text(m.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${(m.sizeMB / 1024).toStringAsFixed(1)} GB · Local Inference',
                                style: TextStyle(
                                    color: colorScheme.secondary,
                                    fontSize: 13)),
                            trailing: isCurrent
                                ? Icon(Icons.check_circle,
                                    color: colorScheme.primary)
                                : null,
                            onTap: () {
                              ref.read(selectedModelIdProvider.notifier).state =
                                  m.id;
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/models');
                  },
                  child: const Text('Visit Model Library'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = selectedModel != null;

    return GestureDetector(
      onTap: () => _showModelSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? Icons.smart_toy : Icons.download_outlined,
                size: 18,
                color:
                    isSelected ? colorScheme.onPrimary : colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSelected ? selectedModel!.name : 'No model',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? colorScheme.onSurface
                        : colorScheme.secondary,
                  ),
                ),
                Text(
                  isSelected ? 'Local Model' : 'Tap to select',
                  style: TextStyle(fontSize: 10, color: colorScheme.secondary),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(Icons.unfold_more, size: 18, color: colorScheme.secondary),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(Icons.smart_toy, size: 40, color: colorScheme.primary),
          ).animate().fadeIn(duration: 400.ms).scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 28),
          Text(
            'What can I help you with?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 26,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 10),
          Text(
            'All conversations stay on your device.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.secondary,
                  fontSize: 16,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 48),
          ...presets.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _PresetCard(
                    preset: e.value,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onPresetTap(e.value);
                    },
                    colorScheme: colorScheme,
                  )
                      .animate()
                      .fadeIn(delay: (300 + e.key * 50).ms, duration: 350.ms)
                      .slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                ),
              ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PresetCard extends StatefulWidget {
  final String preset;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _PresetCard({
    required this.preset,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  State<_PresetCard> createState() => _PresetCardState();
}

class _PresetCardState extends State<_PresetCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: widget.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 22, color: widget.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child:
                    Text(widget.preset, style: const TextStyle(fontSize: 16)),
              ),
              Icon(Icons.north_west,
                  size: 20, color: widget.colorScheme.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesList extends StatelessWidget {
  final List<ChatMessage> messages;
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _Bubble(msg: msg, colorScheme: colorScheme)
            .animate()
            .fadeIn(duration: 250.ms)
            .slideY(
                begin: 0.05,
                end: 0,
                duration: 250.ms,
                curve: Curves.easeOutCubic);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final ColorScheme colorScheme;

  const _Bubble({required this.msg, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.fromUser;
    const bubbleRadius = Radius.circular(28);
    const smallRadius = Radius.circular(10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: bubbleRadius,
                      topRight: bubbleRadius,
                      bottomLeft: isUser ? bubbleRadius : smallRadius,
                      bottomRight: isUser ? smallRadius : bubbleRadius,
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.5,
                      color: isUser
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                  child: Text(
                    '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.secondary.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _WaveDots(color: colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            'Generating',
            style: TextStyle(
                fontSize: 14,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton(
            onPressed: onStop,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text('Stop',
                style: TextStyle(fontSize: 14, color: colorScheme.error)),
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
        vsync: this, duration: const Duration(milliseconds: 1200))
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

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final ValueChanged<bool> onHasTextChanged;
  final VoidCallback onSend;
  final ColorScheme colorScheme;
  final bool canAttach;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onHasTextChanged,
    required this.onSend,
    required this.colorScheme,
    required this.canAttach,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (canAttach)
            SizedBox(
              width: 52,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: IconButton(
                  icon: Icon(Icons.add, color: colorScheme.secondary, size: 24),
                  onPressed: () => _showAttachmentSheet(context),
                ),
              ),
            ),
          if (canAttach) const SizedBox(width: 10),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 52,
                maxHeight: 180,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 17),
                onChanged: (v) => onHasTextChanged(v.trim().isNotEmpty),
                decoration: InputDecoration(
                  hintText: 'Message Flux…',
                  hintStyle: TextStyle(
                      color: colorScheme.secondary.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(
              hasText: hasText, colorScheme: colorScheme, onSend: onSend),
        ],
      ),
    );
  }

  void _showAttachmentSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.photo_outlined,
                      color: colorScheme.primary, size: 26),
                ),
                title: const Text('Photo', style: TextStyle(fontSize: 17)),
                subtitle: Text('Attach from gallery',
                    style:
                        TextStyle(fontSize: 14, color: colorScheme.secondary)),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.description_outlined,
                      color: colorScheme.primary, size: 26),
                ),
                title: const Text('Document', style: TextStyle(fontSize: 17)),
                subtitle: Text('Attach a PDF or text file',
                    style:
                        TextStyle(fontSize: 14, color: colorScheme.secondary)),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.camera_alt_outlined,
                      color: colorScheme.primary, size: 26),
                ),
                title: const Text('Camera', style: TextStyle(fontSize: 17)),
                subtitle: Text('Take a photo',
                    style:
                        TextStyle(fontSize: 14, color: colorScheme.secondary)),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabledColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);

    return SizedBox(
      width: 52,
      height: 52,
      child: GestureDetector(
        onTap: hasText
            ? () {
                HapticFeedback.lightImpact();
                onSend();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: hasText ? colorScheme.primary : disabledColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            Icons.arrow_upward,
            color: hasText
                ? colorScheme.onPrimary
                : colorScheme.secondary.withValues(alpha: 0.6),
            size: 24,
          ),
        ),
      ),
    );
  }
}
