import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/services/inference_service.dart';
import '../../core/providers/model_provider.dart';
import '../../core/providers/download_provider.dart';
import '../../core/models/chat_session.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/rich_message_renderer.dart';
import '../../core/widgets/animated_tap_card.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../l10n/app_localizations.dart';

// ============================================================================
// TYPOGRAPHY
// ============================================================================
class _TextStyles {
  static TextStyle title(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 25,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
        height: 1.22,
      );

  static TextStyle message(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
        height: 1.22,
      );

  static TextStyle hint(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textSecondary,
        height: 1.22,
      );
}

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

  // Performance: local ValueNotifier for streaming text avoids rebuilding the entire message list on every token
  final _streamingTextNotifier = ValueNotifier<String>('');

  void _startNewChat() {
    setState(() => _isClearingChat = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      ref.read(chatMessagesProvider.notifier).clear();
      setState(() {
        _currentConversationId = null;
        _isClearingChat = false;
      });
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

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
          text: "No model is currently selected or downloaded. Please visit the Library to download a model first.",
          fromUser: false,
          time: DateTime.now(),
        ),
      );
      return;
    }

    setState(() => _isStreaming = true);
    _streamingTextNotifier.value = '';

    // Build conversation history for memory (exclude the current user message and any thinking placeholder)
    final currentMessages = ref.read(chatMessagesProvider);
    final history = <Map<String, String>>[];
    for (final msg in currentMessages) {
      if (msg.fromUser) {
        history.add({'role': 'user', 'content': msg.text});
      } else if (msg.text.isNotEmpty) {
        history.add({'role': 'assistant', 'content': msg.text});
      }
    }

    String accumulated = '';
    bool receivedFirstToken = false;

    final stream = InferenceService().streamChat(
      modelId: selectedModel.id,
      prompt: text,
      localPath: selectedModel.localPath,
      systemPrompt: "You are Flux, a helpful and friendly AI assistant.",
      history: history,
      maxTokens: 4096,
    );

    int tokenCount = 0;
    await for (final token in stream) {
      if (!mounted) break;
      accumulated += token;
      tokenCount++;

      if (!receivedFirstToken) {
        receivedFirstToken = true;
        _streamingTextNotifier.value = accumulated;
      } else {
        final shouldUpdate = tokenCount % 3 == 0 ||
                            token.contains('.') ||
                            token.contains('!') ||
                            token.contains('?') ||
                            token.contains('\n');

        if (shouldUpdate) {
          _streamingTextNotifier.value = accumulated;
        }
      }
      _scrollToBottom();
      await Future.delayed(Duration.zero);
    }

    if (mounted) {
      _streamingTextNotifier.value = accumulated;
      setState(() => _isStreaming = false);
      HapticFeedback.selectionClick();

      // Single provider update at the end with final text
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
                  style: _TextStyles.title(context),
                ),
                const SizedBox(height: 20),
                if (downloadedModels.isEmpty)
                  Text(
                    AppLocalizations.of(context)!.noModelsDownloaded,
                    style: _TextStyles.hint(context),
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
                                  style: GoogleFonts.instrumentSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w400,
                                    color: flux.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Powered by ${model.baseModel ?? model.name} \u2022 ${model.sizeMB >= 1024 ? '${(model.sizeMB / 1024).toStringAsFixed(1)} GB' : '${model.sizeMB} MB'}',
                                  style: GoogleFonts.instrumentSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: flux.textSecondary,
                                  ),
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
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
                          'Chats',
                          style: GoogleFonts.instrumentSans(
                            fontSize: 25,
                            fontWeight: FontWeight.w400,
                            color: flux.textPrimary,
                            height: 1.22,
                            decoration: TextDecoration.none,
                          ),
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
                                      'No chats yet',
                                      style: GoogleFonts.instrumentSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                        color: flux.textSecondary,
                                        height: 1.22,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Your conversations will appear here',
                                      style: GoogleFonts.instrumentSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: flux.textSecondary.withValues(alpha: 0.6),
                                        height: 1.22,
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
                                  return _AnimatedChatHistoryItem(
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
    return AnimatedTapCard(
      scaleDown: 0.95,
      onTap: () {
        setState(() {
          _currentConversationId = conv.id;
        });
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
                      style: GoogleFonts.instrumentSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: flux.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(height: 20),
                  ListTile(
                    leading: Icon(Icons.edit, color: flux.textPrimary),
                    title: Text(
                      'Rename',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: flux.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRenameDialog(context, conv);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(
                      'Delete',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: Colors.red,
                      ),
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
          style: GoogleFonts.instrumentSans(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: flux.textPrimary,
            decoration: TextDecoration.none,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, ChatSession conv) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textController = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Rename Chat',
          style: GoogleFonts.instrumentSans(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: flux.textPrimary,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: GoogleFonts.instrumentSans(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: flux.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Chat name',
            hintStyle: GoogleFonts.instrumentSans(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: flux.textSecondary,
            ),
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
              'Cancel',
              style: GoogleFonts.instrumentSans(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: flux.textSecondary,
              ),
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
              'Save',
              style: GoogleFonts.instrumentSans(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: flux.textPrimary,
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

    final inputBottom = keyboardHeight > 0 ? keyboardHeight + 20 : 108.0;

    return Scaffold(
      backgroundColor: flux.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned(
            left: 20,
            top: topPadding + 60,
            width: 28,
            height: 28,
            child: Semantics(
              label: 'Chat history',
              button: true,
              child: Tooltip(
                message: 'Chat history',
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
                        style: _TextStyles.title(context).copyWith(
                          color: flux.textPrimary,
                        ),
                      ),
                      if (suffix.isNotEmpty)
                        Text(
                          suffix,
                          style: _TextStyles.title(context).copyWith(
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
                label: 'New chat',
                button: true,
                child: Tooltip(
                  message: 'New chat',
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
                            itemCount: messages.length + (_isStreaming ? 1 : 0),
                            cacheExtent: 200,
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
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
                        style: _TextStyles.message(context),
                        decoration: InputDecoration(
                          hintText: 'Message Flux...',
                          hintStyle: _TextStyles.hint(context),
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
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
            'How can I help you today?',
            style: _TextStyles.hint(context).copyWith(
              fontSize: 17,
              color: flux.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with Flux',
            style: _TextStyles.hint(context).copyWith(
              fontSize: 13,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isError = !isUser && msg.text.startsWith('Error:');

    Widget bubbleContent;
    if (!isUser) {
      bubbleContent = RichMessageRenderer(
        text: msg.text,
        isUser: false,
      );
    } else {
      bubbleContent = Text(
        msg.text,
        style: GoogleFonts.instrumentSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: isDark ? flux.textPrimary : flux.background,
          height: 1.4,
        ),
      );
    }

    final bubble = !isUser
        ? RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bubbleContent,
                  if (isError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AnimatedTapCard(
                        onTap: () {
                          // Retry: prepend the user's last message to the input and send
                          final lastUserMsg = ref.read(chatMessagesProvider).lastWhere((m) => m.fromUser, orElse: () => msg);
                          _controller.text = lastUserMsg.text;
                          // Remove the error message
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
                                'Retry',
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: flux.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                        'Copied to clipboard',
                        style: GoogleFonts.instrumentSans(fontSize: 14),
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

  Widget _buildStreamingBubble(bool isLast) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0.0 : 12.0),
        child: ValueListenableBuilder<String>(
          valueListenable: _streamingTextNotifier,
          builder: (context, streamingText, _) {
            if (streamingText.isEmpty) {
              return _ThinkingIndicator(flux: flux);
            }
            return _buildBubble(
              ChatMessage(text: streamingText, fromUser: false, time: DateTime.now()),
              isLast: isLast,
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
              final double opacity = (1.0 - (offset.abs() / 3)).clamp(0.3, 1.0);
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

// Staggered entrance animation for sidebar chat history items
class _AnimatedChatHistoryItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedChatHistoryItem({required this.index, required this.child});

  @override
  State<_AnimatedChatHistoryItem> createState() => _AnimatedChatHistoryItemState();
}

class _AnimatedChatHistoryItemState extends State<_AnimatedChatHistoryItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slide;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    final delay = widget.index * 40;

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _slide = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _startTimer = Timer(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, _slide.value),
              child: child,
            ),
          );
        },
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
