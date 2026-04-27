import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/services/inference_service.dart';
import '../../core/services/search_service.dart';
import '../../core/providers/model_provider.dart';
import '../../core/providers/download_provider.dart';
import '../../core/models/chat_session.dart';
import '../../core/models/hf_model.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/rich_message_renderer.dart';
import '../../core/widgets/animated_tap_card.dart';
import '../../core/widgets/flux_widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../l10n/app_localizations.dart';

// ============================================================================
// PROVIDERS
// ============================================================================
final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) => ChatMessagesNotifier());
final conversationsProvider = StateNotifierProvider<ConversationsNotifier, List<ChatSession>>((ref) => ConversationsNotifier());

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
    final chats = box.values.map((v) => ChatSession.fromJson(Map<String, dynamic>.from(v))).toList();
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = chats;
  }
  Future<void> updateConversation(ChatSession conv) async {
    state = [conv, ...state.where((c) => c.id != conv.id)];
    final box = Hive.box('chats');
    await box.put(conv.id, conv.toJson());
  }
  
  Future<void> deleteConversation(String id) async {
    state = state.where((c) => c.id != id).toList();
    final box = Hive.box('chats');
    await box.delete(id);
  }
}

// ============================================================================
// MAIN CHAT SCREEN
// ============================================================================
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
  String? _currentConversationId;
  bool _hasText = false;
  bool _isClearingChat = false;
  DateTime? _lastSendTime;
  bool _searchEnabled = false;
  bool _isSearching = false;
  String? _lastSearchQuery;
  List<SearchResult> _lastSearchResults = [];

  /// Running summary of older conversation turns.
  /// Updated every 4 messages so the model keeps context without a bloated prompt.
  String? _contextSummary;

  // Performance: local ValueNotifier for streaming text avoids rebuilding the entire message list on every token
  final _streamingTextNotifier = ValueNotifier<String>('');

  // Batched token buffering: accumulate tokens here and flush to the notifier
  // on a timer so the UI rebuilds at most ~6-7 times per second instead of
  // hundreds of times per second during fast generation.
  final StringBuffer _streamBuffer = StringBuffer();
  Timer? _flushTimer;

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (_streamBuffer.isNotEmpty) {
        _streamingTextNotifier.value = _streamBuffer.toString();
      }
    });
  }

  void _stopFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
    // Final flush of any remaining buffered text
    if (_streamBuffer.isNotEmpty) {
      _streamingTextNotifier.value = _streamBuffer.toString();
    }
  }

  void _startNewChat() {
    setState(() => _isClearingChat = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      ref.read(chatMessagesProvider.notifier).clear();
      setState(() {
        _currentConversationId = null;
        _contextSummary = null;
        _lastSearchQuery = null;
        _lastSearchResults = [];
        _isClearingChat = false;
      });
    });
  }

  /// Every 4 messages, summarize the older turns so the context window stays lean.
  /// The summary is stored in [_contextSummary] and injected as a prior assistant
  /// message in future history builds.
  Future<void> _compactHistoryIfNeeded(
    List<ChatMessage> messages,
    HFModel model,
  ) async {
    final totalTurns = messages.length;
    if (totalTurns < 6 || totalTurns % 4 != 0) return;

    // Everything except the most recent user-assistant pair gets summarized.
    final older = messages.sublist(0, messages.length - 2);
    final transcript = older
        .map((m) => '${m.fromUser ? "User" : "Assistant"}: ${m.text}')
        .join('\n');

    final summaryStream = InferenceService().streamChat(
      modelId: model.id,
      prompt:
          'Summarize the following conversation concisely in 1-3 sentences. '
          'Preserve key facts, names, decisions, and user preferences. '
          'Do not greet or explain yourself.\n\n$transcript',
      localPath: model.localPath,
      systemPrompt:
          'You are a compression engine. Output only the summary. No preamble.',
      maxTokens: 256,
    );

    String summary = '';
    await for (final token in summaryStream) {
      summary += token;
    }

    summary = summary.trim();
    if (summary.isNotEmpty && mounted) {
      setState(() => _contextSummary = summary);
    }
  }

  Future<String> _generateWithModel({
    required String prompt,
    required HFModel model,
    required List<Map<String, String>> history,
    required String systemPrompt,
    required StringBuffer buffer,
  }) async {
    final stream = InferenceService().streamChat(
      modelId: model.id,
      prompt: prompt,
      localPath: model.localPath,
      systemPrompt: systemPrompt,
      history: history,
      maxTokens: 8192,
    );

    await for (final token in stream) {
      if (!mounted) break;
      buffer.write(token);
    }
    return buffer.toString();
  }

  /// Heuristic: response looks cut-off if it doesn't end with a terminal
  /// punctuation, a closing tag, or a code-block fence.
  bool _looksTruncated(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    // Ends with proper terminal punctuation
    if (RegExp(r'[.!?\u3002\uFF01\uFF1F]$').hasMatch(trimmed)) return false;
    // Ends with a closing markdown/code tag or fence
    if (trimmed.endsWith('```')) return false;
    if (trimmed.endsWith('</think>')) return false;
    if (trimmed.endsWith('</html>')) return false;
    if (trimmed.endsWith('</body>')) return false;
    if (trimmed.endsWith('</div>')) return false;
    if (trimmed.endsWith(')')) return false;
    if (trimmed.endsWith(']')) return false;
    if (trimmed.endsWith('}')) return false;
    if (trimmed.endsWith('"')) return false;
    if (trimmed.endsWith('\'')) return false;
    // Ends mid-sentence or mid-word → likely truncated
    return true;
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    // Debounce: prevent double-sends within 500ms
    final now = DateTime.now();
    if (_lastSendTime != null && now.difference(_lastSendTime!).inMilliseconds < 500) {
      return;
    }
    _lastSendTime = now;

    final isFirstMessage = _currentConversationId == null;
    if (isFirstMessage) {
      _currentConversationId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    HapticFeedback.lightImpact();
    ref.read(chatMessagesProvider.notifier).addMessage(ChatMessage(text: text, fromUser: true, time: DateTime.now()));
    _controller.clear();
    _focusNode.unfocus();
    _scrollToBottom(smooth: false);

    final selectedModel = ref.read(selectedModelProvider);
    if (selectedModel == null || selectedModel.localPath == null) {
      ref.read(chatMessagesProvider.notifier).updateLastMessage(
        ChatMessage(
          text: AppLocalizations.of(context)!.noModelSelectedMessage,
          fromUser: false,
          time: DateTime.now(),
        ),
      );
      return;
    }

    setState(() => _isStreaming = true);
    _streamBuffer.clear();
    _streamingTextNotifier.value = '';
    _startFlushTimer();

    // Build conversation history with compaction support.
    final currentMessages = ref.read(chatMessagesProvider);
    final history = <Map<String, String>>[];

    if (_contextSummary != null && _contextSummary!.isNotEmpty) {
      history.add({'role': 'assistant', 'content': _contextSummary!});
    }

    final recentMessages = currentMessages.length > 4
        ? currentMessages.sublist(currentMessages.length - 4)
        : currentMessages;

    for (final msg in recentMessages) {
      if (msg.fromUser) {
        history.add({'role': 'user', 'content': msg.text});
      } else if (msg.text.isNotEmpty) {
        history.add({'role': 'assistant', 'content': msg.text});
      }
    }

    String prompt = text;
    String? searchContext;
    List<SearchResult> searchResults = [];

    // Web search: when enabled, fetch live results and prepend them as context.
    if (_searchEnabled) {
      setState(() {
        _isSearching = true;
        _lastSearchQuery = text;
      });

      searchResults = await SearchService().search(text);

      setState(() {
        _isSearching = false;
        _lastSearchResults = searchResults;
      });

      if (searchResults.isNotEmpty) {
        searchContext = SearchService().formatResultsForModel(searchResults);
        prompt =
            '$searchContext\n\n'
            'Using the authoritative web search results above, answer the following. '
            'Base your answer primarily on the search results provided. \n'
            'Question: $text';
      }
    }

    final systemPrompt =
        "You are Flux, a helpful and friendly AI assistant. "
        "IMPORTANT: You have perfect memory of this conversation. "
        "The full conversation history is provided to you with every message, "
        "so you can reference anything said earlier. "
        "Never claim you do not remember something from this chat — you do. "
        "${searchContext != null ? "You have been provided with live web search results above. Use them as your primary source of truth and cite them in your answer. " : ""}"
        "Answer concisely and accurately.";

    // First generation pass
    String accumulated = await _generateWithModel(
      prompt: prompt,
      model: selectedModel,
      history: history,
      systemPrompt: systemPrompt,
      buffer: _streamBuffer,
    );

    // Auto-continuation: if the response looks truncated, ask the model to
    // continue from where it left off. We do this silently without adding
    // extra user-visible messages.
    int continuationAttempts = 0;
    const maxContinuations = 3;
    while (mounted &&
        _looksTruncated(accumulated) &&
        continuationAttempts < maxContinuations) {
      continuationAttempts++;
      _streamBuffer.clear();
      _streamingTextNotifier.value = accumulated;

      final contHistory = <Map<String, String>>[
        ...history,
        {'role': 'assistant', 'content': accumulated},
      ];

      final cont = await _generateWithModel(
        prompt: 'Continue exactly from where you left off. Do not repeat anything already said.',
        model: selectedModel,
        history: contHistory,
        systemPrompt: systemPrompt,
        buffer: _streamBuffer,
      );

      if (cont.trim().isEmpty) break;
      accumulated += cont;
    }

    _stopFlushTimer();

    if (mounted) {
      _streamingTextNotifier.value = accumulated;
      setState(() => _isStreaming = false);
      HapticFeedback.selectionClick();

      ref.read(chatMessagesProvider.notifier).addMessage(
        ChatMessage(text: accumulated, fromUser: false, time: DateTime.now()),
      );

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

        // Compact older context every 4 messages in the background.
        if (messages.length >= 4 && messages.length % 4 == 0) {
          _compactHistoryIfNeeded(messages, selectedModel);
        }
      }
    }
  }

  void _scrollToBottom({bool smooth = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (smooth) {
          _scrollController.animateTo(
            maxExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(maxExtent);
        }
      }
    });
  }

  void _showModelSelector(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: flux.background,
      isScrollControlled: true,
      useRootNavigator: true,
      enableDrag: false,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final downloadedModels = ref.watch(downloadProvider).where((m) => m.downloaded).toList();
          final selectedModel = ref.watch(selectedModelProvider);

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 80),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.selectModel,
                  style: textTheme.displaySmall,
                ),
                const SizedBox(height: 20),
                if (downloadedModels.isEmpty)
                  Text(
                    AppLocalizations.of(context)!.noModelsDownloaded,
                    style: textTheme.bodyMedium?.copyWith(color: flux.textSecondary),
                  )
                else
                  ...downloadedModels.where((model) => !model.id.contains('creative')).map((model) => AnimatedTapCard(
                    scaleDown: 0.95,
                    onTap: () {
                      ref.read(selectedModelIdProvider.notifier).select(model.id);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                        color: flux.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: flux.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  model.name,
                                  style: textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Powered by ${model.baseModel ?? model.name} \u2022 ${model.sizeMB >= 1024 ? '${(model.sizeMB / 1024).toStringAsFixed(1)} GB' : '${model.sizeMB} MB'}',
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (selectedModel?.id == model.id)
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: flux.textPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: flux.background,
                                size: 16,
                              ),
                            )
                          else
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: flux.border),
                              ),
                              child: Icon(
                                Icons.touch_app_outlined,
                                color: flux.textPrimary,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showChatHistory(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)!.closeMenu,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = Curves.easeInOutCubic;
        
        final overlayAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));
        
        final menuAnimation = Tween<Offset>(
          begin: const Offset(-0.85, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));
        
        final scaleAnimation = Tween<double>(
          begin: 0.98,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));
        
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Stack(
              children: [
                Opacity(
                  opacity: overlayAnimation.value * 0.3,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      color: flux.textPrimary,
                    ),
                  ),
                ),
                
                Transform.translate(
                  offset: Offset(
                    menuAnimation.value.dx * MediaQuery.of(context).size.width,
                    0,
                  ),
                  child: Transform.scale(
                    scale: scaleAnimation.value,
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                ),
              ],
            );
          },
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Consumer(
          builder: (context, ref, child) {
            final conversations = ref.watch(conversationsProvider);
            
            return Container(
              width: 340,
              color: flux.surface,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () {},
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Padding(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                        child: Text(
                          AppLocalizations.of(context)!.chats,
                          style: textTheme.displaySmall?.copyWith(decoration: TextDecoration.none),
                        ),
                      ),
                      
                      Expanded(
                        child: conversations.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 40,
                                      color: flux.textSecondary.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      AppLocalizations.of(context)!.noChatsYet,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: flux.textSecondary,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppLocalizations.of(context)!.conversationsAppearHere,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: flux.textSecondary.withValues(alpha: 0.6),
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: conversations.length,
                                cacheExtent: 150,
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: true,
                                itemBuilder: (context, index) {
                                  final conv = conversations[index];
                                  final isSelected = _currentConversationId == conv.id;
                                  return StaggeredEntrance(
                                    index: index,
                                    child: _buildChatHistoryItem(
                                      context, 
                                      conv, 
                                      () => Navigator.of(context).pop(),
                                      isSelected,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatHistoryItem(BuildContext context, ChatSession conv, VoidCallback onClose, bool isSelected) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    
    return AnimatedTapCard(
      scaleDown: 0.95,
      onTap: () {
        setState(() {
          _currentConversationId = conv.id;
        });
        // Restore the model used for this conversation if available
        if (conv.modelId != null) {
          ref.read(selectedModelIdProvider.notifier).select(conv.modelId);
        }
        ref.read(chatMessagesProvider.notifier).setMessages(conv.messages);
        onClose();
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: flux.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      conv.title,
                      style: textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(height: 20),
                  ListTile(
                    leading: Icon(Icons.edit, color: flux.textPrimary),
                    title: Text(
                      AppLocalizations.of(context)!.rename,
                      style: textTheme.bodyLarge,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRenameDialog(context, conv);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(
                      AppLocalizations.of(context)!.delete,
                      style: textTheme.bodyLarge?.copyWith(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(conversationsProvider.notifier).deleteConversation(conv.id);
                      if (_currentConversationId == conv.id) {
                        _startNewChat();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? flux.textPrimary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          conv.title,
          style: textTheme.bodyLarge?.copyWith(decoration: TextDecoration.none),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, ChatSession conv) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final textController = TextEditingController(text: conv.title);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          AppLocalizations.of(context)!.renameChat,
          style: textTheme.headlineMedium,
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.chatName,
            hintStyle: textTheme.bodyLarge?.copyWith(color: flux.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: flux.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: flux.textPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: textTheme.bodyMedium?.copyWith(color: flux.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final newTitle = textController.text.trim();
              if (newTitle.isNotEmpty) {
                final updatedConv = ChatSession(
                  id: conv.id,
                  title: newTitle,
                  messages: conv.messages,
                  updatedAt: conv.updatedAt,
                  modelId: conv.modelId,
                );
                ref.read(conversationsProvider.notifier).updateConversation(updatedConv);
              }
              Navigator.pop(ctx);
            },
            child: Text(
              AppLocalizations.of(context)!.save,
              style: textTheme.bodyMedium?.copyWith(color: flux.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _streamingTextNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    final inputBottom = keyboardHeight > 0 ? keyboardHeight + 20 : 108.0;

    return Scaffold(
      backgroundColor: flux.background,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
          Positioned(
            left: 20,
            top: topPadding + 60,
            width: 28,
            height: 28,
            child: Semantics(
              label: AppLocalizations.of(context)!.chatHistory,
              button: true,
              child: Tooltip(
                message: AppLocalizations.of(context)!.chatHistory,
                child: AnimatedTapCard(
                  onTap: () => _showChatHistory(context),
                  scaleDown: 0.85,
                  child: SvgPicture.asset(
                    'assets/images/menu-02.svg',
                    width: 28,
                    height: 28,
                    colorFilter: ColorFilter.mode(
                      flux.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 63,
            top: topPadding + 58,
            child: AnimatedTapCard(
              onTap: () => _showModelSelector(context),
              scaleDown: 0.95,
              child: Consumer(
                builder: (context, ref, child) {
                  final selectedModel = ref.watch(selectedModelProvider);
                  final modelName = selectedModel?.name ?? '';
                  
                  String suffix = '';
                  if (modelName.toLowerCase().contains('lite')) {
                    suffix = ' Lite';
                  } else if (modelName.toLowerCase().contains('creative')) {
                    suffix = ' Creative';
                  } else if (modelName.toLowerCase().contains('steady')) {
                    suffix = ' Steady';
                  } else if (modelName.toLowerCase().contains('smart')) {
                    suffix = ' Smart';
                  }
                  
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Flux',
                        style: textTheme.displaySmall,
                      ),
                      if (suffix.isNotEmpty)
                        Text(
                          suffix,
                          style: textTheme.displaySmall?.copyWith(
                            color: flux.textPrimary.withValues(alpha: 0.5),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: flux.textPrimary.withValues(alpha: 0.3),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          if (messages.isNotEmpty)
            Positioned(
              right: 20,
              top: topPadding + 60,
              width: 28,
              height: 28,
            child: Semantics(
              label: AppLocalizations.of(context)!.newChat,
              button: true,
              child: Tooltip(
                message: AppLocalizations.of(context)!.newChat,
                  child: _AnimatedPencilButton(
                    onTap: _startNewChat,
                  ),
                ),
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            left: 20,
            right: 20,
            top: topPadding + 105,
            bottom: inputBottom,
            child: Column(
              children: [
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _isClearingChat ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: messages.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.zero,
                            itemCount: messages.length + (_isStreaming ? 1 : 0) + (_isSearching ? 1 : 0),
                            cacheExtent: 300,
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            itemBuilder: (context, index) {
                              // Show search indicator before streaming bubble
                              if (_isSearching && index == messages.length) {
                                return _buildSearchIndicator();
                              }
                              // Streaming bubble (either at end or before search indicator)
                              if (index == messages.length + (_isSearching ? 1 : 0)) {
                                return _buildStreamingBubble(true);
                              }
                              final msg = messages[index];
                              final isLast = index == messages.length - 1 && !_isStreaming;
                              return _buildBubble(msg, isLast: isLast);
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
              constraints: const BoxConstraints(
                minHeight: 52,
                maxHeight: 140,
              ),
              padding: const EdgeInsets.only(left: 20, right: 6, top: 6, bottom: 6),
              decoration: BoxDecoration(
                color: flux.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: flux.border,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: const InputDecorationTheme(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.messageFlux,
                          hintStyle: textTheme.bodyMedium?.copyWith(color: flux.textSecondary),
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                          counterText: '',
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),

                  _SearchToggleButton(
                    isEnabled: _searchEnabled,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _searchEnabled = !_searchEnabled);
                    },
                  ),
                  const SizedBox(width: 6),
                  _AnimatedSendButton(
                    onTap: _sendMessage,
                    isEnabled: _hasText,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 48,
            color: flux.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.howCanIHelp,
            style: textTheme.bodyLarge?.copyWith(
              color: flux.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.startConversation,
            style: textTheme.bodySmall?.copyWith(
              color: flux.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, {bool isLast = false}) {
    final isUser = msg.fromUser;
    final bottomPadding = isLast ? 0.0 : 12.0;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isError = !isUser && msg.text.startsWith('Error:');

    // Detect thinking blocks in the message
    final hasThinking = !isUser && msg.text.contains('<think>');
    final thinkingContent = hasThinking
        ? msg.text.substring(
            msg.text.indexOf('<think>') + 7,
            msg.text.contains('</think>') ? msg.text.indexOf('</think>') : msg.text.length,
          ).trim()
        : '';

    Widget bubbleContent;
    if (!isUser) {
      // Strip thinking tags from display text
      var displayText = msg.text;
      if (hasThinking) {
        displayText = displayText.replaceAll(
          RegExp(r'<think>.*?</think>', dotAll: true),
          '',
        ).trim();
      }
      bubbleContent = RichMessageRenderer(
        text: displayText.isEmpty ? msg.text : displayText,
        isUser: false,
      );
    } else {
      bubbleContent = Text(
        msg.text,
        style: textTheme.bodyMedium?.copyWith(
          color: isDark ? flux.textPrimary : flux.background,
          height: 1.4,
        ),
      );
    }

    // Only show sources on the last assistant message when search results exist
    final showSources = !isUser && isLast && _lastSearchResults.isNotEmpty && _searchEnabled;

    final bubble = !isUser
        ? RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata row: search badge + thinking indicator
                  if (showSources || hasThinking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (showSources)
                            _buildSearchBadge(flux: flux, textTheme: textTheme),
                          if (hasThinking)
                            _buildThinkingBadge(flux: flux, textTheme: textTheme),
                        ],
                      ),
                    ),
                  // Thinking content (collapsible-like compact display)
                  if (hasThinking && thinkingContent.isNotEmpty)
                    _buildThinkingPreview(
                      content: thinkingContent,
                      flux: flux,
                      textTheme: textTheme,
                    ),
                  // Main message content
                  bubbleContent,
                  if (isError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AnimatedTapCard(
                        onTap: () {
                          final lastUserMsg = ref.read(chatMessagesProvider).lastWhere((m) => m.fromUser, orElse: () => msg);
                          _controller.text = lastUserMsg.text;
                          ref.read(chatMessagesProvider.notifier).clear();
                          _sendMessage();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: flux.textPrimary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, size: 14, color: flux.textPrimary),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(context)!.retry,
                                style: textTheme.labelLarge?.copyWith(color: flux.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Sources at the bottom
                  if (showSources) _buildSources(flux, textTheme),
                ],
              ),
            ),
          )
        : RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? flux.surface : flux.textPrimary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: bubbleContent,
                    ),
                  ),
                ],
              ),
            ),
          );

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 15 * (1.0 - value)),
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onLongPress: msg.text.isNotEmpty
              ? () {
                  Clipboard.setData(ClipboardData(text: msg.text));
                  HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.copiedToClipboard,
                        style: textTheme.bodySmall,
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(20),
                    ),
                  );
                }
              : null,
          child: bubble,
        ),
      ),
    );
  }

  Widget _buildSearchIndicator() {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: flux.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            AppLocalizations.of(context)!.searchingFor(_lastSearchQuery ?? ''),
            style: textTheme.bodySmall?.copyWith(
              color: flux.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSources(FluxColorsExtension flux, TextTheme textTheme) {
    if (_lastSearchResults.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)!.sources,
            style: textTheme.labelLarge?.copyWith(
              color: flux.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _lastSearchResults.map((result) {
              return AnimatedTapCard(
                onTap: () async {
                  final url = result.url;
                  if (url.isNotEmpty) {
                    // Open URL in external browser
                    // For now just show a snackbar with the URL
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          url,
                          style: textTheme.bodySmall,
                        ),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(20),
                      ),
                    );
                  }
                },
                scaleDown: 0.95,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: flux.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: flux.border.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        size: 12,
                        color: flux.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          result.title,
                          style: textTheme.labelLarge?.copyWith(
                            color: flux.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBadge({required FluxColorsExtension flux, required TextTheme textTheme}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: flux.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language, size: 12, color: flux.textSecondary),
          const SizedBox(width: 5),
          Text(
            AppLocalizations.of(context)!.searched,
            style: textTheme.labelLarge?.copyWith(
              color: flux.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingBadge({required FluxColorsExtension flux, required TextTheme textTheme}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: flux.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology, size: 12, color: flux.textSecondary),
          const SizedBox(width: 5),
          Text(
            AppLocalizations.of(context)!.reasoned,
            style: textTheme.labelLarge?.copyWith(
              color: flux.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingPreview({required String content, required FluxColorsExtension flux, required TextTheme textTheme}) {
    // Truncate thinking content to first 120 chars
    final preview = content.length > 120 ? '${content.substring(0, 120)}...' : content;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: flux.textSecondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: flux.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology_outlined, size: 12, color: flux.textSecondary),
              const SizedBox(width: 5),
              Text(
                AppLocalizations.of(context)!.thinking,
                style: textTheme.labelLarge?.copyWith(
                  color: flux.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            preview,
            style: textTheme.bodySmall?.copyWith(
              color: flux.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingBubble(bool isLast) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0.0 : 12.0),
        child: ValueListenableBuilder<String>(
          valueListenable: _streamingTextNotifier,
          builder: (context, streamingText, _) {
            if (streamingText.isEmpty) {
              return _ThinkingIndicator(flux: flux);
            }
            // During streaming we render plain text only — markdown/think-block
            // parsing is expensive and causes crashes on long outputs.
            // The final bubble (once streaming ends) gets the full rich render.
            return Text(
              streamingText,
              style: textTheme.bodyMedium?.copyWith(height: 1.4),
            );
          },
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  final FluxColorsExtension flux;
  const _ThinkingIndicator({required this.flux});

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double offset = (_controller.value * 3 - index) % 3;
              final double opacity = (1.0 - (offset.abs() / 2)).clamp(0.2, 1.0);
              return Opacity(
                opacity: opacity,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.flux.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// Search toggle button
class _SearchToggleButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onTap;

  const _SearchToggleButton({required this.isEnabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return AnimatedTapCard(
      onTap: onTap,
      scaleDown: 0.85,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled ? flux.textPrimary : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isEnabled ? flux.textPrimary : flux.border,
            width: 1,
          ),
        ),
        child: Icon(
          Icons.language,
          color: isEnabled ? flux.background : flux.textSecondary,
          size: 18,
        ),
      ),
    );
  }
}

// Animated send button with press feedback
class _AnimatedSendButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isEnabled;

  const _AnimatedSendButton({required this.onTap, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return AnimatedTapCard(
      onTap: isEnabled ? onTap : null,
      scaleDown: 0.85,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.3,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: flux.textPrimary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_upward,
            color: flux.background,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// Animated pencil button with press feedback
class _AnimatedPencilButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AnimatedPencilButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return AnimatedTapCard(
      onTap: onTap,
      scaleDown: 0.75,
      child: SvgPicture.asset(
        'assets/images/pencil-edit-02.svg',
        width: 28,
        height: 28,
        colorFilter: ColorFilter.mode(
          flux.textPrimary,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

