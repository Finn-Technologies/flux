import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/memory_service.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../core/widgets/flux_animations.dart';

class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen> with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  List<Memory> _memories = MemoryService().getAllMemories();

  void _refreshMemories() {
    if (!mounted) return;
    setState(() => _memories = MemoryService().getAllMemories());
  }
  
  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: flux.background,
      body: Stack(
        children: [
          // Header
          Positioned(
            left: 20,
            top: topPadding + 48,
            child: FluxBackButton(onTap: () => context.pop()),
          ),
          Positioned(
            left: 20,
            top: topPadding + 100,
            child: const FluxTitle(title: "You"),
          ),

          // Orbit UI / empty state
          if (_memories.isEmpty)
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bubble_chart_rounded,
                          size: 48, color: flux.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        "Nothing remembered yet",
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Flux saves facts and preferences here as you chat, or add one yourself.",
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(color: flux.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: _OrbitUI(
                memories: _memories,
                controller: _orbitController,
                onChanged: _refreshMemories,
              ),
            ),

          // Bottom Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 40 + MediaQuery.of(context).padding.bottom,
            child: Center(
              child: BouncyTap(
                onTap: () => _showAddMemoryDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: flux.surface,
                    borderRadius: BorderRadius.circular(FluxRadii.card),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _StickerChip(
                        icon: Icons.add_rounded,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Add Memory",
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMemoryDialog(BuildContext context) {
    final controller = TextEditingController();
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: flux.surface,
        title: const Text("New Memory"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "What should Flux remember?",
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await MemoryService().saveMemory(controller.text);
                if (mounted) {
                  setState(() {
                    _memories.clear();
                    _memories.addAll(MemoryService().getAllMemories());
                  });
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

class _OrbitUI extends StatefulWidget {
  final List<Memory> memories;
  final AnimationController controller;
  final VoidCallback onChanged;

  const _OrbitUI({
    required this.memories,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_OrbitUI> createState() => _OrbitUIState();
}

class _OrbitUIState extends State<_OrbitUI> {
  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Background decoration — ignore pointer so header stays tappable.
            IgnorePointer(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Neural-style connection lines
                  CustomPaint(
                    size: Size.infinite,
                    painter: _NeuralConnectionPainter(
                      memories: widget.memories,
                      progress: widget.controller.value,
                      flux: flux,
                    ),
                  ),

                  // Orbit Rings (Subtle)
                  for (var i = 1; i <= 3; i++)
                    Container(
                      width: i * 220.0,
                      height: i * 220.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: flux.textPrimary.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Central "You" Node with Pulsing Aura
            _CentralNode(flux: flux),

            // Orbiting Memories
            for (var i = 0; i < widget.memories.length; i++)
              _OrbitingNode(
                memory: widget.memories[i],
                index: i,
                total: widget.memories.length,
                progress: widget.controller.value,
                flux: flux,
                onChanged: widget.onChanged,
              ),
          ],
        );
      },
    );
  }
}

class _CentralNode extends StatefulWidget {
  final FluxColorsExtension flux;
  const _CentralNode({required this.flux});

  @override
  State<_CentralNode> createState() => _CentralNodeState();
}

class _CentralNodeState extends State<_CentralNode> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        return Container(
          width: 100 + (pulse * 20),
          height: 100 + (pulse * 20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.flux.textPrimary.withValues(alpha: 0.05),
          ),
          child: Center(
              child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.flux.surface,
              ),
              child: Icon(Icons.person_rounded, color: widget.flux.textPrimary, size: 36),
            ),
          ),
        );
      },
    );
  }
}

class _NeuralConnectionPainter extends CustomPainter {
  final List<Memory> memories;
  final double progress;
  final FluxColorsExtension flux;

  _NeuralConnectionPainter({
    required this.memories,
    required this.progress,
    required this.flux,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = flux.textPrimary.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < memories.length; i++) {
      final orbitIndex = (i % 3) + 1;
      final radius = orbitIndex * 110.0;
      final speed = 1.0 / (orbitIndex * 1.5);
      final angle = (progress * speed * 2 * math.pi) + (i * (2 * math.pi / memories.length));
      
      final dx = center.dx + math.cos(angle) * radius;
      final dy = center.dy + math.sin(angle) * radius;
      
      canvas.drawLine(center, Offset(dx, dy), paint);
    }
  }

  @override
  bool shouldRepaint(_NeuralConnectionPainter old) => old.progress != progress;
}

class _OrbitingNode extends StatelessWidget {
  final Memory memory;
  final int index;
  final int total;
  final double progress;
  final FluxColorsExtension flux;
  final VoidCallback onChanged;

  const _OrbitingNode({
    required this.memory,
    required this.index,
    required this.total,
    required this.progress,
    required this.flux,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final orbitIndex = (index % 3) + 1;
    final radius = orbitIndex * 110.0;
    final speed = 1.0 / (orbitIndex * 1.5);
    
    final angle = (progress * speed * 2 * math.pi) + (index * (2 * math.pi / total));
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;

    // Subtle floating offset
    final floatX = math.sin(progress * 10 + index) * 5;
    final floatY = math.cos(progress * 12 + index) * 5;

    return Transform.translate(
      offset: Offset(dx + floatX, dy + floatY),
      child: BouncyTap(
        onTap: () => _showMemoryDetail(context, memory),
          child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: flux.surface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Center(
              child: Icon(
                _getCategoryIcon(memory.category),
                color: flux.textSecondary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'preference': return Icons.favorite_rounded;
      case 'fact': return Icons.lightbulb_rounded;
      case 'biography': return Icons.history_edu_rounded;
      default: return Icons.bubble_chart_rounded;
    }
  }

  void _showMemoryDetail(BuildContext context, Memory memory) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: flux.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(FluxRadii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StickerChip(
                  icon: _getCategoryIcon(memory.category),
                ),
                const SizedBox(width: 12),
                Text(
                  memory.category.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: flux.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                BouncyTap(
                  onTap: () async {
                    await MemoryService().deleteMemory(memory.id);
                    onChanged();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Icon(Icons.delete_outline_rounded, color: flux.accentWarm, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              memory.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StickerChip extends StatelessWidget {
  final IconData icon;

  const _StickerChip({required this.icon});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: flux.surface,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(icon, size: 20, color: flux.textPrimary),
      ),
    );
  }
}
