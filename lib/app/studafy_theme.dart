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
    error: studafyDanger,
    // Tonal buttons and chips: the palette's lightest blue, deep blue text.
    secondaryContainer: studafyWash,
    onSecondaryContainer: studafyNavy,
  ),
  splashFactory: InkSparkle.splashFactory,
  // The bar is the page's own colour, so header and content read as one
  // screen rather than two bands.
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
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: studafyHairline),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: studafyHairline,
    thickness: 1,
    space: 24,
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: studafyNavy,
    textColor: studafyInk,
    subtitleTextStyle: TextStyle(color: studafyMuted, fontSize: 13),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: studafyWash,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: studafyNavy, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: studafyDanger, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: studafyDanger, width: 1.6),
    ),
    labelStyle: const TextStyle(color: studafyMuted),
    hintStyle: const TextStyle(color: studafyMuted),
  ),
  filledButtonTheme: FilledButtonThemeData(
    // Colours come from the scheme, so a tonal button stays light.
    style: FilledButton.styleFrom(
      disabledBackgroundColor: studafyHairline,
      disabledForegroundColor: studafyMuted,
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: studafyNavy,
      minimumSize: const Size(48, 50),
      side: const BorderSide(color: studafyHairline, width: 1.2),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: studafyNavy,
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: studafyInk,
      shape: const CircleBorder(),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    selectedColor: studafyWash,
    checkmarkColor: studafyNavy,
    side: const BorderSide(color: studafyHairline),
    shape: const StadiumBorder(),
    labelStyle: const TextStyle(color: studafyInk, fontWeight: FontWeight.w600),
    secondaryLabelStyle: const TextStyle(
      color: studafyNavy,
      fontWeight: FontWeight.w700,
    ),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: SegmentedButton.styleFrom(
      selectedBackgroundColor: studafyWash,
      selectedForegroundColor: studafyNavy,
      side: const BorderSide(color: studafyHairline),
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    dragHandleColor: studafyHairline,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: studafyInk,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: studafyNavy,
    foregroundColor: Colors.white,
    elevation: 3,
    shape: StadiumBorder(),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: studafyNavy,
    linearTrackColor: studafyWash,
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: studafyNavy,
    unselectedLabelColor: studafyMuted,
    dividerColor: Colors.transparent,
    indicatorSize: TabBarIndicatorSize.label,
  ),
);
