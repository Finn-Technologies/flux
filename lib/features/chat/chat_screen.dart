import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/services/inference_service.dart';
import '../../core/providers/model_provider.dart';
import '../../core/providers/download_provider.dart';
import '../../core/models/chat_session.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ============================================================================
// COLORS - Exact from Figma fill_ZEXJUU, fill_2766IO, fill_2N4TRD, fill_DDJ51Q
// ============================================================================
class _Colors {
  static const Color background = Color(0xFFF9F9F9); // fill_ZEXJUU
  static const Color black = Color(0xFF000000); // fill_2766IO
  static const Color white = Color(0xFFFFFFFF); // fill_2N4TRD
  static const Color border = Color.fromRGBO(0, 0, 0, 0.1); // fill_DDJ51Q 10%
  static const Color textSecondary = Color.fromRGBO(0, 0, 0, 0.5); // 50% black
}

// ============================================================================
// TYPOGRAPHY - Exact from Figma style_DJWIIE, style_8UZ7J7
// ============================================================================
class _TextStyles {
  static TextStyle get title => GoogleFonts.instrumentSans(
        fontSize: 25,
        fontWeight: FontWeight.w400,
        color: _Colors.black,
        height: 1.22,
      );

  static TextStyle get message => GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _Colors.black,
        height: 1.22,
      );

  static TextStyle get hint => GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _Colors.textSecondary,
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
// MAIN CHAT SCREEN - Exact replication of Home - Chat frame (id: 8:290)
// Frame dimensions: 390 x 844
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

  void _startNewChat() {
    // Clear current messages
    ref.read(chatMessagesProvider.notifier).clear();
    // Reset conversation ID
    setState(() {
      _currentConversationId = null;
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    // Create new conversation on first message
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
      localPath: selectedModel.localPath!,
      systemPrompt: "You are Flux, a helpful and friendly AI assistant.",
    );

    // Token-by-token streaming for faster feel
    int tokenCount = 0;
    await for (final token in stream) {
      if (!mounted) break;
      accumulated += token;
      tokenCount++;
      
      // Update UI every 3 tokens or on punctuation for natural feel
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
        // Small yield to allow UI to render
        await Future.delayed(Duration.zero);
      }
    }

    if (mounted) {
      // Final update to ensure everything is displayed
      ref.read(chatMessagesProvider.notifier).updateLastMessage(
        ChatMessage(text: accumulated, fromUser: false, time: DateTime.now()),
      );
      setState(() => _isStreaming = false);
      
      // Save conversation to sidebar after streaming completes
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
    showModalBottomSheet(
      context: context,
      backgroundColor: _Colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final downloadedModels = ref.watch(downloadProvider).where((m) => m.downloaded).toList();
          final selectedModel = ref.watch(selectedModelProvider);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Model',
                    style: _TextStyles.title,
                  ),
                  const SizedBox(height: 20),
                  if (downloadedModels.isEmpty)
                    Text(
                      'No models downloaded. Go to Library to download.',
                      style: _TextStyles.hint,
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
                          color: _Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: selectedModel?.id == model.id ? _Colors.black : _Colors.border,
                            width: selectedModel?.id == model.id ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                                Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Show "Flux Lite" as the model name
                                  Text(
                                    'Flux Lite',
                                    style: GoogleFonts.instrumentSans(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                      color: _Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Show the underlying model (Gemma 3 1B) and size
                                  Text(
                                    'Powered by ${model.name.replaceAll('google/', '').replaceAll('-it', '').replaceAll('-', ' ')} • ${(model.sizeMB / 1024).toStringAsFixed(1)} GB',
                                    style: GoogleFonts.instrumentSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: _Colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedModel?.id == model.id)
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: _Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: _Colors.white,
                                  size: 16,
                                ),
                              )
                            else
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _Colors.border),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: _Colors.black,
                                  size: 16,
                                ),
                              ),
                          ],
                     ),
                    ),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================================
  // CHAT HISTORY / MENU VIEW - Home - Menu View from Figma
  // Simple slide in from left, dark overlay on right, clean animation
  // ============================================================================
  void _showChatHistory(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Consumer(
          builder: (context, ref, child) {
            final conversations = ref.watch(conversationsProvider);
            
            return Stack(
              children: [
                // Dark overlay - fades in
                FadeTransition(
                  opacity: animation,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      color: _Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                
                // Menu slides in from left
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: Container(
                    width: 340,
                    color: _Colors.white, // White background FFFFFF
                    child: SafeArea(
                      child: GestureDetector(
                        // Prevent taps on menu from closing it
                        onTap: () {},
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chats title only (no back button)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                              child: Text(
                                'Chats',
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w400,
                                  color: _Colors.black,
                                  height: 1.22,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            
                            // Chat list
                            Expanded(
                              child: conversations.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No chats yet',
                                        style: GoogleFonts.instrumentSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          color: _Colors.textSecondary,
                                          height: 1.22,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      itemCount: conversations.length,
                                      itemBuilder: (context, index) {
                                        final conv = conversations[index];
                                        // Check if this is the currently active conversation
                                        final isSelected = _currentConversationId == conv.id;
                                        return _buildChatHistoryItem(
                                          context, 
                                          conv, 
                                          () => Navigator.of(context).pop(),
                                          isSelected,
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChatHistoryItem(BuildContext context, ChatSession conv, VoidCallback onClose, bool isSelected) {
    return GestureDetector(
      onTap: () {
        // Set this as the active conversation
        setState(() {
          _currentConversationId = conv.id;
        });
        ref.read(chatMessagesProvider.notifier).setMessages(conv.messages);
        onClose();
      },
      onLongPress: () {
        // Show delete/rename options
        showModalBottomSheet(
          context: context,
          backgroundColor: _Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chat title preview
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      conv.title,
                      style: GoogleFonts.instrumentSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(height: 20),
                  // Rename option
                  ListTile(
                    leading: const Icon(Icons.edit, color: _Colors.black),
                    title: Text(
                      'Rename',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: _Colors.black,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRenameDialog(context, conv);
                    },
                  ),
                  // Delete option
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
                      // If deleting current chat, clear it
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
          color: isSelected ? const Color.fromRGBO(0, 0, 0, 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          conv.title,
          style: GoogleFonts.instrumentSans(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: _Colors.black,
            decoration: TextDecoration.none,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, ChatSession conv) {
    final textController = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _Colors.white,
        title: Text(
          'Rename Chat',
          style: GoogleFonts.instrumentSans(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: _Colors.black,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: GoogleFonts.instrumentSans(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: _Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Chat name',
            hintStyle: GoogleFonts.instrumentSans(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: _Colors.textSecondary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _Colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _Colors.black),
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
                color: _Colors.textSecondary,
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
                color: _Colors.black,
              ),
            ),
          ),
        ],
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    final messages = ref.watch(chatMessagesProvider);

    return Scaffold(
      backgroundColor: _Colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // ==========================================================================
            // Positioned elements exactly as per Figma Home - Chat frame (8:290)
            // ==========================================================================
            
            // menu-02 icon - Position moved higher: x: 20, y: 60, size: 28x28
            Positioned(
              left: 20,
              top: 60,
              width: 28,
              height: 28,
              child: GestureDetector(
                onTap: () => _showChatHistory(context),
                child: SvgPicture.asset(
                  'assets/images/menu-02.svg',
                  width: 28,
                  height: 28,
                ),
              ),
            ),

            // Flux Lite text - Position moved higher: x: 63, y: 58 - Tappable to select model
            // This is the model name (Flux Lite), powered by the actual LLM (Gemma 3 1B)
            Positioned(
              left: 63,
              top: 58,
              child: GestureDetector(
                onTap: () => _showModelSelector(context),
                child: Row(
                  children: [
                    // "Flux" - full opacity
                    Text(
                      'Flux',
                      style: _TextStyles.title.copyWith(
                        color: _Colors.black,
                      ),
                    ),
                    // "Lite" - 50% opacity
                    Text(
                      ' Lite',
                      style: _TextStyles.title.copyWith(
                        color: _Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // pencil-edit-02 icon - Only visible after first message is sent
            if (messages.isNotEmpty)
              Positioned(
                right: 20,
                top: 60,
                width: 28,
                height: 28,
                child: GestureDetector(
                  onTap: _startNewChat,
                  child: SvgPicture.asset(
                    'assets/images/pencil-edit-02.svg',
                    width: 28,
                    height: 28,
                  ),
                ),
              ),

            // Chat messages area - scrollable
            // Extends INTO the input field area to eliminate any gap
            Positioned(
              left: 20,
              right: 20,
              top: 100,
              bottom: 90, // 844 - 90 = 754 (extends 48px into input field area)
              child: messages.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _buildBubble(msg, isLast: index == messages.length - 1);
                      },
                    ),
            ),

            // ==========================================================================
            // Text Input Frame (8:309) - Position: x: 20, y: 706
            // Unified design: Clean text input with NO inner borders
            // Dynamic height: 52px when empty, up to 140px (4 lines) when typing
            // ==========================================================================
            Positioned(
              left: 20,
              right: 20,
              top: 706,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 52,
                  maxHeight: 140,
                ),
                padding: const EdgeInsets.only(left: 20, right: 6, top: 6, bottom: 6),
                decoration: BoxDecoration(
                  color: _Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _Colors.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Type/Attach text area - Completely transparent, no borders or backgrounds
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
                          style: _TextStyles.message,
                          decoration: InputDecoration(
                            hintText: 'Type here',
                            hintStyle: _TextStyles.hint,
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

                    // Send button - Solid black circle
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: _Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          color: _Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================================================
            // Dock Frame - Bottom navigation with 4 items: Chat, Models, Downloads, Settings
            // Position: Centered at bottom with labels
            // ==========================================================================
            Positioned(
              left: 20,
              right: 20,
              top: 786,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Chat - active
                    _DockItem(
                      icon: Icons.chat_bubble,
                      label: 'Chat',
                      isActive: true,
                      onTap: () {},
                    ),

                    // Models
                    _DockItem(
                      icon: Icons.grid_view,
                      label: 'Models',
                      isActive: false,
                      onTap: () => context.go('/models'),
                    ),

                    // Downloads
                    _DockItem(
                      icon: Icons.download,
                      label: 'Downloads',
                      isActive: false,
                      onTap: () => context.go('/downloads'),
                    ),

                    // Settings
                    _DockItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      isActive: false,
                      onTap: () => context.go('/settings'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dock item widget
  Widget _DockItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: isActive ? _Colors.black : _Colors.textSecondary,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.instrumentSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isActive ? _Colors.black : _Colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Bubble widget matching Figma bubble style (8:325)
  // Border radius: 45px 20px 10px 45px pattern
  Widget _buildBubble(ChatMessage msg, {bool isLast = false}) {
    final isUser = msg.fromUser;
    // No bottom padding for last message to eliminate gap
    final bottomPadding = isLast ? 0.0 : 8.0;

            // AI responses (fromUser: false) - Full width, no bubble, aligned with input margins
    if (!isUser) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Text(
          msg.text,
          style: GoogleFonts.instrumentSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: _Colors.black,
            height: 1.5,
          ),
        ),
      );
    }

    // User messages - Black bubble, right-aligned, aligned with input right margin
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: _Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: const Radius.circular(24),
                  bottomRight: const Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.instrumentSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
