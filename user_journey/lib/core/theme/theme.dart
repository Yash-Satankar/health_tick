import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.buttonFill,
      onPrimary: AppColors.buttonText,
      secondary: AppColors.healthAccent,
      error: AppColors.error,
    ),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    ),
    textTheme: base.textTheme.apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.surface),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.textPrimary),
  );
}
