/// Application Theme definition and configuration.
/// Pure Dart model representing theme styling across web, desktop, and mobile.
library app_theme;

import 'tokens.dart';

enum AppThemeMode { light, dark, system }

class AppColorScheme {
  final int primary;
  final int secondary;
  final int background;
  final int surface;
  final int surfaceRaised;
  final int border;
  final int textPrimary;
  final int textSecondary;
  final int textMuted;
  final int success;
  final int warning;
  final int danger;
  final int info;

  const AppColorScheme({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  static const AppColorScheme dark = AppColorScheme(
    primary: AppColors.primaryLightValue,
    secondary: AppColors.secondaryLightValue,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceRaised: AppColors.darkSurfaceRaised,
    border: AppColors.darkBorder,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    info: AppColors.info,
  );

  static const AppColorScheme light = AppColorScheme(
    primary: AppColors.primaryValue,
    secondary: AppColors.secondaryValue,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceRaised: AppColors.lightSurfaceRaised,
    border: AppColors.lightBorder,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    info: AppColors.info,
  );
}

class AppTheme {
  final AppColorScheme colors;
  final bool isDark;

  const AppTheme({
    required this.colors,
    required this.isDark,
  });

  static const AppTheme dark = AppTheme(
    colors: AppColorScheme.dark,
    isDark: true,
  );

  static const AppTheme light = AppTheme(
    colors: AppColorScheme.light,
    isDark: false,
  );
}
