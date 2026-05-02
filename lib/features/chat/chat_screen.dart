import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import '../../core/widgets/flux_widgets.dart';
import '../../core/widgets/flux_animations.dart';
import '../../core/constants/responsive.dart';
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
  double _topFadeOpacity = 0.0;
  double _bottomFadeOpacity = 0.0;
  bool _isStreaming = false;
  String? _currentConversationId;
  bool _hasText = false;
  bool _isClearingChat = false;
  DateTime? _lastSendTime;
  bool _searchEnabled = false;
  bool _isSearching = false;
  String? _lastSearchQuery;
  List<SearchResult> _lastSearchResults = [];
  bool _isModelSelectorExpanded = false;

  /// Running summary of older conversation turns.
  String? _contextSummary;

  final _streamingTextNotifier = ValueNotifier<String>('');
  final StringBuffer _streamBuffer = StringBuffer();
  Timer? _flushTimer;

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_streamBuffer.isNotEmpty) {
        _streamingTextNotifier.value = _streamBuffer.toString();
      }
    });
  }

  void _stopFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
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

  Future<void> _compactHistoryIfNeeded(
    List<ChatMessage> messages,
    HFModel model,
  ) async {
    final totalTurns = messages.length;
    if (totalTurns < 6 || totalTurns % 4 != 0) return;

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

  bool _looksTruncated(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (RegExp(r'[.!?\u3002\uFF01\uFF1F]$').hasMatch(trimmed)) return false;
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
    return true;
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

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
        "Never claim you do not remember something from this chat -- you do. "
        "${searchContext != null ? "You have been provided with live web search results above. Use them as your primary source of truth and cite them in your answer. " : ""}"
        "Answer concisely and accurately.";

    String accumulated = await _generateWithModel(
      prompt: prompt,
      model: selectedModel,
      history: history,
      systemPrompt: systemPrompt,
      buffer: _streamBuffer,
    );

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
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          );
        } else {
          _scrollController.jumpTo(maxExtent);
        }
      }
    });
  }

  void _showChatHistory(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)!.closeMenu,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final smoothCurve = Curves.easeInOutCubic;
        
        final overlayAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: smoothCurve,
        ));
        
        final menuAnimation = Tween<Offset>(
          begin: const Offset(-0.75, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: smoothCurve,
        ));
        
        final scaleAnimation = Tween<double>(
          begin: 0.97,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: smoothCurve,
        ));
        
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Stack(
              children: [
                Opacity(
                  opacity: overlayAnimation.value * 0.4,
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
              width: context.isDesktop ? 380 : 320,
              decoration: BoxDecoration(
                color: flux.surface,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: flux.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 48,
                    offset: const Offset(8, 0),
                  ),
                ],
              ),
              child: SafeArea(
                child: GestureDetector(
                  onTap: () {},
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
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
                                      color: flux.textSecondary.withValues(alpha: 0.3),
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
                                        color: flux.textSecondary.withValues(alpha: 0.5),
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _ChatHistoryList(
                                conversations: conversations,
                                currentConversationId: _currentConversationId,
                                flux: flux,
                                textTheme: textTheme,
                                onSelect: () => Navigator.of(context).pop(),
                                buildItem: (conv, isSelected, onClose) =>
                                    _buildChatHistoryItem(context, conv, onClose, isSelected),
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
    final itemKey = GlobalKey();
    
    return BouncyTap(
      scaleDown: 0.97,
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _currentConversationId = conv.id;
          _isModelSelectorExpanded = false;
        });
        if (conv.modelId != null) {
          ref.read(selectedModelIdProvider.notifier).select(conv.modelId);
        }
        ref.read(chatMessagesProvider.notifier).setMessages(conv.messages);
        onClose();
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        final renderBox = itemKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final offset = renderBox.localToGlobal(Offset.zero);
        final itemSize = renderBox.size;

        final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

        if (isIOS) {
          showCupertinoModalPopup<String>(
            context: context,
            builder: (ctx) => CupertinoActionSheet(
              title: Text(
                conv.title,
                style: textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(ctx, 'rename');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.pencil, color: flux.textPrimary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        AppLocalizations.of(context)!.rename,
                        style: textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () {
                    Navigator.pop(ctx, 'delete');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.delete, color: CupertinoColors.destructiveRed, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        AppLocalizations.of(context)!.delete,
                        style: textTheme.bodyLarge?.copyWith(color: CupertinoColors.destructiveRed),
                      ),
                    ],
                  ),
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ).then((value) {
            if (!mounted) return;
            if (value == 'rename') {
              _showRenameDialog(this.context, conv);
            } else if (value == 'delete') {
              _showDeleteConfirmation(this.context, conv);
            }
          });
        } else {
          final position = RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + itemSize.height + 10,
            offset.dx + itemSize.width,
            offset.dy + itemSize.height + 10,
          );
          showMenu<String>(
            context: context,
            position: position,
            color: flux.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            items: [
              PopupMenuItem<String>(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: flux.textPrimary, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.rename,
                      style: textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.delete,
                      style: textTheme.bodyLarge?.copyWith(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ).then((value) {
            if (!mounted) return;
            if (value == 'rename') {
              _showRenameDialog(this.context, conv);
            } else if (value == 'delete') {
              _showDeleteConfirmation(this.context, conv);
            }
          });
        }
      },
      child: AnimatedContainer(
        key: itemKey,
        duration: FluxDurations.fast,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? flux.textPrimary.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          conv.title,
          style: textTheme.bodyLarge?.copyWith(
            decoration: TextDecoration.none,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: flux.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: flux.textPrimary, width: 1.5),
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
              style: textTheme.bodyMedium?.copyWith(color: flux.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, ChatSession conv) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${AppLocalizations.of(context)!.delete} "${conv.title}"?',
          style: textTheme.headlineMedium,
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
              ref.read(conversationsProvider.notifier).deleteConversation(conv.id);
              if (_currentConversationId == conv.id) {
                _startNewChat();
              }
              Navigator.pop(ctx);
            },
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
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
    _scrollController.addListener(_onChatScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkBottomFade();
    });
  }

  void _onChatScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final top = offset > 0 ? 1.0 : 0.0;
    final bottom = maxExtent > 0 && offset < maxExtent ? 1.0 : 0.0;

    if (top != _topFadeOpacity || bottom != _bottomFadeOpacity) {
      setState(() {
        _topFadeOpacity = top;
        _bottomFadeOpacity = bottom;
      });
    }
  }

  void _checkBottomFade() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      setState(() => _bottomFadeOpacity = 1.0);
    }
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
    _scrollController.removeListener(_onChatScroll);
    _scrollController.dispose();
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

    final inputBottom = keyboardHeight > 0
        ? keyboardHeight + 16
        : (context.isDesktop ? 24.0 : MediaQuery.of(context).padding.bottom + 84.0);

    return Scaffold(
      backgroundColor: flux.background,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_isModelSelectorExpanded) {
            setState(() => _isModelSelectorExpanded = false);
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              left: 20,
              right: 20,
              top: topPadding + 90,
              bottom: inputBottom,
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: _isClearingChat ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: messages.isEmpty
                                ? _buildEmptyState(context)
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.only(top: 8),
                                    itemCount: messages.length + (_isStreaming ? 1 : 0) + (_isSearching ? 1 : 0),
                                    cacheExtent: 300,
                                    addAutomaticKeepAlives: false,
                                    addRepaintBoundaries: true,
                                    physics: const BouncingScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      if (_isSearching && index == messages.length) {
                                        return _buildSearchIndicator();
                                      }
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
                        if (_topFadeOpacity > 0)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 30,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      flux.background,
                                      flux.background,
                                      flux.background.withValues(alpha: 0),
                                    ],
                                    stops: const [0.0, 0.3, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_bottomFadeOpacity > 0)
                          Positioned(
                            bottom: -5,
                            left: 0,
                            right: 0,
                            height: 30,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      flux.background,
                                      flux.background,
                                      flux.background.withValues(alpha: 0),
                                    ],
                                    stops: const [0.0, 0.3, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 52,
                      maxHeight: 140,
                    ),
                    padding: const EdgeInsets.only(left: 16, right: 6, top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: flux.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: flux.border,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: flux.textPrimary.withValues(alpha: 0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                        FluxSendButton(
                          onTap: _sendMessage,
                          isEnabled: _hasText,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_isModelSelectorExpanded)
            Positioned(
              top: math.min(topPadding + 92, MediaQuery.of(context).size.height - 1),
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: flux.background.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 20,
              top: topPadding + 48,
              child: Semantics(
                label: AppLocalizations.of(context)!.chatHistory,
                button: true,
                child: Tooltip(
                  message: AppLocalizations.of(context)!.chatHistory,
                  child: BouncyTap(
                    onTap: () => _showChatHistory(context),
                    scaleDown: 0.85,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            ),

            Consumer(
              builder: (context, ref, child) {
                final selectedModel = ref.watch(selectedModelProvider);
                final downloadedModels = ref.watch(downloadProvider)
                    .where((m) => m.downloaded && !m.id.contains('creative'))
                    .toList();
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

                final hasMultiple = downloadedModels.length > 1;

                final otherModels = downloadedModels
                    .where((m) => m.id != selectedModel?.id)
                    .toList();

                return Positioned(
                  left: 72,
                  top: topPadding + 52,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BouncyTap(
                        onTap: hasMultiple
                            ? () {
                                HapticFeedback.lightImpact();
                                setState(() => _isModelSelectorExpanded = !_isModelSelectorExpanded);
                              }
                            : null,
                        scaleDown: 0.95,
                        child: Row(
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
                                  color: _isModelSelectorExpanded
                                      ? flux.textPrimary
                                      : flux.textSecondary,
                                ),
                              ),
                            if (hasMultiple) ...[
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: _isModelSelectorExpanded ? 0.5 : 0,
                                duration: FluxDurations.fast,
                                curve: FluxCurves.bouncy,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: flux.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_isModelSelectorExpanded && otherModels.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 10,
                            left: (textTheme.displaySmall?.fontSize ?? 32) * 2.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: otherModels.asMap().entries.map((entry) {
                              final model = entry.value;
                              String modelSuffix = '';
                              final mn = model.name.toLowerCase();
                              if (mn.contains('lite')) {
                                modelSuffix = ' Lite';
                              } else if (mn.contains('steady')) {
                                modelSuffix = ' Steady';
                              } else if (mn.contains('smart')) {
                                modelSuffix = ' Smart';
                              } else if (mn.contains('creative')) {
                                modelSuffix = ' Creative';
                              }
                              return BouncyTap(
                                scaleDown: 0.97,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(selectedModelIdProvider.notifier).select(model.id);
                                  setState(() => _isModelSelectorExpanded = false);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                    modelSuffix,
                                    style: textTheme.displaySmall?.copyWith(
                                      color: flux.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            if (messages.isNotEmpty)
              Positioned(
                right: 20,
                top: topPadding + 48,
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return FluxEmptyState(
      icon: Icons.auto_awesome_outlined,
      title: AppLocalizations.of(context)!.howCanIHelp,
      subtitle: AppLocalizations.of(context)!.startConversation,
    );
  }

  Widget _buildBubble(ChatMessage msg, {bool isLast = false}) {
    final isUser = msg.fromUser;
    final bottomPadding = isLast ? 0.0 : 10.0;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isError = !isUser && msg.text.startsWith('Error:');

    final hasThinking = !isUser && msg.text.contains('<think>');
    final thinkingContent = hasThinking
        ? msg.text.substring(
            msg.text.indexOf('<think>') + 7,
            msg.text.contains('</think>') ? msg.text.indexOf('</think>') : msg.text.length,
          ).trim()
        : '';

    Widget bubbleContent;
    if (!isUser) {
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
          height: 1.45,
        ),
      );
    }

    final showSources = !isUser && isLast && _lastSearchResults.isNotEmpty && _searchEnabled;

    final bubble = !isUser
        ? RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSources || hasThinking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                  if (hasThinking && thinkingContent.isNotEmpty)
                    _buildThinkingPreview(
                      content: thinkingContent,
                      flux: flux,
                      textTheme: textTheme,
                    ),
                  bubbleContent,
                  if (isError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: BouncyTap(
                        onTap: () {
                          final lastUserMsg = ref.read(chatMessagesProvider).lastWhere((m) => m.fromUser, orElse: () => msg);
                          _controller.text = lastUserMsg.text;
                          ref.read(chatMessagesProvider.notifier).clear();
                          _sendMessage();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: flux.textPrimary.withValues(alpha: 0.05),
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
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? flux.surfaceSecondary : flux.textPrimary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
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
      child: BouncyFadeSlide(
        duration: FluxDurations.normal,
        slideOffset: 12,
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
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
      padding: const EdgeInsets.only(top: 10, left: 4),
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
              return BouncyTap(
                onTap: () async {
                  final url = result.url;
                  if (url.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          url,
                          style: textTheme.bodySmall,
                        ),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.all(20),
                      ),
                    );
                  }
                },
                scaleDown: 0.95,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: flux.textPrimary.withValues(alpha: 0.05),
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
        color: flux.textPrimary.withValues(alpha: 0.05),
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
        color: flux.textPrimary.withValues(alpha: 0.05),
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
    final preview = content.length > 120 ? '${content.substring(0, 120)}...' : content;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: flux.textSecondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 6),
          Text(
            preview,
            style: textTheme.bodySmall?.copyWith(
              color: flux.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingBubble(bool isLast) {
    final textTheme = Theme.of(context).textTheme;
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0.0 : 10.0),
        child: ValueListenableBuilder<String>(
          valueListenable: _streamingTextNotifier,
          builder: (context, streamingText, _) {
            if (streamingText.isEmpty) {
              return const FluxThinkingIndicator();
            }
            return Text(
              streamingText,
              style: textTheme.bodyMedium?.copyWith(height: 1.45),
            );
          },
        ),
      ),
    );
  }
}

class _SearchToggleButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onTap;

  const _SearchToggleButton({required this.isEnabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return BouncyTap(
      onTap: onTap,
      scaleDown: 0.85,
      child: AnimatedContainer(
        duration: FluxDurations.fast,
        width: 34,
        height: 34,
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
          size: 16,
        ),
      ),
    );
  }
}

class _AnimatedPencilButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AnimatedPencilButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return BouncyTap(
      onTap: onTap,
      scaleDown: 0.85,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: SvgPicture.asset(
           'assets/images/pencil-edit-02.svg',
           width: 28,
           height: 28,
           colorFilter: ColorFilter.mode(
             flux.textPrimary,
             BlendMode.srcIn,
           ),
         ),
       ),
     );
   }
 }

class _ChatHistoryList extends StatefulWidget {
  final List<ChatSession> conversations;
  final String? currentConversationId;
  final FluxColorsExtension flux;
  final TextTheme textTheme;
  final VoidCallback onSelect;
  final Widget Function(ChatSession, bool, VoidCallback) buildItem;

  const _ChatHistoryList({
    required this.conversations,
    required this.currentConversationId,
    required this.flux,
    required this.textTheme,
    required this.onSelect,
    required this.buildItem,
  });

  @override
  State<_ChatHistoryList> createState() => _ChatHistoryListState();
}

class _ChatHistoryListState extends State<_ChatHistoryList> {
  final _scrollController = ScrollController();
  double _topFadeOpacity = 0.0;
  double _bottomFadeOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        setState(() => _bottomFadeOpacity = 1.0);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final top = offset > 0 ? 1.0 : 0.0;
    final bottom = maxExtent > 0 && offset < maxExtent ? 1.0 : 0.0;

    if (top != _topFadeOpacity || bottom != _bottomFadeOpacity) {
      setState(() {
        _topFadeOpacity = top;
        _bottomFadeOpacity = bottom;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.conversations.length,
            cacheExtent: 150,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final conv = widget.conversations[index];
              final isSelected = widget.currentConversationId == conv.id;
              return StaggeredEntrance(
                index: index,
                delayStep: const Duration(milliseconds: 20),
                child: widget.buildItem(conv, isSelected, widget.onSelect),
              );
            },
          ),
        ),
        if (_topFadeOpacity > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 30,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.flux.surface,
                      widget.flux.surface,
                      widget.flux.surface.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
              ),
            ),
          ),
        if (_bottomFadeOpacity > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 30,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      widget.flux.surface,
                      widget.flux.surface,
                      widget.flux.surface.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
