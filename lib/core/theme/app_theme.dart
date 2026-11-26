import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // MEROUANESAT PREMIUM - Gold
static const Color accent = Color(0xFFD4AF37);
static const Color accentHover = Color(0xFFFFD700);
static const Color accentDeep = Color(0xFFB8860B);

  // Dark theme surface palette.
  static const Color background = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF15151B);
  static const Color surfaceElevated = Color(0xFF1F1F27);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF777777);
  static const Color divider = Color(0xFF2A2A33);
  static const Color buffered = Color(0xFF6A6A77);
  static const Color trackUnplayed = Color(0xFF3A3A45);

  // Theme flag for code paths that branch on it (e.g. on-accent text color).
  static bool _dark = true;
  static bool get isDark => _dark;
  static void setDark(bool v) => _dark = v;
}

class AppTheme {
  static ThemeData build(bool isDark) {
    AppColors.setDark(isDark);
    if (isDark) return _dark();
    return _light();
  }

  static ThemeData _dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      primary: AppColors.accent,
    );
    return _common(base, textTheme, colorScheme,
        bg: AppColors.background,
        surface: AppColors.surface,
        surfaceElevated: AppColors.surfaceElevated,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        textTertiary: AppColors.textTertiary,
        divider: AppColors.divider,
        accentForeground: Colors.black);
  }

  static ThemeData _light() {
    const lightBg = Color(0xFFF6F7FA);
    const lightSurface = Color(0xFFFFFFFF);
    const lightSurfaceElevated = Color(0xFFE9EBF2);
    const lightTextPrimary = Color(0xFF1B1B20);
    const lightTextSecondary = Color(0xFF55555F);
    const lightTextTertiary = Color(0xFF8B8B95);
    const lightDivider = Color(0xFFDADBE3);
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: lightTextPrimary,
      displayColor: lightTextPrimary,
    );
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      surface: lightSurface,
      primary: AppColors.accent,
    );
    return _common(base, textTheme, colorScheme,
        bg: lightBg,
        surface: lightSurface,
        surfaceElevated: lightSurfaceElevated,
        textPrimary: lightTextPrimary,
        textSecondary: lightTextSecondary,
        textTertiary: lightTextTertiary,
        divider: lightDivider,
        accentForeground: Colors.white);
  }

  static ThemeData _common(
    ThemeData base,
    TextTheme textTheme,
    ColorScheme colorScheme, {
    required Color bg,
    required Color surface,
    required Color surfaceElevated,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color divider,
    required Color accentForeground,
  }) {
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg.withValues(alpha: 0.7),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: textPrimary,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      dividerColor: divider,
      iconTheme: IconThemeData(color: textPrimary),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: accentForeground,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: surfaceElevated,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textTertiary,
        indicatorColor: AppColors.accent,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.accent : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.accent.withValues(alpha: 0.5)
                : null),
      ),
    );
  }
}
