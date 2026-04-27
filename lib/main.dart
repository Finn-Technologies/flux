import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/chat/chat_screen.dart';
import 'features/creations/creations_screen.dart';
import 'features/creations/creation_editor_screen.dart';
import 'features/creations/creation_app_screen.dart';
import 'features/models/models_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/licenses_screen.dart';
import 'core/widgets/flux_shell.dart';
import 'core/theme/flux_theme.dart';

import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('models');
  await Hive.openBox('settings');
  await Hive.openBox('chats');
  await Hive.openBox('creations');

  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarded') ?? false;

  // Desktop-aware system UI overlay
  final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  if (!isDesktop) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  runApp(ProviderScope(child: FluxApp(onboarded: onboarded)));
}

// Unified smooth, non-bouncy page transition for all routes
CustomTransitionPage buildSlidePage({
  required GoRouterState state,
  required Widget child,
  required double position,
  double Function(BuildContext context)? resolvePosition,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = Curves.easeInOutCubic;
      return AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        builder: (context, child) {
          final effectivePosition = resolvePosition?.call(context) ?? position;
          final thisProgress = curve.transform(animation.value);
          final secondaryProgress = curve.transform(secondaryAnimation.value);

          final thisOffset = effectivePosition * (1.0 - thisProgress);
          final combinedOffset = thisOffset - (0.05 * secondaryProgress * (effectivePosition > 0 ? -1 : 1));

          return Transform.translate(
            offset: Offset(combinedOffset * MediaQuery.of(context).size.width, 0),
            child: Opacity(
              opacity: 0.4 + (0.6 * thisProgress.clamp(0.0, 1.0)),
              child: child,
            ),
          );
        },
        child: child,
      );
    },
  );
}

class FluxApp extends StatefulWidget {
  final bool onboarded;
  const FluxApp({super.key, required this.onboarded});

  @override
  State<FluxApp> createState() => _FluxAppState();
}

class _FluxAppState extends State<FluxApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: widget.onboarded ? '/home' : '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          pageBuilder: (context, state) => buildSlidePage(
            state: state,
            child: const OnboardingScreen(),
            position: 0, // Root
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => FluxShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => buildSlidePage(
                state: state,
                child: const ChatScreen(),
                position: -0.12, // Home is on the LEFT
              ),
            ),
            GoRoute(
              path: '/creations',
              pageBuilder: (context, state) => buildSlidePage(
                state: state,
                child: const CreationsScreen(),
                position: 0.06, // Default: slides from right
                resolvePosition: (context) {
                  final tabInfo = TabNavigationInfo.of(context);
                  if (tabInfo == null) return 0.06;
                  // Navigating from right (Settings) -> slide from left
                  if (tabInfo.previousIndex > tabInfo.currentIndex) {
                    return -0.06;
                  }
                  // Navigating from left (Home) -> slide from right
                  return 0.06;
                },
              ),
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => buildSlidePage(
                state: state,
                child: const SettingsScreen(),
                position: 0.12, // Settings is on the RIGHT
              ),
            ),
          ],
        ),
        // Hierarchical routes use the same slide animation as tabs for consistency
        GoRoute(
          path: '/settings/models',
          pageBuilder: (context, state) => buildSlidePage(
            state: state,
            child: const ModelsScreen(),
            position: 0.24,
          ),
        ),
        GoRoute(
          path: '/settings/licenses',
          pageBuilder: (context, state) => buildSlidePage(
            state: state,
            child: const LicensesScreen(),
            position: 0.24,
          ),
        ),
        GoRoute(
          path: '/model/:id',
          pageBuilder: (context, state) => buildSlidePage(
            state: state,
            child: ChatScreen(modelId: state.params['id']),
            position: 0.12,
          ),
        ),
        GoRoute(
          path: '/creations/editor',
          pageBuilder: (context, state) {
            final id = (state.extra as String?) ?? state.queryParams['id'];
            return buildSlidePage(
              state: state,
              child: CreationEditorScreen(creationId: id),
              position: 0.12,
            );
          },
        ),
        GoRoute(
          path: '/creations/app/:id',
          pageBuilder: (context, state) {
            final id = state.params['id']!;
            return buildSlidePage(
              state: state,
              child: CreationAppScreen(creationId: id),
              position: 0.2,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flux',
      debugShowCheckedModeBanner: false,
      theme: FluxTheme.light,
      darkTheme: FluxTheme.dark,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
