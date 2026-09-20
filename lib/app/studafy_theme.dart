import 'package:flutter/material.dart';

import '../core/studafy_design.dart';

/// The app's Material theme, lifted out of `main.dart` so the entry point
/// stays about startup, configuration and routing (MOB-070).
///
/// Colours come from `core/studafy_design.dart`, which is the one palette.
ThemeData studafyTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: studafyCanvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: studafyNavy,
    primary: studafyNavy,
    secondary: studafyCyan,
    tertiary: const Color(0xFFFF6B6B),
    surface: Colors.white,
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: studafyInk),
    titleLarge: TextStyle(fontWeight: FontWeight.w800, color: studafyInk),
    titleMedium: TextStyle(fontWeight: FontWeight.w700, color: studafyInk),
    bodyMedium: TextStyle(color: studafyInk, height: 1.35),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDCE0EE)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDCE0EE)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: .1,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 50),
      side: const BorderSide(color: Color(0xFFD8DCEC)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: studafyCyan.withValues(alpha: .08),
    selectedColor: const Color(0xFF7737EE).withValues(alpha: .15),
    side: BorderSide(color: studafyCyan.withValues(alpha: .16)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    labelStyle: const TextStyle(color: studafyInk, fontWeight: FontWeight.w700),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFFFF6B6B),
    foregroundColor: Colors.white,
  ),
);
