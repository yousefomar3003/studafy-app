import 'package:flutter/material.dart';

import '../core/studafy_design.dart';

ThemeData studafyTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: studafyCanvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: studafyNavy,
    primary: studafyNavy,
    secondary: studafyCyan,
    surface: Colors.white,
  ),
  splashFactory: InkSparkle.splashFactory,
  appBarTheme: const AppBarTheme(
    backgroundColor: studafyCanvas,
    foregroundColor: studafyInk,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleSpacing: 24,
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -.7,
      color: studafyInk,
    ),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.4,
      color: studafyInk,
    ),
    headlineMedium: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      color: studafyInk,
    ),
    headlineSmall: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: -.8,
      color: studafyInk,
    ),
    titleLarge: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      letterSpacing: -.5,
      color: studafyInk,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: studafyInk,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: studafyInk),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: studafyInk),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: studafyMuted),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    margin: const EdgeInsets.symmetric(vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xFFE8ECF2)),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFFE8ECF2),
    thickness: 1,
    space: 24,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF2F4F8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: studafyNavy, width: 2),
    ),
    labelStyle: const TextStyle(color: studafyMuted),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 52),
      side: const BorderSide(color: Color(0xFFDDE3EC)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFEEF0FF),
    selectedColor: const Color(0xFFDFE3FF),
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    labelStyle: const TextStyle(
      color: studafyNavy,
      fontWeight: FontWeight.w600,
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: studafyInk,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: studafyNavy,
    foregroundColor: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: studafyNavy,
    unselectedLabelColor: studafyMuted,
    dividerColor: Colors.transparent,
    indicatorSize: TabBarIndicatorSize.label,
  ),
);
