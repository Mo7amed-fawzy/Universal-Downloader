import 'package:flutter/material.dart';

/// Material 3 themes for the application.
class AppTheme {
  const AppTheme._();

  static const _violet = Color(0xFF6828F5);
  static const _lime = Color(0xFFD5F438);

  static ThemeData light() => _base(
    ColorScheme.fromSeed(seedColor: _violet).copyWith(
      primary: _violet,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFECE3FF),
      onPrimaryContainer: const Color(0xFF381379),
      secondary: const Color(0xFF526400),
      onSecondary: Colors.white,
      secondaryContainer: _lime,
      onSecondaryContainer: const Color(0xFF263000),
      surface: const Color(0xFFF7F5FC),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFEFCFF),
      surfaceContainer: const Color(0xFFF0EBF8),
      surfaceContainerHigh: const Color(0xFFECE6F5),
      surfaceContainerHighest: const Color(0xFFE5DEF0),
      onSurface: const Color(0xFF231A35),
      onSurfaceVariant: const Color(0xFF61566F),
      outline: const Color(0xFF84768F),
      outlineVariant: const Color(0xFFDFD6ED),
    ),
  );

  static ThemeData dark() => _base(
    ColorScheme.fromSeed(
      seedColor: _violet,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFA884FF),
      onPrimary: const Color(0xFF210052),
      primaryContainer: const Color(0xFF302442),
      onPrimaryContainer: const Color(0xFFECE3FF),
      secondary: _lime,
      onSecondary: const Color(0xFF263000),
      secondaryContainer: _lime,
      onSecondaryContainer: const Color(0xFF263000),
      surface: const Color(0xFF111216),
      surfaceContainerLowest: const Color(0xFF0C0D10),
      surfaceContainerLow: const Color(0xFF191B21),
      surfaceContainer: const Color(0xFF22252C),
      surfaceContainerHigh: const Color(0xFF2B2E36),
      surfaceContainerHighest: const Color(0xFF353943),
      onSurface: const Color(0xFFF4F5F7),
      onSurfaceVariant: const Color(0xFFBFC2CB),
      outline: const Color(0xFF8B909D),
      outlineVariant: const Color(0xFF3D414C),
    ),
  );

  static ThemeData _base(ColorScheme scheme) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final text = base.textTheme;
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodySmall: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: rounded,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelType: NavigationRailLabelType.all,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: rounded,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.brightness == Brightness.dark
              ? _violet
              : null,
          foregroundColor: scheme.brightness == Brightness.dark
              ? Colors.white
              : null,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: rounded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: scheme.outline),
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: rounded,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: rounded,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
