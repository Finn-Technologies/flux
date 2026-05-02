import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as dart_ui;
import 'flux_shell.dart';

// ============================================================================
// ANIMATION DURATIONS
// ============================================================================
class FluxDurations {
  static const Duration micro = Duration(milliseconds: 30);
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 500);
  static const Duration reverseTransition = Duration(milliseconds: 300);
  static const Duration staggerStep = Duration(milliseconds: 40);
  static const Duration bouncy = Duration(milliseconds: 600);
  static const Duration tapDown = Duration(milliseconds: 60);
  static const Duration tapUp = Duration(milliseconds: 200);
}

// ============================================================================
// CURVES
// ============================================================================
class FluxCurves {
  static const Curve easeOut = Cubic(0.16, 1, 0.3, 1); // easeOutExpo
  static const Curve easeInOut = Cubic(0.87, 0, 0.13, 1); // easeInOutExpo
  static const Curve bouncy = Cubic(0.68, -0.6, 0.32, 1.6);
  static const Curve superBouncy = Cubic(0.68, -0.8, 0.265, 1.8);
  static const Curve springy = Cubic(0.175, 0.885, 0.32, 1.275); // easeOutBack
  static const Curve playful = Cubic(0.87, -0.41, 0.19, 1.44);
  static const Curve snappy = Cubic(0.0, 1.0, 0.0, 1.0); // step like
  static const Curve gentleSpring = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve elasticIn = Curves.elasticIn;
  static const Curve bouncyElastic = Curves.elasticInOut;
  static const Curve smoothIn = Cubic(0.4, 0, 1, 1);
  static const Curve smoothOut = Cubic(0, 0, 0.2, 1);
  static const Curve decelerate = Curves.easeOutCirc;
  static const Curve emphasis = Curves.easeOutQuint;
  static const Curve popIn = Curves.easeOutBack;
}

// ============================================================================
// BOUNCY TAP - Snap feedback on tap
// ============================================================================
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
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FluxDurations.tapUp,
      reverseDuration: FluxDurations.tapDown,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: FluxCurves.springy,
        reverseCurve: FluxCurves.easeOut,
      ),
    );
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _controller.reverse().then((_) {
        widget.onTap!();
      });
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress != null
          ? () {
              _controller.reverse().then((_) {
                widget.onLongPress!();
              });
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// ANIMATED SCALE TAP (deprecated)
// ============================================================================
@Deprecated('Use BouncyTap instead')
class AnimatedScaleTap extends BouncyTap {
  const AnimatedScaleTap({
    super.key,
    required super.child,
    super.onTap,
    super.onLongPress,
    super.scaleDown = 0.94,
    Duration duration = FluxDurations.fast,
  });
}

// ============================================================================
// BOUNCY FADE SLIDE - Smooth entrance
// ============================================================================
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final easeT = FluxCurves.easeOut.transform(_controller.value);
        final t = FluxCurves.springy.transform(_controller.value);
        
        final offset = widget.slideDirection == Axis.vertical
            ? Offset(0, widget.slideOffset * (1.0 - t))
            : Offset(widget.slideOffset * (1.0 - t), 0);
            
        return Opacity(
          opacity: easeT.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: offset,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// FADE SLIDE TRANSITION (deprecated)
// ============================================================================
@Deprecated('Use BouncyFadeSlide')
class FadeSlideTransition extends BouncyFadeSlide {
  const FadeSlideTransition({
    super.key,
    required super.child,
    super.delay = Duration.zero,
    super.duration = FluxDurations.normal,
    super.slideOffset = 20.0,
  });
}

// ============================================================================
// POP IN - Bouncy scale entrance with overshoot
// ============================================================================
class PopIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double fromScale;

  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = FluxDurations.bouncy,
    this.fromScale = 0.5,
  });

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = FluxCurves.bouncy.transform(_controller.value);
        final opacityT = FluxCurves.easeOut.transform(_controller.value);
        final scale = widget.fromScale + (1.0 - widget.fromScale) * t;
        return Opacity(
          opacity: opacityT.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// SCALE IN TRANSITION (deprecated)
// ============================================================================
@Deprecated('Use PopIn')
class ScaleInTransition extends PopIn {
  const ScaleInTransition({
    super.key,
    required super.child,
    super.delay = Duration.zero,
    super.duration = FluxDurations.normal,
    super.fromScale = 0.92,
  });
}

// ============================================================================
// BOUNCY STAGGER LIST
// ============================================================================
class BouncyStaggerList extends StatelessWidget {
  final List<Widget> children;
  final Duration delayStep;
  final Duration duration;
  final double slideOffset;
  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  const BouncyStaggerList({
    super.key,
    required this.children,
    this.delayStep = FluxDurations.staggerStep,
    this.duration = FluxDurations.normal,
    this.slideOffset = 30.0,
    this.direction = Axis.vertical,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  @override
  Widget build(BuildContext context) {
    final wrapped = children.asMap().entries.map((entry) {
      return BouncyFadeSlide(
        delay: delayStep * entry.key,
        duration: duration,
        slideOffset: slideOffset,
        slideDirection: direction,
        child: entry.value,
      );
    }).toList();

    if (direction == Axis.vertical) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: wrapped,
      );
    }
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: wrapped,
    );
  }
}

// ============================================================================
// STAGGER LIST (deprecated)
// ============================================================================
@Deprecated('Use BouncyStaggerList')
class StaggerList extends BouncyStaggerList {
  const StaggerList({
    super.key,
    required super.children,
    super.delayStep = FluxDurations.staggerStep,
    super.duration = FluxDurations.normal,
    super.slideOffset = 16.0,
    super.direction = Axis.vertical,
    super.mainAxisAlignment = MainAxisAlignment.start,
    super.crossAxisAlignment = CrossAxisAlignment.start,
    super.mainAxisSize = MainAxisSize.max,
  });
}

// ============================================================================
// GLOW SHIMMER
// ============================================================================
class GlowShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool enabled;

  const GlowShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
    this.enabled = true,
  });

  @override
  State<GlowShimmer> createState() => _GlowShimmerState();
}

class _GlowShimmerState extends State<GlowShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GlowShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = FluxCurves.easeOut.transform(_controller.value);
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.5),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.5 + t * 3.0, -0.5),
              end: Alignment(-0.5 + t * 3.0, 0.5),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

// ============================================================================
// SHIMMER (deprecated)
// ============================================================================
@Deprecated('Use GlowShimmer')
class Shimmer extends GlowShimmer {
  const Shimmer({
    super.key,
    required super.child,
    super.duration = const Duration(milliseconds: 1500),
    super.enabled = true,
  });
}

// ============================================================================
// BOUNCY PULSE
// ============================================================================
class BouncyPulse extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double scale;

  const BouncyPulse({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.scale = 1.15,
  });

  @override
  State<BouncyPulse> createState() => _BouncyPulseState();
}

class _BouncyPulseState extends State<BouncyPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
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
        final t = FluxCurves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 1.0 + (widget.scale - 1.0) * t,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// PULSE ANIMATION (deprecated)
// ============================================================================
@Deprecated('Use BouncyPulse')
class PulseAnimation extends BouncyPulse {
  const PulseAnimation({
    super.key,
    required super.child,
    super.duration = const Duration(milliseconds: 2000),
    super.scale = 1.05,
  });
}

// ============================================================================
// BOUNCY PAGE TRANSITION
// ============================================================================
class BouncyPageTransition extends PageRouteBuilder {
  final Widget child;
  final double offset;

  BouncyPageTransition({
    required this.child,
    this.offset = 0.2,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionDuration: FluxDurations.pageTransition,
    reverseTransitionDuration: FluxDurations.reverseTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = FluxCurves.springy.transform(animation.value);
          final opacityT = FluxCurves.easeOut.transform(animation.value);
          final thisOffset = offset * (1.0 - t);
          final scale = 0.9 + (0.1 * t);
          
          return Transform.translate(
            offset: Offset(thisOffset * MediaQuery.of(context).size.width, 0),
            child: Opacity(
              opacity: opacityT.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            ),
          );
        },
        child: child,
      );
    },
  );
}

// ============================================================================
// FLUX PAGE TRANSITION (Universal Peer-to-Peer slide)
// ============================================================================
class FluxPageTransition extends StatelessWidget {
  final Animation<double> primaryAnimation;
  final Animation<double>? secondaryAnimation;
  final bool isForwardLayout;
  final Widget child;

  const FluxPageTransition({
    super.key,
    required this.primaryAnimation,
    this.secondaryAnimation,
    required this.isForwardLayout,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([primaryAnimation, secondaryAnimation]),
      builder: (context, child) {
        bool isForeground = true;
        double t = primaryAnimation.value;
        double s = 0.0;

        if (secondaryAnimation != null && secondaryAnimation!.status != AnimationStatus.dismissed) {
          // If we have an active secondaryAnimation, we are the BOTTOM route being pushed over.
          isForeground = false;
          s = secondaryAnimation!.value;
        } else if (secondaryAnimation == null && primaryAnimation.status == AnimationStatus.reverse) {
          // In AnimatedSwitcher, the outgoing child runs primaryAnimation in reverse.
          isForeground = false;
          s = 1.0 - primaryAnimation.value;
        }

        final curve = Curves.easeOutQuart;
        
        double offsetValue = 0.0;
        Widget finalChild = child!;

        if (isForeground) {
          final curvedT = curve.transform(t);
          offsetValue = (isForwardLayout ? 0.65 : -0.65) * (1.0 - curvedT);
          
          if (curvedT <= 0.25) {
            finalChild = Opacity(opacity: 0.0, child: finalChild);
          } else {
            final p = ((curvedT - 0.25) / 0.75).clamp(0.0, 1.0);
            final blurAmount = 3.0 * (1.0 - p);
            if (blurAmount > 0.0) {
              finalChild = ImageFiltered(
                imageFilter: dart_ui.ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
                child: finalChild,
              );
            }
            if (p < 1.0) {
              finalChild = Opacity(opacity: p, child: finalChild);
            }
          }
        } else {
          final curvedS = curve.transform(s);
          offsetValue = (isForwardLayout ? -0.3 : 0.3) * curvedS;
          
          final blurAmount = 3.0 * curvedS;
          if (blurAmount > 0.0) {
            finalChild = ImageFiltered(
              imageFilter: dart_ui.ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
              child: finalChild,
            );
          }
        }

        return Transform.translate(
          offset: Offset(offsetValue * MediaQuery.of(context).size.width, 0),
          child: finalChild,
        );
      },
      child: child,
    );
  }
}

// ============================================================================
// SMOOTH PAGE TRANSITION (deprecated)
// ============================================================================
@Deprecated('Use FluxPageTransition')
class SmoothPageTransition extends BouncyPageTransition {
  SmoothPageTransition({
    required super.child,
    super.offset = 0.1,
  });
}

// ============================================================================
// WIGGLE
// ============================================================================
class Wiggle extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double angle;

  const Wiggle({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.angle = 0.1,
  });

  @override
  State<Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<Wiggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _controller.forward();
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
        final t = _controller.value;
        final wiggle = math.sin(t * math.pi * 5) * widget.angle * (1.0 - t);
        return Transform.rotate(
          angle: wiggle,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// SHAKE
// ============================================================================
class Shake extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;

  const Shake({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.offset = 15.0,
  });

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _controller.forward();
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
        final t = _controller.value;
        final shake = math.sin(t * math.pi * 7) * widget.offset * (1.0 - t);
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// BOUNCE IN
// ============================================================================
class BounceIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const BounceIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = FluxDurations.bouncy,
  });

  @override
  State<BounceIn> createState() => _BounceInState();
}

class _BounceInState extends State<BounceIn>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = FluxCurves.bouncy.transform(_controller.value);
        final opacityT = FluxCurves.easeOut.transform(_controller.value);
        return Opacity(
          opacity: opacityT.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: t.clamp(0.0, 1.2), // prevent extreme overshoots
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
