import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF0B2E4C);
  static const _secondaryColor = Color(0xFFF36B4E);
  static const _tertiaryColor = Color(0xFF1FBF9B);
  static const _surfaceTint = Color(0xFFE7EEF3);

  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: brightness,
        secondary: _secondaryColor,
        tertiary: _tertiaryColor,
      ),
    );

    final textTheme = _buildTextTheme(base.textTheme, isDark: isDark);

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF0B1218) : const Color(0xFFF5F7FA),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF0B1218) : const Color(0xFFF5F7FA),
        foregroundColor: isDark ? const Color(0xFFEFF4F8) : const Color(0xFF0D1B2A),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        color: isDark ? const Color(0xFF141F2B) : Colors.white,
        surfaceTintColor: isDark ? const Color(0xFF1B2A3B) : _surfaceTint,
      ),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF121C28) : const Color(0xFFFDFDFE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A3A4D) : const Color(0xFFE1E7EE),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A3A4D) : const Color(0xFFE1E7EE),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _secondaryColor, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        indicatorColor: isDark
            ? _secondaryColor.withOpacity(0.18)
            : _secondaryColor.withOpacity(0.14),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      dividerColor: isDark ? const Color(0xFF223041) : const Color(0xFFE3E8EE),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, {required bool isDark}) {
    final display = GoogleFonts.spaceGroteskTextTheme(base);
    final body = GoogleFonts.manropeTextTheme(base);
    final merged = body.copyWith(
      displayLarge: display.displayLarge,
      displayMedium: display.displayMedium,
      displaySmall: display.displaySmall,
      headlineLarge: display.headlineLarge,
      headlineMedium: display.headlineMedium,
      headlineSmall: display.headlineSmall,
      titleLarge: display.titleLarge,
      titleMedium: display.titleMedium,
      titleSmall: display.titleSmall,
    );

    final foreground = isDark ? const Color(0xFFEFF4F8) : const Color(0xFF0D1B2A);
    final muted = isDark ? const Color(0xFFA7B4C4) : const Color(0xFF5C6C7B);

    return merged.copyWith(
      displayLarge: merged.displayLarge?.copyWith(color: foreground, fontWeight: FontWeight.w800),
      displayMedium: merged.displayMedium?.copyWith(color: foreground, fontWeight: FontWeight.w800),
      displaySmall: merged.displaySmall?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      headlineMedium: merged.headlineMedium?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      headlineSmall: merged.headlineSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      titleLarge: merged.titleLarge?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      titleMedium: merged.titleMedium?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      titleSmall: merged.titleSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      bodyLarge: merged.bodyLarge?.copyWith(color: foreground),
      bodyMedium: merged.bodyMedium?.copyWith(color: muted),
      bodySmall: merged.bodySmall?.copyWith(color: muted),
      labelLarge: merged.labelLarge?.copyWith(color: foreground),
      labelMedium: merged.labelMedium?.copyWith(color: muted),
    );
  }
}
