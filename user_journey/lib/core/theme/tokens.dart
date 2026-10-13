import 'package:flutter/material.dart';

/// Theme tokens (SPEC §9.1, dark only, sampled from the reference video).
/// These are layout/theme constants — the only UI values allowed in code besides FallbackMessages.
class AppColors {
  const AppColors._();

  static const background = Color(0xFF000000);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFBDBDBD);
  static const pathCompleted = Color(0xFFBDBDBD);
  static const pathLocked = Color(0xFF2A2A2A);
  static const surface = Color(0xFF1E1E1E);
  static const completedCheck = Color(0xFF3DBE8B);
  static const buttonFill = Color(0xFFF5F5F5);
  static const buttonText = Color(0xFF111111);
  static const buttonDisabled = Color(0xFF3A3A3A);
  static const highlight = Color(0xFFD9F2C4);
  static const highlightText = Color(0xFF111111);
  static const healthAccent = Color(0xFF5DBB8A);
  static const border = Color(0xFF3A3A3A);
  static const borderSelected = Color(0xFFF5F5F5);
  static const error = Color(0xFFE57373);
  static const streak = Color(0xFFFF8A3D);
  static const scrim = Color(0xB3000000);
}

class AppSizes {
  const AppSizes._();

  static const double bodyFont = 16;
  static const double headingFont = 22;
  static const double ctaFont = 16;
  static const double gutter = 16;
  static const double radius = 12;
  static const double maxContentWidth = 480;
  static const double minHitTarget = 48;
}

class AppDurations {
  const AppDurations._();

  static const popover = Duration(milliseconds: 180);
  static const ensureVisible = Duration(milliseconds: 250);
  static const shake = Duration(milliseconds: 300);
  static const reloadFade = Duration(milliseconds: 200);
  static const progress = Duration(milliseconds: 250);
  static const pageCrossfade = Duration(milliseconds: 220);
  static const accordion = Duration(milliseconds: 200);
  static const medal = Duration(milliseconds: 400);
  static const searchDebounce = Duration(milliseconds: 300);
}

/// Parses a `#RRGGBB` colour from the API; falls back to [fallback] if malformed.
Color parseHexColor(String? hex, {Color fallback = AppColors.textPrimary}) {
  if (hex == null) return fallback;
  final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex);
  if (match == null) return fallback;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}
