import 'dart:ui';
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
import 'core/widgets/flux_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class FluxColors {
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF7F7F8);
  static const lightBorder = Color(0xFFE5E5E5);
  static const lightText = Color(0xFF0A0A0A);
  static const lightTextSecondary = Color(0xFF6B6B6B);
  static const lightOverlay = Color(0xB3FFFFFF);

  static const darkBackground = Color(0xFF0A0A0A);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkBorder = Color(0xFF2E2E2E);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF8B8B8B);
  static const darkOverlay = Color(0xB31A1A1A);
}

class FluxTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: FluxColors.lightBackground,
        colorScheme: const ColorScheme.light(
          surface: FluxColors.lightBackground,
          primary: FluxColors.lightText,
          onPrimary: FluxColors.lightBackground,
          secondary: FluxColors.lightTextSecondary,
          onSecondary: FluxColors.lightBackground,
          surfaceContainerHighest: FluxColors.lightSurface,
          outline: FluxColors.lightBorder,
          outlineVariant: FluxColors.lightBorder,
          error: Color(0xFFDC2626),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: FluxColors.lightBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: FluxColors.lightText,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: FluxColors.lightText),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: FluxColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
                color: FluxColors.lightBorder.withValues(alpha: 0.5)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: FluxColors.lightSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
                color: FluxColors.lightBorder.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide:
                const BorderSide(color: FluxColors.lightText, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(
            color: FluxColors.lightTextSecondary,
            fontSize: 16,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: FluxColors.lightSurface,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: FluxColors.lightText, size: 24);
            }
            return const IconThemeData(
                color: FluxColors.lightTextSecondary, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  color: FluxColors.lightText,
                  fontSize: 11,
                  fontWeight: FontWeight.w500);
            }
            return const TextStyle(
                color: FluxColors.lightTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400);
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: FluxColors.lightText,
            foregroundColor: FluxColors.lightBackground,
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: FluxColors.lightText,
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: FluxColors.lightBorder,
          thickness: 0.5,
          space: 0.5,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 24),
          minVerticalPadding: 14,
        ),
        extensions: const [
          FluxColorsExtension(
            textPrimary: FluxColors.lightText,
            textSecondary: FluxColors.lightTextSecondary,
            background: FluxColors.lightBackground,
            surface: FluxColors.lightSurface,
            border: FluxColors.lightBorder,
            overlay: FluxColors.lightOverlay,
          ),
        ],
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: FluxColors.darkBackground,
        colorScheme: const ColorScheme.dark(
          surface: FluxColors.darkBackground,
          primary: FluxColors.darkText,
          onPrimary: FluxColors.darkBackground,
          secondary: FluxColors.darkTextSecondary,
          onSecondary: FluxColors.darkBackground,
          surfaceContainerHighest: FluxColors.darkSurface,
          outline: FluxColors.darkBorder,
          outlineVariant: FluxColors.darkBorder,
          error: Color(0xFFEF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: FluxColors.darkBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: FluxColors.darkText,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: FluxColors.darkText),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: FluxColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side:
                BorderSide(color: FluxColors.darkBorder.withValues(alpha: 0.5)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: FluxColors.darkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide:
                BorderSide(color: FluxColors.darkBorder.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide:
                const BorderSide(color: FluxColors.darkText, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(
            color: FluxColors.darkTextSecondary,
            fontSize: 16,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: FluxColors.darkSurface,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: FluxColors.darkText, size: 24);
            }
            return const IconThemeData(
                color: FluxColors.darkTextSecondary, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  color: FluxColors.darkText,
                  fontSize: 11,
                  fontWeight: FontWeight.w500);
            }
            return const TextStyle(
                color: FluxColors.darkTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400);
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: FluxColors.darkText,
            foregroundColor: FluxColors.darkBackground,
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: FluxColors.darkText,
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: FluxColors.darkBorder,
          thickness: 0.5,
          space: 0.5,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 24),
          minVerticalPadding: 14,
        ),
        extensions: const [
          FluxColorsExtension(
            textPrimary: FluxColors.darkText,
            textSecondary: FluxColors.darkTextSecondary,
            background: FluxColors.darkBackground,
            surface: FluxColors.darkSurface,
            border: FluxColors.darkBorder,
            overlay: FluxColors.darkOverlay,
          ),
        ],
      );
}

class FluxColorsExtension extends ThemeExtension<FluxColorsExtension> {
  final Color textPrimary;
  final Color textSecondary;
  final Color background;
  final Color surface;
  final Color border;
  final Color overlay;

  const FluxColorsExtension({
    required this.textPrimary,
    required this.textSecondary,
    required this.background,
    required this.surface,
    required this.border,
    required this.overlay,
  });

  @override
  ThemeExtension<FluxColorsExtension> copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? background,
    Color? surface,
    Color? border,
    Color? overlay,
  }) {
    return FluxColorsExtension(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  ThemeExtension<FluxColorsExtension> lerp(
    covariant ThemeExtension<FluxColorsExtension>? other,
    double t,
  ) {
    if (other is! FluxColorsExtension) return this;
    return FluxColorsExtension(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
    );
  }
}

class FluxApp extends ConsumerWidget {
  final bool onboarded;
  const FluxApp({super.key, required this.onboarded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: onboarded ? '/chat' : '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
          routes: [
            GoRoute(
              path: 'choose-model',
              builder: (context, state) => const ChooseModelScreen(),
            ),
          ],
        ),
        ShellRoute(
          builder: (context, state, child) => FluxShell(child: child),
          routes: [
            GoRoute(
                path: '/chat', builder: (context, state) => const ChatScreen()),
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
          ],
        ),
        GoRoute(
          path: '/model/:id',
          builder: (context, state) =>
              ChatScreen(modelId: state.location.split('/').last),
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
