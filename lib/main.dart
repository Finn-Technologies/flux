import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
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
import 'features/settings/about_screen.dart';
import 'core/widgets/flux_shell.dart';
import 'core/theme/flux_theme.dart';
import 'core/widgets/flux_animations.dart';

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

// Smooth, balanced page transition with parallax and delayed reveal
CustomTransitionPage buildSlidePage({
  required GoRouterState state,
  required Widget child,
  required double position,
  double Function(BuildContext context)? resolvePosition,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tabInfo = TabNavigationInfo.of(context);
      final isTabSwitch = tabInfo != null && tabInfo.previousIndex != tabInfo.currentIndex;
      
      // Spatial Layout:
      // true = foreground route lives on the right, background lives on the left.
      // false = foreground route lives on the left, background lives on the right.
      bool isForwardLayout = true;
      if (isTabSwitch) {
        isForwardLayout = tabInfo.currentIndex > tabInfo.previousIndex;
      }

      return FluxPageTransition(
        primaryAnimation: animation,
        secondaryAnimation: secondaryAnimation,
        isForwardLayout: isForwardLayout,
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
            position: 0,
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
                position: -0.08,
              ),
            ),
            GoRoute(
              path: '/creations',
              pageBuilder: (context, state) => buildSlidePage(
                state: state,
                child: const CreationsScreen(),
                position: 0.04,
                resolvePosition: (context) {
                  final tabInfo = TabNavigationInfo.of(context);
                  if (tabInfo == null) return 0.04;
                  if (tabInfo.previousIndex > tabInfo.currentIndex) {
                    return -0.04;
                  }
                  return 0.04;
                },
              ),
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => buildSlidePage(
                state: state,
                child: const SettingsScreen(),
                position: 0.08,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/settings/models',
          pageBuilder: (context, state) => buildSlidePage(
            state: state,
            child: const ModelsScreen(),
            position: 0.16,
          ),
        ),
        GoRoute(
          path: '/settings/about',
          pageBuilder: (context, state) => buildSlidePage(
            state: state,
            child: const AboutScreen(),
            position: 0.16,
          ),
        ),
        GoRoute(
          path: '/model/:id',
          pageBuilder: (context, state) => buildSlidePage(
            state: state,
            child: ChatScreen(modelId: state.params['id']),
            position: 0.08,
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
              position: 0.16,
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
