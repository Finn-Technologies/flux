import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/responsive.dart';
import '../theme/flux_theme.dart';
import '../providers/sidebar_provider.dart';
import '../../features/chat/chat_history_screen.dart';

class TabNavigationInfo extends InheritedWidget {
  final int previousIndex;
  final int currentIndex;

  const TabNavigationInfo({
    super.key,
    required this.previousIndex,
    required this.currentIndex,
    required super.child,
  });

  static TabNavigationInfo? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabNavigationInfo>();
  }

  @override
  bool updateShouldNotify(TabNavigationInfo oldWidget) {
    return previousIndex != oldWidget.previousIndex ||
        currentIndex != oldWidget.currentIndex;
  }
}

class FluxShell extends ConsumerStatefulWidget {
  final Widget child;

  const FluxShell({super.key, required this.child});

  @override
  ConsumerState<FluxShell> createState() => _FluxShellState();
}

class _FluxShellState extends ConsumerState<FluxShell> {
  int _currentIndex = 0;
  int _previousIndex = 0;
  double _sidebarWidth = 400.0;
  static const double _minSidebarWidth = 200.0;
  static const double _maxSidebarWidth = 400.0;
  bool _isDragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextIndex = _getIndexFromLocation(GoRouterState.of(context).location);
    if (nextIndex != _currentIndex) {
      _previousIndex = _currentIndex;
      _currentIndex = nextIndex;
    }
  }

  int _getIndexFromLocation(String location) {
    if (location.startsWith('/home')) {
      return 0;
    }
    if (location.startsWith('/creations')) {
      return 1;
    }
    if (location.startsWith('/settings')) {
      return 2;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final isSidebarOpen = ref.watch(sidebarOpenProvider);

    final body = TabNavigationInfo(
      previousIndex: _previousIndex,
      currentIndex: _currentIndex,
      child: isDesktop ? ResponsiveCenter(child: widget.child) : widget.child,
    );

    return Scaffold(
      backgroundColor: flux.background,
      resizeToAvoidBottomInset: false,
      body: Row(
        children: [
          if (isDesktop)
            AnimatedContainer(
              duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isSidebarOpen ? _sidebarWidth + 8.0 : 0.0,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerRight,
                  minWidth: _sidebarWidth + 8.0,
                  maxWidth: _sidebarWidth + 8.0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: _sidebarWidth,
                        child: const RepaintBoundary(child: ChatHistoryScreen()),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanStart: (_) => setState(() => _isDragging = true),
                          onPanUpdate: (details) {
                            setState(() {
                              _sidebarWidth += details.delta.dx;
                              if (_sidebarWidth < _minSidebarWidth) {
                                _sidebarWidth = _minSidebarWidth;
                              } else if (_sidebarWidth > _maxSidebarWidth) {
                                _sidebarWidth = _maxSidebarWidth;
                              }
                            });
                          },
                          onPanEnd: (_) => setState(() => _isDragging = false),
                          onPanCancel: () => setState(() => _isDragging = false),
                          child: Container(
                            width: 8,
                            alignment: Alignment.center,
                            child: Container(
                              width: 1,
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: RepaintBoundary(child: body),
          ),
        ],
      ),
    );
  }
}
