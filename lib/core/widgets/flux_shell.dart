import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/models/model_library_screen.dart';
import '../../features/downloads/downloads_screen.dart';
import '../../features/settings/settings_screen.dart';

class FluxShell extends StatefulWidget {
  final Widget child;
  const FluxShell({super.key, required this.child});

  @override
  State<FluxShell> createState() => _FluxShellState();
}

class _FluxShellState extends State<FluxShell> {
  late PageController _pageController;
  int _currentIndex = 0;
  int _previousIndex = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _currentIndex = _getIndexFromLocation(GoRouterState.of(context).location);
      _previousIndex = _currentIndex;
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getIndexFromLocation(String location) {
    if (location.startsWith('/chat')) return 0;
    if (location.startsWith('/models')) return 1;
    if (location.startsWith('/downloads')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onDestinationSelected(int index) {
    if (index == _currentIndex) return;

    HapticFeedback.selectionClick();

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );

    switch (index) {
      case 0:
        context.go('/chat');
        break;
      case 1:
        context.go('/models');
        break;
      case 2:
        context.go('/downloads');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return const ChatScreen();
      case 1:
        return const ModelLibraryScreen();
      case 2:
        return const DownloadsScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const ChatScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor =
        isDark ? FluxColors.darkOverlay : FluxColors.lightOverlay;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.1);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            onPageChanged: (index) {
              setState(() {
                _previousIndex = _currentIndex;
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  final direction = index > _previousIndex ? 1.0 : -1.0;
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(direction * 0.08, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child:
                    KeyedSubtree(key: ValueKey(index), child: _getPage(index)),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Stack(
            children: [
              // Blur behind nav bar
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              // Nav bar container
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: overlayColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  child: NavigationBar(
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    height: 72,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _onDestinationSelected,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.chat_bubble_outline),
                        selectedIcon: Icon(Icons.chat_bubble),
                        label: 'Chat',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.widgets_outlined),
                        selectedIcon: Icon(Icons.widgets),
                        label: 'Models',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.download_outlined),
                        selectedIcon: Icon(Icons.download),
                        label: 'Downloads',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: 'Settings',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
