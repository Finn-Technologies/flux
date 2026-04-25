import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class FluxColors {
  static const lightBackground = Color(0xFFF9F9F9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color.fromRGBO(0, 0, 0, 0.1);
  static const lightText = Color(0xFF000000);
  static const lightTextSecondary = Color.fromRGBO(0, 0, 0, 0.5);
  static const lightOverlay = Color(0xB3FFFFFF);

  static const darkBackground = Color(0xFF0A0A0A);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkBorder = Color(0xFF2E2E2E);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF8B8B8B);
  static const darkOverlay = Color(0xB31A1A1A);
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
            background: FluxColors.lightBackground,
            surface: FluxColors.lightSurface,
            border: FluxColors.lightBorder,
            overlay: FluxColors.lightOverlay,
          )
        : const FluxColorsExtension(
            textPrimary: FluxColors.darkText,
            textSecondary: FluxColors.darkTextSecondary,
            background: FluxColors.darkBackground,
            surface: FluxColors.darkSurface,
            border: FluxColors.darkBorder,
            overlay: FluxColors.darkOverlay,
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
        fontSize: 32,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w400,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        color: textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w500,
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
              error: const Color(0xFFDC2626),
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
              error: const Color(0xFFEF4444),
              onSurface: textPrimary,
              onError: background,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: textPrimary),
        systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: textPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.instrumentSans(
          color: textSecondary,
          fontSize: 16,
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
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: GoogleFonts.instrumentSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 24),
        minVerticalPadding: 14,
      ),
      extensions: [colors],
    );
  }
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
