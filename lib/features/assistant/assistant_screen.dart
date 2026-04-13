import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/inference_service.dart';
import '../../core/providers/model_provider.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with TickerProviderStateMixin {
  bool _isListening = false;
  final List<_TranscriptBubble> _transcripts = [];
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    HapticFeedback.mediumImpact();

    if (_isListening) {
      setState(() => _isListening = false);
      _processCommand("Tell me a fun fact about the moon."); // Mock transcription
      return;
    }

    setState(() {
      _isListening = true;
    });
  }

  Future<void> _processCommand(String text) async {
    setState(() {
      _transcripts.add(_TranscriptBubble(text: text, isUser: true));
    });

    final selectedModel = ref.read(selectedModelProvider);
    final inference = InferenceService();
    
    String accumulated = "";
    int bubbleIndex = _transcripts.length;
    setState(() {
      _transcripts.add(_TranscriptBubble(text: "...", isUser: false));
    });

    if (selectedModel == null || selectedModel.localPath == null) {
      setState(() {
        _transcripts[bubbleIndex] = _TranscriptBubble(
          text: "No model selected or downloaded. Please visit the Library to get started.",
          isUser: false,
        );
      });
      return;
    }

    final stream = inference.streamChat(
      modelId: selectedModel.id,
      prompt: "The user said: $text. Provide a helpful, intelligent assistant response.",
      localPath: selectedModel.localPath,
    );

    await for (final token in stream) {
      if (!mounted) break;
      accumulated += token;
      setState(() {
        _transcripts[bubbleIndex] = _TranscriptBubble(
          text: accumulated,
          isUser: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.smart_toy,
                        color: colorScheme.onPrimary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Flux Assistant',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? colorScheme.error
                                    : colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isListening ? 'Listening...' : 'Ready',
                              style: TextStyle(
                                  fontSize: 13, color: colorScheme.secondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_transcripts.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.refresh, color: colorScheme.secondary),
                      onPressed: () => setState(() => _transcripts.clear()),
                    ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: _transcripts.isEmpty && !_isListening
                  ? _buildIdleState(colorScheme)
                  : _buildConversationState(colorScheme),
            ),

            // Bottom action area
            _buildBottomArea(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleState(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isListening ? 'Listening...' : 'Tap to start',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _isListening
              ? 'Speak now or tap to stop'
              : 'Ask anything or try a suggestion below',
          style: TextStyle(fontSize: 14, color: colorScheme.secondary),
        ),
        if (!_isListening) ...[
          const SizedBox(height: 48),
          _SuggestionChips(onTap: _toggleListening),
        ],
      ],
    );
  }

  Widget _buildConversationState(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        if (_isListening) ...[
          _ListeningIndicator(colorScheme: colorScheme),
          const SizedBox(height: 24),
        ],
        ..._transcripts.map((t) => _TranscriptBubbleWidget(
              bubble: t,
              colorScheme: colorScheme,
            )),
      ],
    );
  }

  Widget _buildBottomArea(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: GestureDetector(
        onTap: _toggleListening,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _isListening ? colorScheme.error : colorScheme.primary,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (_isListening ? colorScheme.error : colorScheme.primary)
                    .withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _isListening ? 'Stop' : 'Tap to speak',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListeningIndicator extends StatelessWidget {
  final ColorScheme colorScheme;

  const _ListeningIndicator({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: _SoundWave(colorScheme: colorScheme),
          ),
          const SizedBox(width: 16),
          Text(
            'Listening...',
            style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1500.ms,
          color: colorScheme.primary.withValues(alpha: 0.1),
        );
  }
}

class _SoundWave extends StatefulWidget {
  final ColorScheme colorScheme;

  const _SoundWave({required this.colorScheme});

  @override
  State<_SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<_SoundWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final offset = (i - 2).abs() / 4;
            final value = (((_controller.value + offset) % 1.0) * 2 - 1).abs();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: 12 + (value * 12),
              decoration: BoxDecoration(
                color: widget.colorScheme.primary
                    .withValues(alpha: 0.5 + value * 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  final VoidCallback onTap;

  const _SuggestionChips({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final suggestions = [
      'Help me plan a trip',
      'Explain this code',
      'Summarize this article',
      'Write a poem',
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: suggestions.asMap().entries.map((e) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              e.value,
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            ),
          ),
        ).animate().fadeIn(delay: (e.key * 100).ms).slideY(begin: 0.1, end: 0);
      }).toList(),
    );
  }
}

class _TranscriptBubble {
  final String text;
  final bool isUser;
  final DateTime time;

  _TranscriptBubble({required this.text, required this.isUser, DateTime? time})
      : time = time ?? DateTime.now();
}

class _TranscriptBubbleWidget extends StatelessWidget {
  final _TranscriptBubble bubble;
  final ColorScheme colorScheme;

  const _TranscriptBubbleWidget(
      {required this.bubble, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isUser = bubble.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(6),
                  bottomRight: isUser
                      ? const Radius.circular(6)
                      : const Radius.circular(20),
                ),
              ),
              child: Text(
                bubble.text,
                style: TextStyle(
                  fontSize: 16,
                  color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
