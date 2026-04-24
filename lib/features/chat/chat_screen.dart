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
import 'package:hive_flutter/hive_flutter.dart';

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
    _scrollToBottom();

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
    String accumulated = '';

    final stream = InferenceService().streamChat(
      modelId: selectedModel.id,
      prompt: text,
      localPath: selectedModel.localPath,
      systemPrompt: "You are Flux, a helpful and friendly AI assistant.",
    );

    int tokenCount = 0;
    await for (final token in stream) {
      if (!mounted) break;
      accumulated += token;
      tokenCount++;
      
      final shouldUpdate = tokenCount % 3 == 0 || 
                          token.contains('.') || 
                          token.contains('!') || 
                          token.contains('?') ||
                          token.contains('\n');
      
      if (shouldUpdate) {
        ref.read(chatMessagesProvider.notifier).updateLastMessage(
          ChatMessage(text: accumulated, fromUser: false, time: DateTime.now()),
        );
        _scrollToBottom();
        await Future.delayed(Duration.zero);
      }
    }

    if (mounted) {
      ref.read(chatMessagesProvider.notifier).updateLastMessage(
        ChatMessage(text: accumulated, fromUser: false, time: DateTime.now()),
      );
      setState(() => _isStreaming = false);
      
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
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
                  'Select Model',
                  style: _TextStyles.title(context),
                ),
                const SizedBox(height: 20),
                if (downloadedModels.isEmpty)
                  Text(
                    'No models downloaded. Go to Library to download.',
                    style: _TextStyles.hint(context),
                  )
                else
                  ...downloadedModels.map((model) => GestureDetector(
                    onTap: () {
                      ref.read(selectedModelIdProvider.notifier).state = model.id;
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(15),
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
                                Icons.add,
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
        final curve = Curves.easeOutCubic;
        
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
                                child: Text(
                                  'No chats yet',
                                  style: GoogleFonts.instrumentSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: flux.textSecondary,
                                    height: 1.22,
                                    decoration: TextDecoration.none,
                                  ),
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
    return GestureDetector(
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;

    const navBarTopFromBottom = 50.0 + 28.0;

    final inputBottom = keyboardHeight > 0
        ? keyboardHeight + 20
        : navBarTopFromBottom + 30;

    const inputMaxHeight = 140.0;
    const inputSpacing = 20.0;
    final messagesBottom = inputBottom + inputMaxHeight + inputSpacing;

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
            child: GestureDetector(
              onTap: () => _showChatHistory(context),
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

          Positioned(
            left: 63,
            top: topPadding + 58,
            child: GestureDetector(
              onTap: () => _showModelSelector(context),
              child: Consumer(
                builder: (context, ref, child) {
                  final selectedModel = ref.watch(selectedModelProvider);
                  final modelName = selectedModel?.name ?? '';
                  
                  String suffix = '';
                  if (modelName.toLowerCase().contains('lite')) {
                    suffix = ' Lite';
                  } else if (modelName.toLowerCase().contains('steady')) {
                    suffix = ' Steady';
                  } else if (modelName.toLowerCase().contains('smart')) {
                    suffix = ' Smart';
                  }
                  
                  return Row(
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
              child: _AnimatedPencilButton(
                onTap: _startNewChat,
              ),
            ),

          Positioned(
            left: 20,
            right: 20,
            top: topPadding + 105,
            bottom: messagesBottom,
            child: AnimatedOpacity(
              opacity: _isClearingChat ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: messages.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: messages.length,
                      cacheExtent: 200,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _buildBubble(msg, isLast: index == messages.length - 1);
                      },
                    ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            left: 20,
            right: 20,
            bottom: inputBottom,
            child: Container(
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
                          hintText: 'Type here',
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
                        onSubmitted: (_) {},
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

    final bubble = !isUser
        ? RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: RichMessageRenderer(
                text: msg.text,
                isUser: false,
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
                      child: Text(
                        msg.text,
                        style: GoogleFonts.instrumentSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: isDark ? flux.textPrimary : flux.background,
                          height: 1.4,
                        ),
                      ),
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
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 15 * (1.0 - value)),
              child: child,
            ),
          );
        },
        child: bubble,
      ),
    );
  }
}

// Animated send button with press feedback
class _AnimatedSendButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isEnabled;

  const _AnimatedSendButton({required this.onTap, required this.isEnabled});

  @override
  State<_AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<_AnimatedSendButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    if (widget.isEnabled) setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.isEnabled) {
      setState(() => _isPressed = false);
      widget.onTap();
    }
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: widget.isEnabled ? 1.0 : 0.3,
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
      ),
    );
  }
}

// Animated pencil button with press feedback
class _AnimatedPencilButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedPencilButton({required this.onTap});

  @override
  State<_AnimatedPencilButton> createState() => _AnimatedPencilButtonState();
}

class _AnimatedPencilButtonState extends State<_AnimatedPencilButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.75 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
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
