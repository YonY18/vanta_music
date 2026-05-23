import 'package:flutter/material.dart';

ThemeData buildVantaDarkTheme() {
  const seed = Color(0xFF8B5CF6);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
    surface: const Color(0xFF101014),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF07070A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF15151B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF101014),
      indicatorColor: seed.withValues(alpha: 0.22),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        color: seed.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
    ),
  );
}
