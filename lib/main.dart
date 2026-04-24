import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/onboarding/choose_model_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/models/models_screen.dart';
import 'features/settings/settings_screen.dart';
import 'core/widgets/flux_shell.dart';
import 'core/theme/flux_theme.dart';

import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('models');
  await Hive.openBox('settings');
  await Hive.openBox('chats');

  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarded') ?? false;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(ProviderScope(child: FluxApp(onboarded: onboarded)));
}

// Helper for consistent tab-style slide transitions across the app
// Each tab has a spatial position and slides from/to that position
// Unified smooth animation for all transitions
CustomTransitionPage buildSlidePage({
  required GoRouterState state,
  required Widget child,
  required double position,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Use smooth spring-like curve
      final curve = Curves.easeInOutCubicEmphasized;
      
      return AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        builder: (context, child) {
          final thisProgress = curve.transform(animation.value);
          final secondaryProgress = curve.transform(secondaryAnimation.value);
          
          // Calculate offset with smooth interpolation
          final thisOffset = position * (1.0 - thisProgress);
          final combinedOffset = thisOffset - (0.08 * secondaryProgress * (position > 0 ? -1 : 1));
          
          // Add subtle scale for depth
          final scale = 0.98 + (0.02 * thisProgress);
          
          return Transform.scale(
            scale: scale.clamp(0.98, 1.0),
            child: Transform.translate(
              offset: Offset(combinedOffset * MediaQuery.of(context).size.width, 0),
              child: Opacity(
                opacity: 0.5 + (0.5 * thisProgress.clamp(0.0, 1.0)),
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

// Hierarchical push/pop - same smooth animation
CustomTransitionPage buildPopPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = Curves.easeInOutCubicEmphasized;
      
      return AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        builder: (context, child) {
          final primaryProgress = curve.transform(animation.value);
          final secondaryProgress = curve.transform(secondaryAnimation.value);
          
          // Push: enter from right (0.15 to 0)
          // Pop: exit to right (0 to 0.15)
          final dx = 0.15 * (1.0 - primaryProgress) - 0.08 * secondaryProgress;
          final scale = 0.98 + (0.02 * primaryProgress);
          
          return Transform.scale(
            scale: scale.clamp(0.98, 1.0),
            child: Transform.translate(
              offset: Offset(dx * MediaQuery.of(context).size.width, 0),
              child: Opacity(
                opacity: 0.5 + (0.5 * primaryProgress.clamp(0.0, 1.0)),
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
          routes: [
            GoRoute(
              path: 'choose-model',
              pageBuilder: (context, state) => buildPopPage(
                state: state,
                child: const ChooseModelScreen(),
              ),
            ),
          ],
        ),
        ShellRoute(
          builder: (context, state, child) => FluxShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => buildSlidePage(
                state: state,
                child: const ChatScreen(),
                position: -0.15, // Home is on the LEFT
              ),
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => buildSlidePage(
                state: state,
                child: const SettingsScreen(),
                position: 0.15, // Settings is on the RIGHT
              ),
            ),
          ],
        ),
        // Models as separate route with faster pop animation
        GoRoute(
          path: '/settings/models',
          pageBuilder: (context, state) => buildPopPage(
            state: state,
            child: const ModelsScreen(),
          ),
        ),
        GoRoute(
          path: '/model/:id',
          pageBuilder: (context, state) => buildPopPage(
            state: state,
            child: ChatScreen(modelId: state.params['id']),
          ),
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
      routerConfig: _router,
    );
  }
}
