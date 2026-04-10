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
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _transcript = 'Set a timer for 5 minutes';
      _history.insert(
        0,
        _ActionItem(
          request: _transcript,
          response: 'Done. Timer set for 5 minutes.',
          icon: Icons.timer_outlined,
          time: DateTime.now(),
        ),
      );
    });
  }

  void _quickAction(String request, IconData icon) {
    setState(() {
      _transcript = request;
      _history.insert(
        0,
        _ActionItem(
          request: request,
          response: 'Done.',
          icon: icon,
          time: DateTime.now(),
        ),
      );
    });
  }

  void _clear() => setState(() {
        _transcript = '';
        _history.clear();
      });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.mic, size: 15, color: colorScheme.onPrimary),
            ),
            const SizedBox(width: 10),
            Text('Assistant',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          if (_history.isNotEmpty || _transcript.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh, color: colorScheme.onSurfaceVariant),
              onPressed: _clear,
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
                    onTap: _toggleListening,
                  )
                : _ConversationView(
                    transcript: _transcript,
                    history: _history,
                  ),
          ),
          _AssistantFooter(
            isListening: _isListening,
            pulseAnim: _pulseAnim,
            historyEmpty: _history.isEmpty && _transcript.isEmpty,
            onTapMic: _toggleListening,
            onQuickAction: _quickAction,
          ),
        ],
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  final bool isListening;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  const _IdleView({
    required this.isListening,
    required this.pulseAnim,
    required this.onTap,
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
            builder: (_, __) => Transform.scale(
              scale: isListening ? pulseAnim.value : 1.0,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 100,
                  height: 100,
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
                        blurRadius: isListening ? 30 : 20,
                        spreadRadius: isListening ? 4 : 0,
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
          const SizedBox(height: 20),
          Text(
            isListening ? 'Listening…' : 'Tap to speak',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          if (isListening) ...[
            const SizedBox(height: 8),
            Text(
              'Tap again to stop',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConversationView extends StatelessWidget {
  final String transcript;
  final List<_ActionItem> history;

  const _ConversationView({required this.transcript, required this.history});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (transcript.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.zero,
                    ),
                  ),
                  child: Text(transcript,
                      style: TextStyle(color: colorScheme.onPrimary)),
                ),
                const SizedBox(height: 4),
                Text('You',
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...history.map((item) => _ResultCard(item: item)),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final _ActionItem item;
  const _ResultCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = item.time;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon,
                    size: 17, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.request,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              Text(timeStr,
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle, size: 15, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(item.response,
                    style: TextStyle(
                        fontSize: 13, color: colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantFooter extends StatelessWidget {
  final bool isListening;
  final Animation<double> pulseAnim;
  final bool historyEmpty;
  final VoidCallback onTapMic;
  final void Function(String, IconData) onQuickAction;

  const _AssistantFooter({
    required this.isListening,
    required this.pulseAnim,
    required this.historyEmpty,
    required this.onTapMic,
    required this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 16),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: historyEmpty
          ? Column(
              children: [
                Text(
                  'Quick actions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        label: 'Set a timer',
                        icon: Icons.timer_outlined,
                        onTap: () => onQuickAction(
                            'Set a 5-minute timer', Icons.timer_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickActionCard(
                        label: 'Summarize',
                        icon: Icons.summarize_outlined,
                        onTap: () => onQuickAction(
                            'Summarize this page', Icons.summarize_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        label: 'Flashlight',
                        icon: Icons.flashlight_on_outlined,
                        onTap: () => onQuickAction(
                            'Turn on flashlight', Icons.flashlight_on_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickActionCard(
                        label: 'Quick note',
                        icon: Icons.note_add_outlined,
                        onTap: () => onQuickAction(
                            'Create a quick note', Icons.note_add_outlined),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: isListening ? pulseAnim.value : 1.0,
                child: GestureDetector(
                  onTap: onTapMic,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color:
                          isListening ? colorScheme.error : colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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
