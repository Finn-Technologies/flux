import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/onboarding/choose_model_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/assistant/assistant_screen.dart';
import 'features/models/model_library_screen.dart';
import 'features/downloads/downloads_screen.dart';
import 'features/settings/settings_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarded') ?? false;

  runApp(
    ProviderScope(
      child: FluxApp(onboarded: onboarded),
    ),
  );
}

class FluxTheme {
  static const _seedColor = Color(0xFF6750A4);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
            seedColor: _seedColor, brightness: Brightness.light),
        appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark),
        cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
        ),
        dividerTheme: const DividerThemeData(thickness: 0.5, space: 0.5),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: _seedColor, brightness: Brightness.dark),
        appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light),
        cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
        ),
        dividerTheme: const DividerThemeData(thickness: 0.5, space: 0.5),
      );
}

class FluxApp extends ConsumerWidget {
  final bool onboarded;
  const FluxApp({super.key, required this.onboarded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: onboarded ? '/home' : '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
          routes: [
            GoRoute(
                path: 'choose-model',
                builder: (context, state) => const ChooseModelScreen()),
          ],
        ),
        GoRoute(path: '/home', builder: (context, state) => const ChatScreen()),
        GoRoute(
            path: '/assistant',
            builder: (context, state) => const AssistantScreen()),
        GoRoute(
            path: '/models',
            builder: (context, state) => const ModelLibraryScreen()),
        GoRoute(
            path: '/downloads',
            builder: (context, state) => const DownloadsScreen()),
        GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen()),
        GoRoute(
          path: '/model/:id',
          builder: (context, state) => ChatScreen(modelId: state.params['id']),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Flux',
      debugShowCheckedModeBanner: false,
      theme: FluxTheme.light,
      darkTheme: FluxTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supported) {
        return supported.contains(locale) ? locale : const Locale('en');
      },
    );
  }
}
