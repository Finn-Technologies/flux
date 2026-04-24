import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/flux_theme.dart';

class FluxShell extends StatefulWidget {
  final Widget child;
  const FluxShell({super.key, required this.child});

  @override
  State<FluxShell> createState() => _FluxShellState();
}

class _FluxShellState extends State<FluxShell> {
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentIndex = _getIndexFromLocation(GoRouterState.of(context).location);
  }

  int _getIndexFromLocation(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/settings')) return 1;
    return 0;
  }

  void _onDestinationSelected(int index) {
    if (index == _currentIndex) return;

    HapticFeedback.selectionClick();

    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Scaffold(
      backgroundColor: flux.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.child,
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  index: 0,
                  child: (isSelected) {
                    return SvgPicture.asset(
                      'assets/images/home-01.svg',
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        isSelected ? flux.textPrimary : flux.textSecondary,
                        BlendMode.srcIn,
                      ),
                    );
                  },
                ),
                _buildNavItem(
                  index: 1,
                  child: (isSelected) {
                    return SvgPicture.asset(
                      'assets/images/settings-03.svg',
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        isSelected ? flux.textPrimary : flux.textSecondary,
                        BlendMode.srcIn,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required Widget Function(bool isSelected) child,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onDestinationSelected(index),
      child: SizedBox(
        width: 28,
        height: 28,
        child: child(isSelected),
      ),
    );
  }
}
