import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class FluxDurations {
  static const Duration micro = Duration(milliseconds: 50);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration pageTransition = Duration(milliseconds: 280);
  static const Duration staggerStep = Duration(milliseconds: 30);
  static const Duration tap = Duration(milliseconds: 140);
}

class FluxCurves {
  /// Default deceleration for most entrances and movement.
  static const Curve smooth = Curves.easeOutCubic;
  /// Symmetric ease for reversible state changes.
  static const Curve gentle = Curves.easeInOutCubic;
  /// Slight overshoot for playful, tactile moments.
  static const Curve emphasized = Curves.easeOutBack;
  /// Quick settle for exits.
  static const Curve linearOut = Curves.easeOut;
}

class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.85,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FluxDurations.tap,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          final scale = 1.0 + (widget.scaleDown - 1.0) * t;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

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
    this.delayStep = const Duration(milliseconds: 32),
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

    final delay = Duration(
        milliseconds: widget.delayStep.inMilliseconds * widget.index);
    Future.delayed(delay, () {
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
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.slideOffset * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class BouncyFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;
  final Axis slideDirection;

  const BouncyFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = FluxDurations.normal,
    this.slideOffset = 40.0,
    this.slideDirection = Axis.vertical,
  });

  @override
  State<BouncyFadeSlide> createState() => _BouncyFadeSlideState();
}

class _BouncyFadeSlideState extends State<BouncyFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    Future.delayed(widget.delay, () {
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
    final isVertical = widget.slideDirection == Axis.vertical;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: isVertical
                ? Offset(0, widget.slideOffset * (1 - t))
                : Offset(widget.slideOffset * (1 - t), 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class FluxPageTransition extends StatelessWidget {
  final Animation<double> primaryAnimation;
  final Animation<double>? secondaryAnimation;
  final bool isForwardLayout;
  final bool exitToRight;
  final Widget child;

  const FluxPageTransition({
    super.key,
    required this.primaryAnimation,
    this.secondaryAnimation,
    required this.isForwardLayout,
    this.exitToRight = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final inCurve = CurvedAnimation(
      parent: primaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final inSlide = Tween<Offset>(
      begin: Offset(isForwardLayout ? -0.08 : 0.08, 0),
      end: Offset.zero,
    ).animate(inCurve);

    final inFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: primaryAnimation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    final inScale = Tween<double>(begin: 0.985, end: 1.0).animate(inCurve);

    final isDismissing = secondaryAnimation == null || secondaryAnimation!.value == 0.0;
    final exitDriver = isDismissing ? const AlwaysStoppedAnimation(0.0) : secondaryAnimation!;
    final exitCurve = CurvedAnimation(
      parent: exitDriver,
      curve: Curves.easeInOutCubic,
    );

    // Use exitToRight to determine the direction when covered.
    final double exitEndX = exitToRight ? 0.05 : -0.05;

    final outSlide = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(exitEndX, 0),
    ).animate(exitCurve);

    final outFade = Tween<double>(begin: 1.0, end: 0.72).animate(exitCurve);
    final outScale = Tween<double>(begin: 1.0, end: 0.97).animate(exitCurve);

    return AnimatedBuilder(
      animation: Listenable.merge([primaryAnimation, secondaryAnimation]),
      builder: (context, _) {
        return SlideTransition(
          position: outSlide,
          child: ScaleTransition(
            scale: outScale,
            child: FadeTransition(
              opacity: outFade,
              child: SlideTransition(
                position: inSlide,
                child: ScaleTransition(
                  scale: inScale,
                  child: FadeTransition(
                    opacity: inFade,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FluxShimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;
  final bool enabled;

  const FluxShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1200),
    this.enabled = true,
  });

  @override
  State<FluxShimmer> createState() => _FluxShimmerState();
}

class _FluxShimmerState extends State<FluxShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void didUpdateWidget(covariant FluxShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final base = widget.baseColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = widget.highlightColor ?? base.withValues(alpha: 0.45);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1 + 2 * t - 0.6, -0.2),
              end: Alignment(-1 + 2 * t + 0.6, 0.2),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class FluxTypingIndicator extends StatefulWidget {
  final double dotSize;
  final double spacing;
  final Color? color;
  final Duration period;

  const FluxTypingIndicator({
    super.key,
    this.dotSize = 6,
    this.spacing = 5,
    this.color,
    this.period = const Duration(milliseconds: 1100),
  });

  @override
  State<FluxTypingIndicator> createState() => _FluxTypingIndicatorState();
}

class _FluxTypingIndicatorState extends State<FluxTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _phase(int i) {
    final raw = (_c.value + i * 0.18) % 1.0;
    return raw < 0.5 ? raw * 2.0 : 2.0 - raw * 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final a = _phase(i);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Transform.translate(
                offset: Offset(0, -2 * a),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35 + 0.65 * a),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class FluxPulseGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double minBlur;
  final double maxBlur;
  final double spread;
  final Duration period;
  final bool enabled;
  final BorderRadius? borderRadius;

  const FluxPulseGlow({
    super.key,
    required this.child,
    required this.color,
    this.minBlur = 6,
    this.maxBlur = 18,
    this.spread = 0,
    this.period = const Duration(milliseconds: 2200),
    this.enabled = true,
    this.borderRadius,
  });

  @override
  State<FluxPulseGlow> createState() => _FluxPulseGlowState();
}

class _FluxPulseGlowState extends State<FluxPulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)
        ..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant FluxPulseGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final blur =
            lerpDouble(widget.minBlur, widget.maxBlur, t)!;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.18 + 0.22 * t),
                blurRadius: blur,
                spreadRadius: widget.spread,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class FluxAuraBackground extends StatefulWidget {
  final Widget child;
  final Color primary;
  final Color secondary;
  final double intensity;
  final Duration period;

  const FluxAuraBackground({
    super.key,
    required this.child,
    required this.primary,
    required this.secondary,
    this.intensity = 0.10,
    this.period = const Duration(seconds: 60),
  });

  @override
  State<FluxAuraBackground> createState() => _FluxAuraBackgroundState();
}

class _FluxAuraBackgroundState extends State<FluxAuraBackground> {
  final ValueNotifier<double> _drift = ValueNotifier<double>(0);
  Timer? _timer;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 83), (_) {
      if (!mounted) return;
      final elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds;
      _drift.value = (elapsedMs / widget.period.inMilliseconds) % 1.0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: ValueListenableBuilder<double>(
              valueListenable: _drift,
              builder: (context, v, _) {
                final t = v * 2 * math.pi;
                final ax = 0.5 + 0.35 * math.sin(t);
                final ay = 0.35 + 0.30 * math.cos(t * 0.9);
                final bx = 0.5 + 0.40 * math.cos(t * 0.7 + 1.1);
                final by = 0.65 + 0.30 * math.sin(t * 1.1 + 0.4);
                return CustomPaint(
                  painter: _AuraPainter(
                    a: Alignment(ax * 2 - 1, ay * 2 - 1),
                    b: Alignment(bx * 2 - 1, by * 2 - 1),
                    colorA: widget.primary.withValues(alpha: widget.intensity),
                    colorB: widget.secondary
                        .withValues(alpha: widget.intensity * 0.9),
                  ),
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuraPainter extends CustomPainter {
  final Alignment a;
  final Alignment b;
  final Color colorA;
  final Color colorB;

  _AuraPainter({
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.shortestSide * 0.9;

    final paintA = Paint()
      ..shader = RadialGradient(
        colors: [colorA, colorA.withValues(alpha: 0)],
        stops: const [0.0, 1.0],
      ).createShader(
          Rect.fromCircle(center: a.alongSize(size), radius: radius));

    final paintB = Paint()
      ..shader = RadialGradient(
        colors: [colorB, colorB.withValues(alpha: 0)],
        stops: const [0.0, 1.0],
      ).createShader(
          Rect.fromCircle(center: b.alongSize(size), radius: radius));

    canvas.drawRect(rect, paintA);
    canvas.drawRect(rect, paintB);
  }

  @override
  bool shouldRepaint(covariant _AuraPainter old) =>
      old.a != a ||
      old.b != b ||
      old.colorA != colorA ||
      old.colorB != colorB;
}

class FluxBlurReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double maxBlur;

  const FluxBlurReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.maxBlur = 4,
  });

  @override
  State<FluxBlurReveal> createState() => _FluxBlurRevealState();
}

class _FluxBlurRevealState extends State<FluxBlurReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_c.value);
        return Opacity(
          opacity: t,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class FluxSuccessCheck extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const FluxSuccessCheck({
    super.key,
    this.size = 48,
    required this.color,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<FluxSuccessCheck> createState() => _FluxSuccessCheckState();
}

class _FluxSuccessCheckState extends State<FluxSuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: Size.square(widget.size),
        painter: _CheckPainter(t: _c.value, color: widget.color),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double t;
  final Color color;
  _CheckPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final circleProgress = (t.clamp(0, 0.55) / 0.55);
    final tickProgress = ((t - 0.45).clamp(0, 0.55)) / 0.55;

    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = size.shortestSide * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * circleProgress,
      false,
      stroke,
    );

    final p1 = Offset(center.dx - radius * 0.45, center.dy + radius * 0.02);
    final p2 = Offset(center.dx - radius * 0.10, center.dy + radius * 0.35);
    final p3 = Offset(center.dx + radius * 0.50, center.dy - radius * 0.30);

    final total = (p2 - p1).distance + (p3 - p2).distance;
    final drawLen = total * tickProgress;
    final seg1 = (p2 - p1).distance;
    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawLen <= seg1) {
      final f = drawLen / seg1;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * f, p1.dy + (p2.dy - p1.dy) * f);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final f = ((drawLen - seg1) / (p3 - p2).distance).clamp(0.0, 1.0);
      path.lineTo(
          p2.dx + (p3.dx - p2.dx) * f, p2.dy + (p3.dy - p2.dy) * f);
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.t != t || old.color != color;
}

class FluxMorphIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final Duration duration;

  const FluxMorphIcon({
    super.key,
    required this.icon,
    this.size = 22,
    this.color,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: Icon(icon, key: ValueKey(icon), size: size, color: color),
    );
  }
}

class FluxAnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const FluxAnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: Curves.linear,
      builder: (context, v, _) => Text(v.round().toString(), style: style),
    );
  }
}

class FluxHoverScale extends StatefulWidget {
  final Widget child;
  final double hoverScale;
  final Duration duration;
  final Curve curve;

  const FluxHoverScale({
    super.key,
    required this.child,
    this.hoverScale = 1.02,
    this.duration = FluxDurations.fast,
    this.curve = Curves.linear,
  });

  @override
  State<FluxHoverScale> createState() => _FluxHoverScaleState();
}

class _FluxHoverScaleState extends State<FluxHoverScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent event) {
    _controller.forward();
  }

  void _onExit(PointerEvent event) {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (widget.hoverScale - 1.0) * _controller.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
