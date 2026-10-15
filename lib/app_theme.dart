import 'package:flutter/material.dart';

enum CurioThemePreference {
  system,
  dark,
  light,
  oled;

  String get label => switch (this) {
    CurioThemePreference.system => 'System default',
    CurioThemePreference.dark => 'Dark',
    CurioThemePreference.light => 'Light',
    CurioThemePreference.oled => 'OLED black',
  };

  String get description => switch (this) {
    CurioThemePreference.system => 'Follows your device appearance.',
    CurioThemePreference.dark => 'Curio dark with mint-green accents.',
    CurioThemePreference.light =>
      'A bright background with dark, readable text.',
    CurioThemePreference.oled =>
      'Pure black background to save power on OLED screens.',
  };
}

ThemeMode themeModeFor(CurioThemePreference preference) => switch (preference) {
  CurioThemePreference.system => ThemeMode.system,
  CurioThemePreference.light => ThemeMode.light,
  CurioThemePreference.dark || CurioThemePreference.oled => ThemeMode.dark,
};

ThemeData curioTheme(Brightness brightness, {bool oled = false}) {
  final isDark = brightness == Brightness.dark;
  final background = oled
      ? const Color(0xFF000000)
      : isDark
      ? const Color(0xFF151A18)
      : const Color(0xFFF8F9F6);
  final surface = oled
      ? const Color(0xFF000000)
      : isDark
      ? const Color(0xFF1D2421)
      : Colors.white;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: isDark ? const Color(0xFF86D7BC) : const Color(0xFF286B59),
        brightness: brightness,
      ).copyWith(
        primary: isDark ? const Color(0xFF86D7BC) : const Color(0xFF286B59),
        onPrimary: isDark ? const Color(0xFF06251C) : Colors.white,
        secondary: isDark ? const Color(0xFF86D7BC) : const Color(0xFF286B59),
        onSecondary: isDark ? const Color(0xFF06251C) : Colors.white,
        surface: surface,
        onSurface: isDark ? const Color(0xFFE2E8E4) : const Color(0xFF18211D),
        surfaceContainerHighest: oled
            ? const Color(0xFF1A1A1A)
            : isDark
            ? const Color(0xFF29312D)
            : const Color(0xFFE9EFEB),
        outline: isDark ? const Color(0xFF78857F) : const Color(0xFF64736C),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.7),
      thickness: 1,
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: scheme.outline),
        foregroundColor: scheme.primary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: scheme.primary)),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: scheme.onSurfaceVariant),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
  );
}
