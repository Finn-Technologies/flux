import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class FluxColors {
  // Light theme
  static const lightBackground = Color(0xFFF5F5F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSecondary = Color(0xFFF0F0F2);
  static const lightBorder = Color(0xFFE5E5E7);
  static const lightBorderStrong = Color(0xFFD1D1D6);
  static const lightText = Color(0xFF1C1C1E);
  static const lightTextSecondary = Color(0xFF8E8E93);
  static const lightTextTertiary = Color(0xFFC7C7CC);
  static const lightOverlay = Color(0xB3FFFFFF);
  static const lightAccent = Color(0xFF007AFF);

  // Dark theme
  static const darkBackground = Color(0xFF000000);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkSurfaceSecondary = Color(0xFF2C2C2E);
  static const darkBorder = Color(0xFF38383A);
  static const darkBorderStrong = Color(0xFF48484A);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF8E8E93);
  static const darkTextTertiary = Color(0xFF636366);
  static const darkOverlay = Color(0xB3000000);
  static const darkAccent = Color(0xFF0A84FF);

  // Semantic colors (same in both themes)
  static const error = Color(0xFFFF3B30);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
}

class FluxTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colors = isLight
        ? const FluxColorsExtension(
            textPrimary: FluxColors.lightText,
            textSecondary: FluxColors.lightTextSecondary,
            textTertiary: FluxColors.lightTextTertiary,
            background: FluxColors.lightBackground,
            surface: FluxColors.lightSurface,
            surfaceSecondary: FluxColors.lightSurfaceSecondary,
            border: FluxColors.lightBorder,
            borderStrong: FluxColors.lightBorderStrong,
            overlay: FluxColors.lightOverlay,
            accent: FluxColors.lightAccent,
          )
        : const FluxColorsExtension(
            textPrimary: FluxColors.darkText,
            textSecondary: FluxColors.darkTextSecondary,
            textTertiary: FluxColors.darkTextTertiary,
            background: FluxColors.darkBackground,
            surface: FluxColors.darkSurface,
            surfaceSecondary: FluxColors.darkSurfaceSecondary,
            border: FluxColors.darkBorder,
            borderStrong: FluxColors.darkBorderStrong,
            overlay: FluxColors.darkOverlay,
            accent: FluxColors.darkAccent,
          );

    final textPrimary = colors.textPrimary;
    final textSecondary = colors.textSecondary;
    final background = colors.background;
    final surface = colors.surface;
    final border = colors.border;

    final baseTextTheme = GoogleFonts.instrumentSansTextTheme(
      isLight ? Typography.blackMountainView : Typography.whiteMountainView,
    );

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        color: textPrimary,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        height: 1.25,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        color: textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        height: 1.35,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: -0.1,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: -0.1,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        color: textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      colorScheme: isLight
          ? ColorScheme.light(
              surface: background,
              primary: textPrimary,
              onPrimary: background,
              secondary: textSecondary,
              onSecondary: background,
              surfaceContainerHighest: surface,
              outline: border,
              outlineVariant: border,
              error: FluxColors.error,
              onSurface: textPrimary,
              onError: background,
            )
          : ColorScheme.dark(
              surface: background,
              primary: textPrimary,
              onPrimary: background,
              secondary: textSecondary,
              onSecondary: background,
              surfaceContainerHighest: surface,
              outline: border,
              outlineVariant: border,
              error: FluxColors.error,
              onSurface: textPrimary,
              onError: background,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: IconThemeData(color: textPrimary),
        systemOverlayStyle: (isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light).copyWith(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: textPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.instrumentSans(
          color: textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: surface,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: textPrimary, size: 24);
          }
          return IconThemeData(color: textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
          return GoogleFonts.instrumentSans(
            color: textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }
        return GoogleFonts.instrumentSans(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: background,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.instrumentSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: GoogleFonts.instrumentSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 0.5,
        space: 0.5,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        minVerticalPadding: 12,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
      ),
      extensions: [colors],
    );
  }
}

class FluxColorsExtension extends ThemeExtension<FluxColorsExtension> {
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color border;
  final Color borderStrong;
  final Color overlay;
  final Color accent;

  const FluxColorsExtension({
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.border,
    required this.borderStrong,
    required this.overlay,
    required this.accent,
  });

  @override
  ThemeExtension<FluxColorsExtension> copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? background,
    Color? surface,
    Color? surfaceSecondary,
    Color? border,
    Color? borderStrong,
    Color? overlay,
    Color? accent,
  }) {
    return FluxColorsExtension(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      overlay: overlay ?? this.overlay,
      accent: accent ?? this.accent,
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
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}
