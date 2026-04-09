import 'package:flutter/material.dart';
import '../../core/widgets/flux_drawer.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _transcript = '';
  final List<_ActionItem> _history = [];
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    setState(() => _isListening = !_isListening);

    if (_isListening) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _transcript = 'Set a timer for 5 minutes';
        _history.insert(
          0,
          _ActionItem(
            request: 'Set a timer for 5 minutes',
            response: 'Done! Timer set for 5 minutes.',
            icon: Icons.timer_outlined,
            time: DateTime.now(),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.mic,
                  size: 16, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            const Text('Assistant'),
          ],
        ),
        actions: [
          if (_transcript.isNotEmpty || _history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Clear',
              onPressed: () => setState(() {
                _transcript = '';
                _history.clear();
              }),
            ),
        ],
      ),
      drawer: const FluxDrawer(currentItem: NavItem.assistant),
      body: Column(
        children: [
          Expanded(
            child: _history.isEmpty && _transcript.isEmpty
                ? _IdleView(
                    isListening: _isListening,
                    pulseAnim: _pulseAnim,
                    onMicTap: _toggleListening,
                  )
                : _HistoryView(
                    transcript: _transcript,
                    history: _history,
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              children: [
                if (_history.isEmpty && _transcript.isEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _SuggestionChip(
                        label: 'Set a timer',
                        icon: Icons.timer_outlined,
                        onTap: () => _quickAction(
                            'Set a 5-minute timer', Icons.timer_outlined),
                      ),
                      _SuggestionChip(
                        label: 'Summarize this page',
                        icon: Icons.summarize_outlined,
                        onTap: () => _quickAction(
                            'Summarize this page', Icons.summarize_outlined),
                      ),
                      _SuggestionChip(
                        label: 'Turn on flashlight',
                        icon: Icons.flashlight_on_outlined,
                        onTap: () => _quickAction(
                            'Turn on flashlight', Icons.flashlight_on_outlined),
                      ),
                      _SuggestionChip(
                        label: 'Quick note',
                        icon: Icons.note_add_outlined,
                        onTap: () => _quickAction(
                            'Create a quick note', Icons.note_add_outlined),
                      ),
                    ],
                  )
                else
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(
                      scale: _isListening ? _pulseAnim.value : 1.0,
                      child: GestureDetector(
                        onTap: _toggleListening,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _isListening
                                ? colorScheme.error
                                : colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening
                                        ? colorScheme.error
                                        : colorScheme.primary)
                                    .withValues(alpha: 0.35),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _quickAction(String request, IconData icon) {
    setState(() {
      _transcript = request;
      _history.insert(
        0,
        _ActionItem(
          request: request,
          response: 'Action completed.',
          icon: icon,
          time: DateTime.now(),
        ),
      );
    });
  }
}

class _IdleView extends StatelessWidget {
  final bool isListening;
  final Animation<double> pulseAnim;
  final VoidCallback onMicTap;

  const _IdleView({
    required this.isListening,
    required this.pulseAnim,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: isListening ? pulseAnim.value : 1.0,
              child: GestureDetector(
                onTap: onMicTap,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: isListening
                        ? colorScheme.error
                        : colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isListening
                                ? colorScheme.error
                                : colorScheme.primary)
                            .withValues(alpha: 0.25),
                        blurRadius: 28,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    isListening ? Icons.stop : Icons.mic,
                    size: 44,
                    color: isListening
                        ? Colors.white
                        : colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isListening ? 'Listening…' : 'Tap to speak',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your private assistant, works offline',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  final String transcript;
  final List<_ActionItem> history;

  const _HistoryView({required this.transcript, required this.history});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (transcript.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.zero,
                ),
              ),
              child: Text(
                transcript,
                style: TextStyle(color: colorScheme.onPrimaryContainer),
              ),
            ),
          ),
        ...history.map((item) => _ActionCard(item: item)),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final _ActionItem item;
  const _ActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon,
                      size: 16, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.request,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        _formatTime(item.time),
                        style: TextStyle(
                            fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(
              item.response,
              style:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SuggestionChip(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 16, color: colorScheme.primary),
      label: Text(label),
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}

class _ActionItem {
  final String request;
  final String response;
  final IconData icon;
  final DateTime time;
  _ActionItem({
    required this.request,
    required this.response,
    required this.icon,
    required this.time,
  });
}
