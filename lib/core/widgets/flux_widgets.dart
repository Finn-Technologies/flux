import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/flux_theme.dart';
import 'flux_animations.dart';

/// A clean back button with the app's standard springy press feedback.
class FluxBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const FluxBackButton({
    super.key,
    required this.onTap,
    this.label = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return BouncyTap(
      onTap: onTap,
      scaleDown: 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/back_arrow.svg',
              width: 10,
              height: 18,
              colorFilter:
                  ColorFilter.mode(flux.textSecondary, BlendMode.srcIn),
            ),
            const SizedBox(width: 13),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: flux.textSecondary,
                height: 1.22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A standard title widget to ensure consistent spacing and typography.
class FluxTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const FluxTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: textTheme.displaySmall,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// A wrapper to add staggered entrance animations to lists.
class StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delayStep;
  final Duration duration;
  final double slideOffset;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.delayStep = const Duration(milliseconds: 40),
    this.duration = FluxDurations.normal,
    this.slideOffset = 16.0,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    Future.delayed(widget.delayStep * widget.index, () {
      if (mounted) _controller.forward();
    });
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
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.slideOffset * (1.0 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A modern empty state with subtle animation
class FluxEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const FluxEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return BouncyFadeSlide(
      duration: FluxDurations.slow,
      slideOffset: 32,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: flux.textPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 32,
                color: flux.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: textTheme.bodyLarge?.copyWith(
                color: flux.textSecondary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: textTheme.bodySmall?.copyWith(
                  color: flux.textSecondary.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated bouncing dots indicator shown during AI streaming.
class FluxThinkingIndicator extends StatefulWidget {
  const FluxThinkingIndicator({super.key});

  @override
  State<FluxThinkingIndicator> createState() => _FluxThinkingIndicatorState();
}

class _FluxThinkingIndicatorState extends State<FluxThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final phase = (_controller.value * 3 - index).clamp(0.0, 3.0);
              final t = (phase % 1.0);
              final bounce = 1.0 - (2.0 * t - 1.0) * (2.0 * t - 1.0);
              final opacity = 0.3 + 0.7 * bounce;
              final scale = 0.6 + 0.4 * bounce;
              final translateY = -6 * bounce;
              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, translateY),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: flux.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
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

/// Animated send button with smooth state transitions.
class FluxSendButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isEnabled;

  const FluxSendButton({
    super.key,
    required this.onTap,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return BouncyTap(
      onTap: isEnabled ? onTap : null,
      scaleDown: 0.85,
      child: AnimatedContainer(
        duration: FluxDurations.fast,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled ? flux.textPrimary : flux.textTertiary,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.arrow_upward, color: flux.background, size: 20),
      ),
    );
  }
}
