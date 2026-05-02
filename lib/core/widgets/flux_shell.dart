import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_animations.dart';
import '../../l10n/app_localizations.dart';
import '../constants/responsive.dart';

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

class FluxShell extends StatefulWidget {
  final Widget child;
  const FluxShell({super.key, required this.child});

  @override
  State<FluxShell> createState() => _FluxShellState();
}

class _FluxShellState extends State<FluxShell> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentIndex = _getIndexFromLocation(GoRouterState.of(context).location);
  }

  int _getIndexFromLocation(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/creations')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  void _onDestinationSelected(int index) {
    if (index == _currentIndex) return;
    _previousIndex = _currentIndex;
    HapticFeedback.selectionClick();
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/creations'); break;
      case 2: context.go('/settings'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final body = isDesktop
        ? _buildDesktopLayout(context)
        : _buildMobileLayout(context);
    return body;
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;

    return Scaffold(
      backgroundColor: flux.background,
      resizeToAvoidBottomInset: false,
      body: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            width: 64,
            margin: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: flux.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: flux.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNavItem(
                  index: 0,
                  tooltip: AppLocalizations.of(context)!.home,
                  child: (isSelected) => SvgPicture.asset(
                    'assets/images/home-01.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      isSelected ? flux.textPrimary : flux.textSecondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildNavItem(
                  index: 1,
                  tooltip: AppLocalizations.of(context)!.creations,
                  child: (isSelected) => SvgPicture.asset(
                    'assets/images/union.svg',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(
                      isSelected ? flux.textPrimary : flux.textSecondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildNavItem(
                  index: 2,
                  tooltip: AppLocalizations.of(context)!.settings,
                  child: (isSelected) => SvgPicture.asset(
                    'assets/images/settings-03.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      isSelected ? flux.textPrimary : flux.textSecondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TabNavigationInfo(
              previousIndex: _previousIndex,
              currentIndex: _currentIndex,
              child: ResponsiveCenter(child: widget.child),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;

    return Scaffold(
      backgroundColor: flux.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: TabNavigationInfo(
              previousIndex: _previousIndex,
              currentIndex: _currentIndex,
              child: widget.child,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 10 + MediaQuery.of(context).padding.bottom,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(
                        index: 0,
                        tooltip: AppLocalizations.of(context)!.home,
                        child: (isSelected) => SvgPicture.asset(
                          'assets/images/home-01.svg',
                          width: 24,
                          height: 24,
                          colorFilter: ColorFilter.mode(
                            isSelected ? flux.textPrimary : flux.textSecondary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      _buildNavItem(
                        index: 1,
                        tooltip: AppLocalizations.of(context)!.creations,
                        child: (isSelected) => SvgPicture.asset(
                          'assets/images/union.svg',
                          width: 22,
                          height: 22,
                          colorFilter: ColorFilter.mode(
                            isSelected ? flux.textPrimary : flux.textSecondary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      _buildNavItem(
                        index: 2,
                        tooltip: AppLocalizations.of(context)!.settings,
                        child: (isSelected) => SvgPicture.asset(
                          'assets/images/settings-03.svg',
                          width: 24,
                          height: 24,
                          colorFilter: ColorFilter.mode(
                            isSelected ? flux.textPrimary : flux.textSecondary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildNavItem({
    required int index,
    required Widget Function(bool isSelected) child,
    required String tooltip,
  }) {
    final isSelected = _currentIndex == index;

    return Semantics(
      label: tooltip,
      selected: isSelected,
      button: true,
      child: Tooltip(
        message: tooltip,
          child: BouncyTap(
          onTap: () => _onDestinationSelected(index),
          scaleDown: 0.85,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: child(isSelected),
            ),
          ),
        ),
      ),
    );
  }

  FluxColorsExtension get flux {
    return Theme.of(context).extension<FluxColorsExtension>()!;
  }
}
