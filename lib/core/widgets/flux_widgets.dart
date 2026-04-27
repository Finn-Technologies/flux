import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/flux_theme.dart';

/// A clean back button with a subtle press animation.
class FluxBackButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;

  const FluxBackButton({
    super.key,
    required this.onTap,
    this.label = 'Back',
  });

  @override
  State<FluxBackButton> createState() => _FluxBackButtonState();
}

class _FluxBackButtonState extends State<FluxBackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
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
                    colorFilter: ColorFilter.mode(flux.textSecondary, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 13),
                  Text(
                    widget.label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: flux.textSecondary,
                      height: 1.22,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
          const SizedBox(height: 8),
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

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.delayStep = const Duration(milliseconds: 50),
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
      duration: const Duration(milliseconds: 350),
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
            offset: Offset(0, 20 * (1.0 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
