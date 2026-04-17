import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  // Figma colors
  static const Color _background = Color(0xFFF9F9F9);
  static const Color _black = Color(0xFF000000);
  static const Color _textSecondary = Color.fromRGBO(0, 0, 0, 0.5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          // Main content - use the ShellRoute's child (current page)
          Positioned.fill(
            child: widget.child,
          ),

          // Bottom Navigation - Clean dock style
          // No background, no borders, icons only
          // 50% opacity when not active, 100% when active
          // Only 2 screens: Home and Settings
          Positioned(
            left: 20,
            right: 20,
            bottom: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Home (index 0)
                _buildNavItem(
                  index: 0,
                  child: (isSelected) {
                    return SvgPicture.asset(
                      'assets/images/home-01.svg',
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        isSelected ? _black : _textSecondary,
                        BlendMode.srcIn,
                      ),
                    );
                  },
                ),
                // Settings (index 1)
                _buildNavItem(
                  index: 1,
                  child: (isSelected) {
                    return SvgPicture.asset(
                      'assets/images/settings-03.svg',
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        isSelected ? _black : _textSecondary,
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
