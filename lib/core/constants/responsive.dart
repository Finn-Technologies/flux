import 'package:flutter/material.dart';

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1100;
}

extension ResponsiveContext on BuildContext {
  bool get isMobile => width < Breakpoints.mobile;
  bool get isTablet => width >= Breakpoints.mobile && width < Breakpoints.tablet;
  bool get isDesktop => width >= Breakpoints.tablet;
  bool get isWideDesktop => width >= Breakpoints.desktop;

  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;
  double get topPadding => MediaQuery.of(this).padding.top;
  double get bottomInset => MediaQuery.of(this).viewInsets.bottom;
  double get keyboardHeight => MediaQuery.of(this).viewInsets.bottom;

  double get contentMaxWidth =>
      isDesktop ? 900 : (isTablet ? 700 : double.infinity);

  EdgeInsets get screenPadding =>
      EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: isDesktop ? 32 : 0,
      );
}

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  const ResponsiveCenter({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final mw = maxWidth ?? context.contentMaxWidth;
    if (mw >= double.infinity) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: child,
      ),
    );
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isDesktop) builder;
  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return builder(context, context.isDesktop);
  }
}
