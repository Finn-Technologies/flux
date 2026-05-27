import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/flux_theme.dart';
import 'flux_animations.dart';

enum BackdropState { idle, loading }

class FluxBackdrop extends StatelessWidget {
  final bool compact;
  final BackdropState state;

  const FluxBackdrop({
    super.key,
    this.compact = false,
    this.state = BackdropState.idle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).extension<FluxColorsExtension>()!.background;

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BackdropPainter(
            drift: 0.5,
            loadT: state == BackdropState.loading ? 1.0 : 0.0,
            isDark: isDark,
            bg: bg,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final double drift;
  final double loadT;
  final bool isDark;
  final Color bg;

  _BackdropPainter({
    required this.drift,
    required this.loadT,
    required this.isDark,
    required this.bg,
  });

  static const _idleA1 = Color(0x507DFFCD);
  static const _idleA2 = Color(0x4000FF2B);
  static const _idleDark1 = Color(0x505CFFB5);
  static const _idleDark2 = Color(0x403AFF65);
  static const _idleB1 = Color(0x4860E8D0);
  static const _idleB2 = Color(0x3800D4AA);
  static const _idleBDark1 = Color(0x4840D0B0);
  static const _idleBDark2 = Color(0x3830C8AA);
  static const _loadL1 = Color(0x50E8A0BF);
  static const _loadL2 = Color(0x40EFBAD5);
  static const _loadD1 = Color(0x50D48FAB);
  static const _loadD2 = Color(0x40C87DAA);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = bg,
    );

    final t = drift;
    final s = loadT;
    final cyc = (drift * 0.64 + 0.18) % 1.0;

    final c1 = Color.lerp(
      Color.lerp(isDark ? _idleDark1 : _idleA1, isDark ? _idleBDark1 : _idleB1, cyc),
      isDark ? _loadD1 : _loadL1,
      s,
    )!;
    final c2 = Color.lerp(
      Color.lerp(isDark ? _idleDark2 : _idleA2, isDark ? _idleBDark2 : _idleB2, cyc),
      isDark ? _loadD2 : _loadL2,
      s,
    )!;

    final rect = Offset.zero & size;
    final transparent = bg.withValues(alpha: 0);
    final paint = Paint();

    final begin1 = Alignment(-0.6 + t * 0.4, 1.0);
    final end1 = Alignment(0.3 - t * 0.2, 0.2 + t * 0.15);
    paint.shader = LinearGradient(
      begin: begin1,
      end: end1,
      colors: [c1, transparent],
    ).createShader(rect);
    canvas.drawRect(rect, paint);

    final begin2 = Alignment(0.6 - t * 0.5, 1.0);
    final end2 = Alignment(-0.3 + t * 0.3, 0.25 + t * 0.1);
    paint.shader = LinearGradient(
      begin: begin2,
      end: end2,
      colors: [c2, transparent],
    ).createShader(rect);
    canvas.drawRect(rect, paint);

    final c3 = Color.lerp(c1, c2, 0.5)!.withValues(alpha: 0.18);
    paint.shader = LinearGradient(
      begin: Alignment(0.0 + t * 0.2, 1.0),
      end: Alignment(0.0 - t * 0.1, 0.35 + t * 0.1),
      colors: [c3, transparent],
    ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      drift != old.drift || loadT != old.loadT || isDark != old.isDark || bg != old.bg;
}

// ============================================================================
// FluxDottedBackground — soft low-opacity dot pattern. Cheap (single
// CustomPainter, no animation). Use as a background layer to give any
// page that playful sticker-on-paper feel.
// ============================================================================
class FluxDottedBackground extends StatelessWidget {
  final Widget child;
  final double spacing;
  final double radius;
  final double opacity;

  const FluxDottedBackground({
    super.key,
    required this.child,
    this.spacing = 22.0,
    this.radius = 1.0,
    this.opacity = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _FluxDotPatternPainter(
                color: flux.textPrimary,
                spacing: spacing,
                radius: radius,
                opacity: opacity,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _FluxDotPatternPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double radius;
  final double opacity;

  _FluxDotPatternPainter({
    required this.color,
    required this.spacing,
    required this.radius,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: opacity);
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FluxDotPatternPainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.radius != radius ||
      old.opacity != opacity;
}

class FluxBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const FluxBackButton({super.key, required this.onTap, this.label = 'Back'});

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
              'assets/images/back_icon.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                flux.textSecondary,
                BlendMode.srcIn,
              ),
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

class FluxTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const FluxTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: textTheme.displaySmall),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: textTheme.bodySmall),
        ],
      ],
    );
  }
}

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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: flux.textPrimary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
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
              fontWeight: FontWeight.w400,
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
    );
  }
}

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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _phase(int i) {
    final raw = (_controller.value + i * 0.2) % 1.0;
    return raw < 0.5 ? raw * 2.0 : 2.0 - raw * 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final a = _phase(index);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: flux.textSecondary.withValues(alpha: 0.3 + 0.7 * a),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class FluxSendButton extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onStop;
  final bool isEnabled;
  final bool isStreaming;

  const FluxSendButton({
    super.key,
    this.onTap,
    this.onStop,
    required this.isEnabled,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;

    if (isStreaming) {
      return BouncyTap(
        onTap: onStop,
        scaleDown: 0.85,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: flux.textPrimary,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.stop_rounded, color: flux.background, size: 20),
        ),
      );
    }

    return BouncyTap(
      onTap: isEnabled ? onTap : null,
      scaleDown: 0.85,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled ? flux.textPrimary : flux.textTertiary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Image.asset(
            'assets/images/arrow.png',
            width: 18,
            height: 18,
            color: flux.background,
          ),
        ),
      ),
    );
  }
}
