import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:llamadart/llamadart.dart' hide ChatSession;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../core/services/tts_service.dart';
import '../creations/creations_screen.dart';
import '../../core/services/inference_service.dart';
import '../../core/services/memory_service.dart';
import '../../core/services/search_service.dart';
import '../../core/providers/model_provider.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/sidebar_provider.dart';
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
final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(
  (ref) => ChatMessagesNotifier(),
);
final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, List<ChatSession>>(
  (ref) => ConversationsNotifier(),
);

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
  List<String> _attachedImages = [];
  bool _isModelSelectorExpanded = false;
  bool _isModelLoading = false;
  // Inline add-menu panel above the composer.
  bool _isAddMenuOpen = false;
  // Creation mode: chip above composer, voice hidden, send routes the
  // typed message through the HTML-creation system prompt.
  bool _isCreationMode = false;
  
  // Live voice mode state
  bool _isLiveMode = false;
  bool _isLiveMuted = false;
  bool _shouldSpeakResponse = false;
  final SpeechToText _stt = SpeechToText();
  final TtsService _tts = TtsService();
  String _liveTranscript = '';
  double _soundLevel = 0.0;


  bool _showTokenSpeed = false;

  /// Running summary of older conversation turns.
  String? _contextSummary;

  final _streamingTextNotifier = ValueNotifier<String>('');
  final StringBuffer _streamBuffer = StringBuffer();
  bool _shouldStop = false;
  Timer? _sttSilenceTimer;
  int _lastProcessedWordCount = 0;

  void _stopGeneration() {
    _shouldStop = true;
    if (mounted) setState(() => _isStreaming = false);
  }



  void _startNewChat() {
    setState(() => _isClearingChat = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      ref.read(chatMessagesProvider.notifier).clear();
      setState(() {
        _currentConversationId = null;
        _contextSummary = null;
        _isClearingChat = false;
      });
    });
  }

  /// Summarize older conversation turns to stay within the context window.
  /// Called proactively before each message when context is > 70% full.
  Future<void> _compactContextIfNeeded(
    List<ChatMessage> messages,
    HFModel model,
  ) async {
    final ctxSize = InferenceService().contextSize;
    if (ctxSize <= 0) return;

    // Only compact if we have enough messages and context is filling up
    if (messages.length < 4) return;

    // Estimate tokens: chars / 3.5 (rough UTF-8 token ratio)
    final totalChars = messages.fold<int>(0, (s, m) => s + m.text.length);
    final estimatedTokens = (totalChars / 3.5).round();
    final threshold = (ctxSize * 0.7).round();

    if (estimatedTokens < threshold) return;

    // Keep last 2 exchanges, summarize everything older
    final keepCount = 4; // last 2 user + 2 assistant messages
    final older = messages.length > keepCount
        ? messages.sublist(0, messages.length - keepCount)
        : <ChatMessage>[];

    if (older.isEmpty) return;

    final transcript = older
        .map((m) => '${m.fromUser ? "User" : "Assistant"}: ${m.text}')
        .join('\n');

    final summaryStream = InferenceService().streamChat(
      modelId: model.id,
      prompt: 'Summarize this conversation in 1-2 sentences. '
          'Keep key facts, names, decisions, and user preferences.\n\n$transcript',
      localPath: model.localPath,
      systemPrompt: 'Output only the summary. No preamble or greeting.',
      maxTokens: 128,
    );

    String summary = '';
    await for (final token in summaryStream) {
      if (!mounted) return;
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
    List<String>? imagePaths,
    List<ToolDefinition>? tools,
  }) async {
    final stream = InferenceService().streamChat(
      modelId: model.id,
      prompt: prompt,
      localPath: model.localPath,
      systemPrompt: systemPrompt,
      history: history,
      maxTokens: 4096,
      imagePaths: imagePaths,
      tools: tools,
    );

    String sentenceBuffer = "";
    bool hasStartedSpeaking = false;

    await for (final token in stream) {
      if (!mounted || _shouldStop) break;
      buffer.write(token);
      _streamingTextNotifier.value = buffer.toString();
      sentenceBuffer += token;

      if (_shouldSpeakResponse && !_isCreationMode) {
        final fullText = buffer.toString();
        final inCodeBlock = '```'.allMatches(fullText).length % 2 != 0;
        final inThinkBlock = '<think>'.allMatches(fullText).length != '</think>'.allMatches(fullText).length;

        if (!inCodeBlock && !inThinkBlock) {
          final match = RegExp(r'([.!?]+(?=\s))|\n+').firstMatch(sentenceBuffer);
          final commaMatch = sentenceBuffer.length > 50 ? RegExp(r',+(?=\s)').firstMatch(sentenceBuffer) : null;
          
          final breakMatch = match ?? commaMatch;
          
          if (breakMatch != null) {
            final breakIndex = breakMatch.end;
            final chunk = sentenceBuffer.substring(0, breakIndex);
            final cleanSentence = _cleanForSpeech(chunk);
            if (cleanSentence.isNotEmpty) {
              _tts.speak(cleanSentence);
              hasStartedSpeaking = true;
            }
            sentenceBuffer = sentenceBuffer.substring(breakIndex).trimLeft();
          }
        }
      }
    }

    if (_shouldSpeakResponse && !_isCreationMode && sentenceBuffer.trim().isNotEmpty) {
      final cleanSentence = _cleanForSpeech(sentenceBuffer);
      if (cleanSentence.isNotEmpty) {
        await _tts.speak(cleanSentence);
      }
    } else if (_shouldSpeakResponse && !_isCreationMode && !hasStartedSpeaking) {
      final response = buffer.toString().trim();
      if (response.isNotEmpty) {
        await _tts.speak(_cleanForSpeech(response));
      }
    }

    _shouldSpeakResponse = false;
    return buffer.toString();
  }

  String _cleanForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'```[\s\S]*?```'), '') // Remove code blocks
        .replaceAll(RegExp(r'<think>[\s\S]*?<\/think>'), '') // Remove think blocks
        .replaceAll(RegExp(r'`[^`]+`'), '') // Remove inline code
        .replaceAll(RegExp(r'[*_#~\[\](){}]+'), '') // Remove markdown syntax
        .replaceAll(RegExp(r'\n+'), ' ') // Replace newlines with spaces
        .trim();
  }

  String? _extractHtml(String text) {
    final htmlRegex = RegExp(r'```html\s*([\s\S]*?)\s*```', caseSensitive: false);
    var match = htmlRegex.firstMatch(text);
    if (match != null) return match.group(1)?.trim();

    final codeRegex = RegExp(r'```\s*([\s\S]*?)\s*```');
    match = codeRegex.firstMatch(text);
    if (match != null) {
      final content = match.group(1)?.trim() ?? '';
      if (content.toLowerCase().contains('<!doctype html>') ||
          content.toLowerCase().contains('<html') ||
          content.toLowerCase().contains('<body')) {
        return content;
      }
    }
    return null;
  }

  bool _looksTruncated(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed.endsWith(',') ||
        trimmed.endsWith(':') ||
        trimmed.endsWith(';')) {
      return true;
    }
    if (trimmed.endsWith('-') || trimmed.endsWith('\u2014')) {
      return true;
    }
    if (trimmed.contains('```') && trimmed.split('```').length.isEven) {
      return true;
    }
    return false;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final hasImages = _attachedImages.isNotEmpty;
    if ((text.isEmpty && !hasImages) || _isStreaming) return;

    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!).inMilliseconds < 500) {
      return;
    }
    _lastSendTime = now;

    final isFirstMessage = _currentConversationId == null;
    if (isFirstMessage) {
      _currentConversationId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    HapticFeedback.lightImpact();
    final attachedImages = List<String>.from(_attachedImages);
    ref.read(chatMessagesProvider.notifier).addMessage(
          ChatMessage(
            text: text,
            fromUser: true,
            time: DateTime.now(),
            imagePaths: attachedImages,
          ),
        );
    _controller.clear();
    _focusNode.unfocus();
    _attachedImages = [];
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

    // Show loading backdrop while model loads
    final needsLoad = !InferenceService().isLoaded ||
        InferenceService().modelPath != selectedModel.localPath;
    if (needsLoad && mounted) {
      setState(() => _isModelLoading = true);
    }

    setState(() => _isStreaming = true);
    _shouldStop = false;
    _streamBuffer.clear();
    _streamingTextNotifier.value = '';

    final currentMessages = ref.read(chatMessagesProvider);

    // Proactively compact context before it overflows
    await _compactContextIfNeeded(currentMessages, selectedModel);

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

    final prompt = text.isNotEmpty ? text : (hasImages ? 'Describe this image.' : '');
    final isCreation = _isCreationMode;
    final actualPrompt = prompt;

    final searchTools = _searchEnabled && !isCreation
        ? [SearchService.webSearchTool]
        : null;
    final memoryTools =
        !isCreation ? [MemoryService.saveMemoryTool] : null;

    final List<ToolDefinition> allTools = [
      ...(searchTools ?? []),
      ...(memoryTools ?? []),
    ];


    final systemPrompt = isCreation
        ? "You are Flux Creator. The user wants to build an interactive HTML mini-app. "
          "Always respond with a complete, self-contained HTML file inside a markdown code block (```html ... ```). "
          "Use inline CSS and JavaScript. Make it visually polished and interactive."
        : "You are Flux, a helpful and friendly on-device AI assistant. Keep responses concise and engaging. ${MemoryService().getMemoriesForPrompt()}";

    String accumulated = await _generateWithModel(
      prompt: actualPrompt,
      model: selectedModel,
      history: history,
      systemPrompt: systemPrompt,
      buffer: _streamBuffer,
      imagePaths: attachedImages,
      tools: allTools,
    );

    // Model is now loaded and responding — clear loading state
    if (_isModelLoading && mounted) {
      setState(() => _isModelLoading = false);
    }

    if (!_shouldStop && _looksTruncated(accumulated)) {
      _streamBuffer.clear();
      _streamingTextNotifier.value = accumulated;

      final contHistory = <Map<String, String>>[
        ...history,
        {'role': 'assistant', 'content': accumulated},
      ];

      final cont = await _generateWithModel(
        prompt: 'Continue from where you left off. Do not repeat anything.',
        model: selectedModel,
        history: contHistory,
        systemPrompt: systemPrompt,
        buffer: _streamBuffer,
        imagePaths: attachedImages.isNotEmpty ? attachedImages : null,
        tools: searchTools,
      );

      if (cont.trim().isNotEmpty) {
        accumulated += cont;
      }
    }

    if (mounted && !_shouldStop) {
      setState(() => _isStreaming = false);
      HapticFeedback.selectionClick();

      ref.read(chatMessagesProvider.notifier).addMessage(
            ChatMessage(
              text: accumulated,
              fromUser: false,
              time: DateTime.now(),
              outputTokPerSec: InferenceService().lastOutputTokPerSec,
              outputTokens: InferenceService().lastOutputTokens,
            ),
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
          projectId: null,
        );
        ref.read(conversationsProvider.notifier).updateConversation(conv);
      }

      if (isCreation) {
        final html = _extractHtml(accumulated);
        if (html != null && html.isNotEmpty) {
          final creationId = DateTime.now().millisecondsSinceEpoch.toString();
          final title = actualPrompt.length > 30 ? '${actualPrompt.substring(0, 30)}...' : actualPrompt;
          final newCreation = Creation(
            id: creationId,
            title: title,
            html: html,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await ref.read(creationsProvider.notifier).saveCreation(newCreation);
        }
      }
    }
  }

  void _scrollToBottom({bool smooth = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (smooth) {
          _scrollController.jumpTo(maxExtent);
        }
      }
    });
  }

  void _removeImage(int index) {
    setState(() => _attachedImages.removeAt(index));
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 768,
      maxHeight: 768,
    );
    if (images.isNotEmpty) {
      setState(() {
        _attachedImages = [
          ..._attachedImages,
          for (final img in images) img.path,
        ];
      });
    }
  }

  void _toggleAddMenu() {
    HapticFeedback.lightImpact();
    setState(() {
      _isAddMenuOpen = !_isAddMenuOpen;
      if (_isAddMenuOpen) {
        _focusNode.unfocus();
        _isModelSelectorExpanded = false;
      }
    });
  }

  void _enterCreationMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _isCreationMode = true;
      _isAddMenuOpen = false;
      _searchEnabled = false;
    });
    _focusNode.requestFocus();
  }

  void _exitCreationMode() {
    HapticFeedback.lightImpact();
    setState(() => _isCreationMode = false);
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
    _loadPreferences();
    _checkAssistantTrigger();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkBottomFade();
    });
  }

  Future<void> _checkAssistantTrigger() async {
    try {
      const channel = MethodChannel('com.finn.flux/storage');
      final bool wasAssistant = await channel.invokeMethod('checkAssistantTrigger');
      if (wasAssistant && mounted) {
        context.push('/voice');
      }
    } catch (_) {}
  }

  void _onChatScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final top = offset > 0 ? 1.0 : 0.0;
    final bottom = maxExtent > 0 && offset < maxExtent ? 1.0 : 0.0;

    if (top != _topFadeOpacity || bottom != _bottomFadeOpacity) {
      _topFadeOpacity = top;
      _bottomFadeOpacity = bottom;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _checkBottomFade() {
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      setState(() => _bottomFadeOpacity = 1.0);
    }
  }

  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => _showTokenSpeed = prefs.getBool('showTokenSpeed') ?? false,
      );
    }
    _initVoiceEngines();
  }

  Future<void> _initVoiceEngines() async {
    try {
      await _stt.initialize(
        onStatus: _onSttStatus,
        onError: (_) {},
      );
    } catch (e) {
      debugPrint('Voice engine error: $e');
    }
  }

  void _onSttStatus(String status) {
    if (!mounted) return;
    if (status == 'done' && _isLiveMode) {
      // If it stopped but we are still in live mode, restart it
      // This might beep, but it's a fallback for when the engine times out
      _enterLiveMode(skipStopTts: true);
    }
  }

  void _onSttResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    
    // IGNORE results if Flux is currently speaking or streaming a response
    if (_tts.isSpeaking || _isStreaming) {
      return;
    }

    final allWords = result.recognizedWords.trim();
    if (allWords.isEmpty) return;

    // Get only the words since we last "sent" a message
    // We use a simple substring approach or word split
    String newWords = '';
    if (_lastProcessedWordCount > 0 && _lastProcessedWordCount <= allWords.length) {
       newWords = allWords.substring(_lastProcessedWordCount).trim();
    } else if (_lastProcessedWordCount == 0 || allWords.length < _lastProcessedWordCount) {
       _lastProcessedWordCount = 0;
       newWords = allWords;
    }

    if (newWords.isEmpty) return;

    setState(() {
      _liveTranscript = newWords;
    });

    _sttSilenceTimer?.cancel();
    _sttSilenceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _isLiveMode) {
        // Save how much we've processed so far
        _lastProcessedWordCount = allWords.length;
        _finalizeLiveTranscript();
      }
    });

    if (result.finalResult) {
      _lastProcessedWordCount = allWords.length;
      _finalizeLiveTranscript();
    }
  }

  Future<void> _finalizeLiveTranscript() async {
    if (!_isLiveMode) return;
    _sttSilenceTimer?.cancel();
    
    final text = _liveTranscript.trim();
    if (text.isEmpty) return;
    
    _controller.text = text;
    setState(() {
      _hasText = true;
      _liveTranscript = '';
      _shouldSpeakResponse = true;
    });
    
    await _sendMessage();
  }

  Future<void> _toggleLiveMode() async {
    if (_isLiveMode) {
      await _exitLiveMode();
    } else {
      await _enterLiveMode(isInitial: true);
    }
  }

  Future<void> _enterLiveMode({bool skipStopTts = false, bool isInitial = false}) async {
    if (isInitial) {
      HapticFeedback.heavyImpact();
    }
    
    setState(() {
      _isLiveMode = true;
      _liveTranscript = '';
      _lastProcessedWordCount = 0;
      _isAddMenuOpen = false;
      _shouldSpeakResponse = true;
    });
    
    if (!skipStopTts) {
      await _tts.stop();
    }
    
    // Silence system beeps on Android
    if (Platform.isAndroid) {
      try {
        _tts.enableAutoMute = true;
        const channel = MethodChannel('com.finn.flux/storage');
        await channel.invokeMethod('muteSystemSounds');
        await channel.invokeMethod('muteMusicStream');
      } catch (_) {}
    }
    
    await _stt.listen(
      onResult: _onSttResult,
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _soundLevel = level);
      },
      listenFor: const Duration(hours: 1), // Practically infinite
      pauseFor: const Duration(seconds: 30), // Don't stop on short pauses
      localeId: null,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        onDevice: true,
      ),
    );
  }

  Future<void> _exitLiveMode() async {
    HapticFeedback.lightImpact();
    await _stt.stop();
    await _tts.stop();
    
    // Restore system sounds on Android
    if (Platform.isAndroid) {
      try {
        _tts.enableAutoMute = false;
        const channel = MethodChannel('com.finn.flux/storage');
        await channel.invokeMethod('unmuteSystemSounds');
        await channel.invokeMethod('unmuteMusicStream');
      } catch (_) {}
    }
    
    if (!mounted) return;
    setState(() {
      _isLiveMode = false;
      _liveTranscript = '';
      _shouldSpeakResponse = false;
    });
  }

  void _toggleLiveMute() {
    HapticFeedback.selectionClick();
    setState(() => _isLiveMuted = !_isLiveMuted);
    if (_isLiveMuted) {
      _stt.stop();
      _tts.stop();
    } else {
      _enterLiveMode();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onChatScroll);
    _scrollController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _streamingTextNotifier.dispose();
    _stt.stop();
    _tts.stop();
    
    // Ensure sounds are restored
    if (Platform.isAndroid) {
      _tts.enableAutoMute = false;
      const channel = MethodChannel('com.finn.flux/storage');
      channel.invokeMethod('unmuteSystemSounds').catchError((_) => null);
      channel.invokeMethod('unmuteMusicStream').catchError((_) => null);
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    final inputBottom = keyboardHeight > 0
        ? keyboardHeight + 16
        : MediaQuery.of(context).padding.bottom +
            (context.isDesktop ? 24.0 : 30.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: flux.background,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            if (_isModelSelectorExpanded || _isAddMenuOpen) {
              setState(() {
                _isModelSelectorExpanded = false;
                _isAddMenuOpen = false;
              });
            }
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Positioned.fill(
                child: FluxBackdrop(
                  state: _isModelLoading
                      ? BackdropState.loading
                      : BackdropState.idle,
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: topPadding + 90,
                bottom: inputBottom,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: Consumer(
                                      builder: (context, ref, _) {
                                        final messages = ref.watch(chatMessagesProvider);
                                        return AnimatedOpacity(
                                          opacity: _isClearingChat ? 0.0 : 1.0,
                                          duration: const Duration(milliseconds: 180),
                                          child: messages.isEmpty
                                              ? _buildEmptyState(context)
                                              : ListView.builder(
                                                  controller: _scrollController,
                                                  padding: const EdgeInsets.only(top: 8),
                                                  itemCount: messages.length +
                                                      (_isStreaming ? 1 : 0),
                                                  cacheExtent: 600,
                                                  addAutomaticKeepAlives: false,
                                                  addRepaintBoundaries: true,
                                                  physics: const BouncingScrollPhysics(),
                                                  itemBuilder: (context, index) {
                                                    if (index == messages.length) {
                                                      return _buildStreamingBubble(true);
                                                    }
                                                    final msg = messages[index];
                                                    final isLast =
                                                        index == messages.length - 1 &&
                                                            !_isStreaming;
                                                    return _buildBubble(
                                                      msg,
                                                      isLast: isLast,
                                                    );
                                                  },
                                                ),
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
                          if (_attachedImages.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SizedBox(
                                height: 80,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _attachedImages.length,
                                  itemBuilder: (context, index) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.file(
                                            File(_attachedImages[index]),
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: flux.surface,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: flux.border,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                size: 14,
                                                color: flux.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_isAddMenuOpen)
                            _AddMenuPanel(
                              onPickFile: () {
                                setState(() => _isAddMenuOpen = false);
                                _pickImages();
                              },
                              onMakeCreation: _enterCreationMode,
                              searchEnabled: _searchEnabled,
                              onToggleSearch: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _searchEnabled = !_searchEnabled;
                                  _isAddMenuOpen = false;
                                });
                              },
                              isCreationMode: _isCreationMode,
                            ),
                          if (_isCreationMode && !_isAddMenuOpen)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _CreationChip(onDismiss: _exitCreationMode),
                            ),
                          if (_isLiveMode && _liveTranscript.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 40,
                                  maxHeight: 100,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: flux.surface.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: flux.border, width: 1),
                                ),
                                child: Text(
                                  _liveTranscript,
                                  style: textTheme.bodyMedium,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final rawLevel = _soundLevel.clamp(-50.0, 50.0);
                              final normalizedLevel = math.max(0.0, (rawLevel + 40.0) / 50.0).clamp(0.0, 1.0);
                              
                              final liveMaxWidth = constraints.maxWidth - 88.0;
                              final targetWidth = _isLiveMuted 
                                  ? 34.0 
                                  : 34.0 + (normalizedLevel * (liveMaxWidth - 34.0));
                              
                              return TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 150),
                                tween: Tween<double>(begin: targetWidth, end: targetWidth),
                                builder: (context, smoothedTargetWidth, _) {
                                  return TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.fastOutSlowIn,
                                    tween: Tween<double>(
                                      begin: _isLiveMode ? 1.0 : 0.0,
                                      end: _isLiveMode ? 1.0 : 0.0,
                                    ),
                                    builder: (context, t, _) {
                                      final currentWidth = constraints.maxWidth * (1 - t) + smoothedTargetWidth * t;
                                      
                                      final circleLeft = (constraints.maxWidth - currentWidth) / 2;
                                      
                                      return SizedBox(
                                        width: constraints.maxWidth,
                                        child: Stack(
                                          alignment: Alignment.bottomCenter,
                                          clipBehavior: Clip.none,
                                          children: [
                                            SizedBox(
                                              width: currentWidth,
                                              height: _isLiveMode ? currentWidth : null,
                                              child: ClipRect(
                                                child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 400),
                                                curve: Curves.fastOutSlowIn,
                                                constraints: _isLiveMode
                                                    ? null
                                                    : const BoxConstraints(minHeight: 44, maxHeight: 140),
                                                decoration: _isLiveMode 
                                                  ? BoxDecoration(
                                                      borderRadius: BorderRadius.circular(100),
                                                      gradient: const LinearGradient(
                                                        begin: Alignment.topCenter,
                                                        end: Alignment.bottomCenter,
                                                        colors: [Colors.white, Color(0xFF86A8E7)],
                                                      ),
                                                    ) 
                                                  : BoxDecoration(
                                                      color: flux.surface.withValues(alpha: 0.92),
                                                      borderRadius: BorderRadius.circular(100),
                                                      border: Border.all(color: flux.border, width: 1),
                                                    ),
                                                clipBehavior: Clip.antiAlias,
                                                child: IgnorePointer(
                                                  ignoring: _isLiveMode,
                                                  child: AnimatedOpacity(
                                                  duration: const Duration(milliseconds: 200),
                                                  opacity: _isLiveMode ? 0.0 : 1.0,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 10, right: 6, top: 2, bottom: 2),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                             _ComposerAddButton(
                                                               isOpen: _isAddMenuOpen || _isCreationMode,
                                                               onTap: _isCreationMode ? _exitCreationMode : _toggleAddMenu,
                                                             ),
                                                             const SizedBox(width: 10),
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
                                                                     hintText: _isCreationMode ? 'Describe your creation…' : 'Ask anything',
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
                                                             if (_searchEnabled && !_isCreationMode)
                                                               _ComposerIconButton(
                                                                 tooltip: 'Web search on',
                                                                 icon: Icons.language_rounded,
                                                                 isActive: true,
                                                                 onTap: () {
                                                                   HapticFeedback.lightImpact();
                                                                   setState(() => _searchEnabled = false);
                                                                 },
                                                               ),
                                                             if (_searchEnabled && !_isCreationMode)
                                                               const SizedBox(width: 6),
                                                             if (!_isCreationMode)
                                                               _ComposerIconButton(
                                                                 tooltip: 'Flux Voice',
                                                                 svgAsset: 'assets/images/mic.svg',
                                                                 onTap: () {
                                                                   HapticFeedback.mediumImpact();
                                                                   _toggleLiveMode();
                                                                 },
                                                               ),
                                                             if (!_isCreationMode) const SizedBox(width: 6),
                                                             FluxSendButton(
                                                               onTap: _sendMessage,
                                                               onStop: _stopGeneration,
                                                               isEnabled: _hasText || _attachedImages.isNotEmpty,
                                                               isStreaming: _isStreaming,
                                                             ),
                                                             ],
                                                           ),
                                                         ),
                                                       ),
                                                     ),
                                                  ),
                                                   ),
                                                  ),
                                              Positioned(
                                                left: circleLeft - 44,
                                              top: 0,
                                              bottom: 0,
                                              child: IgnorePointer(
                                                ignoring: !_isLiveMode,
                                                child: AnimatedOpacity(
                                                  duration: const Duration(milliseconds: 250),
                                                  curve: Curves.easeOut,
                                                  opacity: _isLiveMode ? 1.0 : 0.0,
                                                  child: SizedBox(
                                                    width: 34,
                                                    child: Center(
                                                      child: _ComposerIconButton(
                                                        tooltip: _isLiveMuted ? 'Unmute' : 'Mute',
                                                        svgAsset: 'assets/images/mic.svg',
                                                        isActive: _isLiveMuted,
                                                        onTap: _toggleLiveMute,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: circleLeft - 40,
                                              top: 0,
                                              bottom: 0,
                                              child: IgnorePointer(
                                                ignoring: !_isLiveMode,
                                                child: AnimatedOpacity(
                                                  duration: const Duration(milliseconds: 250),
                                                  curve: Curves.easeOut,
                                                  opacity: _isLiveMode ? 1.0 : 0.0,
                                                  child: SizedBox(
                                                    width: 34,
                                                    child: Center(
                                                      child: _ComposerAddButton(
                                                        isOpen: true,
                                                        onTap: _exitLiveMode,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_isModelSelectorExpanded)
              Positioned(
                top: math.min(
                  topPadding + 92,
                  MediaQuery.of(context).size.height - 1,
                ),
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    color: flux.background.withValues(alpha: 0.4),
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
                  child: GestureDetector(
                    onTap: () {
                      if (context.isDesktop) {
                        ref.read(sidebarOpenProvider.notifier).toggle();
                      } else {
                        context.push('/history');
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: SvgPicture.asset(
                        'assets/images/menu-02.svg',
                        width: 22,
                        height: 22,
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
                final downloadedModels = ref
                    .watch(downloadProvider)
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
                            ? () => setState(
                                  () => _isModelSelectorExpanded =
                                      !_isModelSelectorExpanded,
                                )
                            : null,
                        scaleDown: 0.95,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Flux',
                              style: textTheme.displaySmall?.copyWith(
                                fontSize: 20,
                              ),
                            ),
                            if (suffix.isNotEmpty)
                              Text(
                                suffix,
                                style: textTheme.displaySmall?.copyWith(
                                  fontSize: 20,
                                  color: _isModelSelectorExpanded
                                      ? flux.textPrimary
                                      : flux.textSecondary,
                                ),
                              ),
                            if (hasMultiple) ...[
                              const SizedBox(width: 4),
                              Icon(
                                _isModelSelectorExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: flux.textSecondary,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_isModelSelectorExpanded && otherModels.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 6,
                            left:
                                (textTheme.displaySmall?.fontSize ?? 32) * 2.0,
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
                                  ref
                                      .read(selectedModelIdProvider.notifier)
                                      .select(model.id);
                                  setState(
                                    () => _isModelSelectorExpanded = false,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    modelSuffix,
                                    style: textTheme.displaySmall?.copyWith(
                                      fontSize: 20,
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
            if (ref.watch(chatMessagesProvider).isNotEmpty)
              Positioned(
                right: 20,
                top: topPadding + 48,
                child: Semantics(
                  label: AppLocalizations.of(context)!.newChat,
                  button: true,
                  child: Tooltip(
                    message: AppLocalizations.of(context)!.newChat,
                    child: _AnimatedPencilButton(onTap: _startNewChat),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}



  Widget _buildEmptyState(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    const suggestions = [
      'Explain quantum computing simply',
      'Write me a haiku about space',
      'Help me debug my code',
    ];

    if (_isModelLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulseText(
              text: 'Loading model',
              style: textTheme.bodyMedium?.copyWith(
                color: flux.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    return BouncyFadeSlide(
      duration: FluxDurations.slow,
      slideOffset: 24,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              greeting,
              style: textTheme.displaySmall?.copyWith(
                color: flux.textPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions.map((s) {
                return BouncyTap(
                  onTap: () {
                    _controller.text = s;
                    setState(() => _hasText = true);
                    _sendMessage();
                  },
                  scaleDown: 0.95,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: flux.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: flux.border,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      s,
                      style: textTheme.bodySmall?.copyWith(
                        color: flux.textPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, {bool isLast = false}) {
    final isUser = msg.fromUser;
    final bottomPadding = isLast ? 0.0 : 10.0;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final isError = !isUser && msg.text.startsWith('Error:');

    final hasThinking = !isUser &&
        (msg.text.contains('<think>') ||
            msg.text.contains('<|channel>thought') ||
            msg.text.contains('<|think|>'));
    final thinkingContent = hasThinking ? _extractThinking(msg.text) : '';

    Widget bubbleContent;
    if (!isUser) {
      var displayText = msg.text;
      if (hasThinking) {
        displayText = _stripThinkingTags(displayText);
      }

      final textContent = RichMessageRenderer(
        text: displayText.isEmpty ? msg.text : displayText,
        isUser: false,
      );

      bubbleContent = textContent;
    } else {
      final textContent = Text(
        msg.text,
        style: textTheme.bodyMedium?.copyWith(
          color: flux.textPrimary,
          height: 1.22,
        ),
      );

      bubbleContent = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (msg.imagePaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: msg.imagePaths.map((path) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(path),
                      width: 180,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  );
                }).toList(),
              ),
            ),
          textContent,
        ],
      );
    }

    final bubble = !isUser
        ? RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasThinking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildThinkingBadge(
                        flux: flux,
                        textTheme: textTheme,
                      ),
                    ),
                  if (hasThinking && thinkingContent.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildThinkingProcess(
                        content: thinkingContent,
                        flux: flux,
                        textTheme: textTheme,
                      ),
                    ),
                  bubbleContent,
                  if (!isUser)
                    _buildMessageFooter(
                      msg,
                      flux: flux,
                      textTheme: textTheme,
                      isError: isError,
                      showTokenSpeed: _showTokenSpeed,
                    ),
                  if (isError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: BouncyTap(
                        onTap: () {
                          final lastUserMsg = ref
                              .read(chatMessagesProvider)
                              .lastWhere((m) => m.fromUser, orElse: () => msg);
                          _controller.text = lastUserMsg.text;
                          ref.read(chatMessagesProvider.notifier).clear();
                          _sendMessage();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: flux.textPrimary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 14,
                                color: flux.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(context)!.retry,
                                style: textTheme.labelLarge?.copyWith(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: flux.surfaceSecondary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: flux.textPrimary.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: bubbleContent,
                    ),
                  ),
                ],
              ),
            ),
          );

    return BouncyFadeSlide(
      duration: FluxDurations.normal,
      slideOffset: 12,
      child: GestureDetector(onLongPress: null, child: bubble),
    );
  }

  void _regenerate(ChatMessage msg) {
    final messages = ref.read(chatMessagesProvider);
    final msgIndex = messages.indexOf(msg);
    if (msgIndex < 0) return;

    final earlierMessages = messages.sublist(0, msgIndex);
    final userMsg = earlierMessages.lastWhere(
      (m) => m.fromUser,
      orElse: () => messages.first,
    );

    ref.read(chatMessagesProvider.notifier).setMessages(earlierMessages);
    _controller.text = userMsg.text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: userMsg.text.length),
    );
    setState(() => _hasText = true);
    _sendMessage();
  }

  Widget _buildMessageFooter(
    ChatMessage msg, {
    required FluxColorsExtension flux,
    required TextTheme textTheme,
    required bool isError,
    bool showTokenSpeed = false,
  }) {
    final hasStats = showTokenSpeed &&
        !isError &&
        (msg.outputTokPerSec > 0 || msg.outputTokens > 0);
    final tg = msg.outputTokPerSec > 0
        ? '${msg.outputTokPerSec.toStringAsFixed(1)} t/s'
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          BouncyTap(
            onTap: () {
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.all(20),
                ),
              );
            },
            scaleDown: 0.9,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.content_copy,
                size: 18,
                color: flux.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          BouncyTap(
            onTap: () => _regenerate(msg),
            scaleDown: 0.9,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.refresh, size: 18, color: flux.textPrimary),
            ),
          ),
          if (hasStats) ...[
            const SizedBox(width: 10),
            Text(
              '${tg != null ? 'Output Speed: $tg' : ''}${msg.outputTokens > 0 ? '  \u2022  ${msg.outputTokens} tok' : ''}',
              style: textTheme.labelMedium?.copyWith(
                color: flux.textSecondary.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _extractThinking(String text) {
    final channelMatch = RegExp(
      r'<\|channel>([\s\S]*?)<channel\|>',
      dotAll: true,
    ).firstMatch(text);
    if (channelMatch != null) {
      var content = channelMatch.group(1)!.trim();
      if (content.startsWith('thought')) {
        content = content.substring('thought'.length).trim();
      }
      if (content.isNotEmpty) return content;
    }

    final thinkMatch = RegExp(
      r'<\|think\|>\s*\n?([\s\S]*?)(?:<\|turn>model|$)',
      dotAll: true,
    ).firstMatch(text);
    if (thinkMatch != null) {
      final content = thinkMatch.group(1)!.trim();
      if (content.isNotEmpty) return content;
    }

    final legacyMatch = RegExp(
      r'<think>([\s\S]*?)</think>',
      dotAll: true,
    ).firstMatch(text);
    if (legacyMatch != null) return legacyMatch.group(1)!.trim();

    return '';
  }

  String _stripThinkingTags(String text) {
    return text
        .replaceAll(RegExp(r'<\|channel>[\s\S]*?<channel\|>', dotAll: true), '')
        .replaceAll(
          RegExp(r'<\|think\|>\s*\n?[\s\S]*?(?:<\|turn>model|$)', dotAll: true),
          '',
        )
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', dotAll: true), '')
        .trim();
  }

  Widget _buildThinkingBadge({
    required FluxColorsExtension flux,
    required TextTheme textTheme,
  }) {
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
              fontWeight: FontWeight.w400,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingProcess({
    required String content,
    required FluxColorsExtension flux,
    required TextTheme textTheme,
  }) {
    return _ThinkingProcessBlock(
      content: content,
      flux: flux,
      textTheme: textTheme,
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
            final cleanText = _stripThinkingTags(streamingText);
            if (cleanText.isEmpty) {
              return const SizedBox.shrink();
            }
            return Text(
              cleanText,
              style: textTheme.bodyMedium?.copyWith(height: 1.45),
            );
          },
        ),
      ),
    );
  }
}

class _LiveWaveIndicator extends StatefulWidget {
  const _LiveWaveIndicator();

  @override
  State<_LiveWaveIndicator> createState() => _LiveWaveIndicatorState();
}

class _LiveWaveIndicatorState extends State<_LiveWaveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final t = (_controller.value + index * 0.2) % 1.0;
            final height = 8 + 16 * math.sin(t * math.pi);
            return Container(
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: flux.textPrimary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ComposerAddButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const _ComposerAddButton({required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Tooltip(
      message: isOpen ? 'Close' : 'Add',
      child: BouncyTap(
        onTap: onTap,
        scaleDown: 0.86,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isOpen
                ? flux.textPrimary.withValues(alpha: 0.08)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 180),
              curve: Curves.linear,
              turns: isOpen ? 0.125 : 0.0,
              child: SvgPicture.asset(
                'assets/images/plus.svg',
                width: 26,
                height: 26,
                colorFilter:
                    ColorFilter.mode(flux.textPrimary, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMenuPanel extends StatelessWidget {
  final VoidCallback onPickFile;
  final VoidCallback onMakeCreation;
  final VoidCallback onToggleSearch;
  final bool searchEnabled;
  final bool isCreationMode;

  const _AddMenuPanel({
    required this.onPickFile,
    required this.onMakeCreation,
    required this.onToggleSearch,
    required this.searchEnabled,
    required this.isCreationMode,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BouncyFadeSlide(
      duration: FluxDurations.fast,
      slideOffset: 14,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: flux.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: flux.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddMenuRow(
                icon: Icons.attach_file_rounded,
                label: 'Attach file or image',
                onTap: onPickFile,
              ),
              _AddMenuRow(
                icon: Icons.auto_awesome_rounded,
                label: isCreationMode
                    ? 'Creation mode is on'
                    : 'Make a creation',
                onTap: onMakeCreation,
                active: isCreationMode,
              ),
              if (!isCreationMode)
                _AddMenuRow(
                  icon: Icons.language_rounded,
                  label: searchEnabled
                      ? 'Web search · on'
                      : 'Web search',
                  onTap: onToggleSearch,
                  active: searchEnabled,
                  trailing: searchEnabled
                      ? Icon(Icons.check_rounded,
                          color: flux.textPrimary, size: 18)
                      : null,
                ),
              if (isCreationMode)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: Text(
                    'Web search and voice are paused while you build a creation.',
                    style: textTheme.bodySmall?.copyWith(
                      color: flux.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Widget? trailing;

  const _AddMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    return BouncyTap(
      onTap: onTap,
      scaleDown: 0.97,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? flux.textPrimary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: flux.textPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: flux.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Sticky tag that sits above the composer while creation mode is on.
/// The dismiss button reuses the "X" idiom (rotated plus glyph) so it
/// feels of-a-piece with the composer's add button.
class _CreationChip extends StatelessWidget {
  final VoidCallback onDismiss;
  const _CreationChip({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: flux.textPrimary,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 14, color: flux.background),
            const SizedBox(width: 6),
            Text(
              'Creation',
              style: textTheme.labelLarge?.copyWith(
                color: flux.background,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            BouncyTap(
              onTap: onDismiss,
              scaleDown: 0.85,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: flux.background.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  // Reuse the rotated-plus = X idiom.
                  child: Transform.rotate(
                    angle: 0.785398, // 45° in radians
                    child: SvgPicture.asset(
                      'assets/images/plus.svg',
                      width: 14,
                      height: 14,
                      colorFilter: ColorFilter.mode(
                        flux.background,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  final String tooltip;
  final IconData? icon;
  final String? svgAsset;
  final VoidCallback onTap;
  final bool isActive;

  const _ComposerIconButton({
    required this.tooltip,
    this.icon,
    this.svgAsset,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Tooltip(
      message: tooltip,
      child: BouncyTap(
        onTap: onTap,
        scaleDown: 0.86,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isActive
                ? flux.textPrimary.withValues(alpha: 0.08)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: svgAsset != null
                ? SvgPicture.asset(
                    svgAsset!,
                    width: 26,
                    height: 26,
                    colorFilter:
                        ColorFilter.mode(flux.textPrimary, BlendMode.srcIn),
                  )
                : Icon(
                    icon ?? Icons.circle,
                    size: 25,
                    color: flux.textPrimary,
                  ),
          ),
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
          'assets/images/compose.svg',
          width: 28,
          height: 28,
          colorFilter: ColorFilter.mode(flux.textPrimary, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _ThinkingProcessBlock extends StatefulWidget {
  final String content;
  final FluxColorsExtension flux;
  final TextTheme textTheme;

  const _ThinkingProcessBlock({
    required this.content,
    required this.flux,
    required this.textTheme,
  });

  @override
  State<_ThinkingProcessBlock> createState() => _ThinkingProcessBlockState();
}

class _ThinkingProcessBlockState extends State<_ThinkingProcessBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final preview = widget.content.length > 150
        ? '${widget.content.substring(0, 150)}...'
        : widget.content;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Opacity(
        opacity: _expanded ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.flux.textSecondary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.flux.border.withValues(
                alpha: _expanded ? 0.5 : 0.25,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 15,
                    color: widget.flux.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thinking process',
                    style: widget.textTheme.labelLarge?.copyWith(
                      color: widget.flux.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: widget.flux.textSecondary,
                  ),
                ],
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.content,
                    style: widget.textTheme.bodySmall?.copyWith(
                      color: widget.flux.textSecondary,
                      height: 1.55,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: widget.textTheme.bodySmall?.copyWith(
                      color: widget.flux.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle pulsing text for loading states (e.g. "Loading model").
class _PulseText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _PulseText({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style);
  }
}
