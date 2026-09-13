/// Design tokens for Zaynahs Ecosystem Design System.
/// Defines consistent palettes, typography, spacing, and radius across all platforms.
library tokens;

class AppColors {
  // Brand Accents
  static const int primaryValue = 0xFF0D9488; // Emerald Teal
  static const int primaryLightValue = 0xFF14B8A6;
  static const int primaryDarkValue = 0xFF0F766E;

  static const int secondaryValue = 0xFF6366F1; // Indigo
  static const int secondaryLightValue = 0xFF818CF8;

  // Semantic Status Colors
  static const int success = 0xFF10B981; // Green
  static const int warning = 0xFFF59E0B; // Amber
  static const int danger = 0xFFEF4444;  // Red
  static const int info = 0xFF3B82F6;    // Blue

  // Dark Theme Palette
  static const int darkBackground = 0xFF0B0F19;
  static const int darkSurface = 0xFF111827;
  static const int darkSurfaceRaised = 0xFF1F2937;
  static const int darkBorder = 0xFF374151;
  static const int darkTextPrimary = 0xFFF9FAFB;
  static const int darkTextSecondary = 0xFF9CA3AF;
  static const int darkTextMuted = 0xFF6B7280;

  // Light Theme Palette
  static const int lightBackground = 0xFFF8FAFC;
  static const int lightSurface = 0xFFFFFFFF;
  static const int lightSurfaceRaised = 0xFFF1F5F9;
  static const int lightBorder = 0xFFE2E8F0;
  static const int lightTextPrimary = 0xFF0F172A;
  static const int lightTextSecondary = 0xFF475569;
  static const int lightTextMuted = 0xFF94A3B8;

  // Recording Banner (Mandatory Rule 54)
  static const int recordingRed = 0xFFDC2626;
}

class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

class AppRadius {
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 9999.0;
}

class AppBreakpoints {
  static const double mobileMax = 600.0;
  static const double tabletMax = 1024.0;
}

class AppTouchTargets {
  static const double minTargetSize = 48.0;
  static const double minIconSize = 24.0;
}

