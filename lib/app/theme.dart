import 'package:flutter/material.dart';

abstract final class VantaColors {
  static const ink = Color(0xFF050505);
  static const surface = Color(0xFF0B0B0F);
  static const surfaceElevated = Color(0xFF111113);
  static const surfaceHigh = Color(0xFF18181B);
  static const border = Color(0xFF27272A);
  static const muted = Color(0xFF71717A);
  static const text = Color(0xFFF8FAFC);
  static const violet = Color(0xFF7C3AED);
}

ThemeData buildVantaDarkTheme() {
  const seed = VantaColors.violet;
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
    surface: VantaColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: VantaColors.ink,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: VantaColors.text,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
    ),
    dividerColor: VantaColors.border,
    cardTheme: CardThemeData(
      color: VantaColors.surfaceElevated,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: VantaColors.border, width: 0.6),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      iconColor: VantaColors.text,
      textColor: VantaColors.text,
      subtitleTextStyle: TextStyle(color: VantaColors.muted, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: VantaColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: VantaColors.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VantaColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: VantaColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: VantaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: seed, width: 1.2),
      ),
      hintStyle: const TextStyle(color: VantaColors.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: VantaColors.surface,
      indicatorColor: seed.withValues(alpha: 0.22),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      indicator: BoxDecoration(
        color: seed.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      labelColor: VantaColors.text,
      unselectedLabelColor: VantaColors.muted,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 5,
      activeTrackColor: seed,
      inactiveTrackColor: VantaColors.border,
      thumbColor: VantaColors.text,
      overlayColor: seed.withValues(alpha: 0.14),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: VantaColors.surfaceHigh,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: VantaColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: VantaColors.surface,
      modalBarrierColor: Color(0xB3000000),
      showDragHandle: true,
      dragHandleColor: VantaColors.border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: VantaColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
  );
}
