import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:home_widget/home_widget.dart';
import 'l10n/app_localizations.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/chat/chat_screen.dart';
import 'features/chat/chat_history_screen.dart';
import 'features/creations/creations_screen.dart';

import 'features/creations/creation_app_screen.dart';
import 'features/models/models_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/license_screen.dart';
import 'core/widgets/flux_shell.dart';
import 'core/services/inference_service.dart';
import 'core/services/memory_service.dart';
import 'core/services/performance_service.dart';
import 'core/services/download_notification_service.dart';
import 'core/theme/flux_theme.dart';
import 'core/widgets/flux_animations.dart';
import 'features/you/you_screen.dart';
import 'features/skills/skills_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure the caches directory exists on macOS sandbox
  // (getTemporaryDirectory() returns this path but does not create it)
  if (Platform.isMacOS) {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      print('Cache dir ensured: ${cacheDir.path}');
    } catch (e) {
      print('Warning: could not create cache dir: $e');
    }
  }

  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox('models'),
    Hive.openBox('settings'),
    Hive.openBox('chats'),
    Hive.openBox('creations'),
    Hive.openBox('flux_code_projects'),
  ]);
  final startup = await Future.wait<dynamic>([
    SharedPreferences.getInstance(),
    MemoryService().init(),
    DownloadNotificationService.initialize(),
    PerformanceService.instance.init(),
  ]);
  final prefs = startup.first as SharedPreferences;
  final onboarded = prefs.getBool('onboarded') ?? false;

  // Pre-warm the model on app start so the first message is near-instant
  if (onboarded) {
    final savedModelId = prefs.getString('selectedModelId');
    if (savedModelId != null && savedModelId.isNotEmpty) {
      unawaited(InferenceService().warmUp(savedModelId));
    }
  }

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

class FluxTransitionPage extends CustomTransitionPage {
  FluxTransitionPage({
    required super.key,
    required super.child,
    this.isForwardLayout = true,
    bool? exitToRight,
  })  : exitToRight = exitToRight ?? isForwardLayout,
        super(
          transitionDuration: FluxDurations.pageTransition,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FluxPageTransition(
              primaryAnimation: animation,
              secondaryAnimation: secondaryAnimation,
              isForwardLayout: isForwardLayout,
              exitToRight: exitToRight ?? isForwardLayout,
              child: child,
            );
          },
        );

  final bool isForwardLayout;
  final bool exitToRight;
}

Page<dynamic> buildSlidePage({
  required GoRouterState state,
  required Widget child,
  bool? exitToRight,
}) {
  return FluxTransitionPage(
    key: state.pageKey,
    child: child,
    exitToRight: exitToRight,
  );
}

Page<dynamic> buildSlidePageInverse({
  required GoRouterState state,
  required Widget child,
  bool? exitToRight,
}) {
  return FluxTransitionPage(
    key: state.pageKey,
    child: child,
    isForwardLayout: false,
    exitToRight: exitToRight,
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

  void _setupWidgetClickHandler() {
    HomeWidget.widgetClicked.listen((_) async {
      if (!mounted) return;
      final creationId = await HomeWidget.getWidgetData<String>('creationId',
          defaultValue: '');
      if (creationId != null && creationId.isNotEmpty) {
        _router.push('/creations/app/$creationId');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _setupWidgetClickHandler();
    _router = GoRouter(
      initialLocation: widget.onboarded ? '/home' : '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          pageBuilder: (context, state) => buildSlidePage(
            state: state,
            child: const OnboardingScreen(),
          ),
        ),
        ShellRoute(
          pageBuilder: (context, state, child) => buildSlidePageInverse(
            state: state,
            child: FluxShell(child: child),
            exitToRight: true, // Forces the shell to exit right when covered
          ),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => buildSlidePage(
                state: state,
                child: const ChatScreen(),
              ),
            ),
            GoRoute(
              path: '/creations',
              pageBuilder: (context, state) => buildSlidePageInverse(
                state: state,
                child: const CreationsScreen(),
              ),
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => buildSlidePageInverse(
                state: state,
                child: const SettingsScreen(),
                exitToRight:
                    false, // Forces Settings to slide left when covered so it returns from left-to-right
              ),
              routes: [
                GoRoute(
                  path: 'about',
                  pageBuilder: (context, state) => buildSlidePageInverse(
                    state: state,
                    child: const AboutScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'license/:id',
                      pageBuilder: (context, state) => buildSlidePageInverse(
                        state: state,
                        child: LicenseScreen(id: state.params['id']!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/you',
              pageBuilder: (context, state) => buildSlidePageInverse(
                state: state,
                child: const YouScreen(),
              ),
            ),
            GoRoute(
              path: '/skills',
              pageBuilder: (context, state) => buildSlidePageInverse(
                state: state,
                child: const SkillsScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/history',
          pageBuilder: (context, state) => buildSlidePage(
            state: state,
            child: const ChatHistoryScreen(),
            exitToRight: false, // Forces sidebar to slide left when covered
          ),
        ),
        GoRoute(
          path: '/settings/models',
          pageBuilder: (context, state) => buildSlidePageInverse(
            state: state,
            child: const ModelsScreen(),
          ),
        ),
        GoRoute(
          path: '/model/:id',
          pageBuilder: (context, state) => buildSlidePage(
            state: state,
            child: ChatScreen(modelId: state.params['id']),
          ),
        ),
        GoRoute(
          path: '/creations/app/:id',
          pageBuilder: (context, state) {
            final id = state.params['id']!;
            return buildSlidePage(
              state: state,
              child: CreationAppScreen(creationId: id),
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
