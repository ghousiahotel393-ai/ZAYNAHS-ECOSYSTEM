/// Responsive Layout and Breakpoint System for Zaynahs Ecosystem.
/// Supports phones, tablets, foldable devices, desktop screens, and POS terminals.
library responsive;

import 'tokens.dart';

enum ScreenType { mobile, tablet, desktop }

class ResponsiveLayoutHelper {
  /// Returns ScreenType based on window/screen width in logical pixels.
  static ScreenType getScreenType(double width) {
    if (width < AppBreakpoints.mobileMax) {
      return ScreenType.mobile;
    } else if (width <= AppBreakpoints.tabletMax) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }

  static bool isMobile(double width) => width < AppBreakpoints.mobileMax;
  static bool isTablet(double width) =>
      width >= AppBreakpoints.mobileMax && width <= AppBreakpoints.tabletMax;
  static bool isDesktop(double width) => width > AppBreakpoints.tabletMax;

  /// Returns optimal column count for POS grid items based on screen width.
  static int getGridColumnCount(double width) {
    if (width < 400) return 2;
    if (width < AppBreakpoints.mobileMax) return 3;
    if (width < 800) return 4;
    if (width <= AppBreakpoints.tabletMax) return 5;
    if (width < 1400) return 6;
    return 8;
  }

  /// Returns optimal sidebar width for desktop/tablet.
  static double getSidebarWidth(double screenWidth) {
    if (isMobile(screenWidth)) return 0.0;
    if (isTablet(screenWidth)) return 80.0; // Rail mode
    return 260.0; // Full sidebar mode
  }
}
