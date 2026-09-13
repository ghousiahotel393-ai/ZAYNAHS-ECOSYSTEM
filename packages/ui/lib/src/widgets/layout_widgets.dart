/// Layout UI Components for Zaynahs Ecosystem.
/// Includes AppScaffold, AppCard, AppDivider, AppBreadcrumb, and AppTabs.
library layout_widgets;

import '../theme/tokens.dart';

/// Navigation item definition for AppScaffold.
class NavItem {
  final String id;
  final String label;
  final String iconName;
  final String routePath;
  final int? badgeCount;

  const NavItem({
    required this.id,
    required this.label,
    required this.iconName,
    required this.routePath,
    this.badgeCount,
  });
}

/// 1. AppScaffold Component model.
/// Responsive root container providing top bar, sidebar (desktop), rail (tablet), or bottom nav (mobile).
class AppScaffoldConfig {
  final String title;
  final List<NavItem> navItems;
  final int activeIndex;
  final bool isRecordingActive; // Triggers mandatory persistent red banner (Rule 54)
  final bool isOffline;        // Triggers offline indicator
  final void Function(int index)? onNavItemSelected;

  const AppScaffoldConfig({
    required this.title,
    required this.navItems,
    this.activeIndex = 0,
    this.isRecordingActive = false,
    this.isOffline = false,
    this.onNavItemSelected,
  });
}

/// 2. AppCard Component model.
/// Elevated card container with rounded corners, subtle border, and optional header/footer.
class AppCardConfig {
  final String? title;
  final String? subtitle;
  final double elevation;
  final double padding;
  final bool isClickable;
  final void Function()? onTap;

  const AppCardConfig({
    this.title,
    this.subtitle,
    this.elevation = 1.0,
    this.padding = AppSpacing.md,
    this.isClickable = false,
    this.onTap,
  });
}

/// 3. AppDivider Component model.
/// Clean hairline divider between list items or sections.
class AppDividerConfig {
  final double thickness;
  final double indent;
  final double endIndent;
  final int? customColor;

  const AppDividerConfig({
    this.thickness = 1.0,
    this.indent = 0.0,
    this.endIndent = 0.0,
    this.customColor,
  });
}

/// 4. AppBreadcrumb Item & Configuration model.
class BreadcrumbItem {
  final String label;
  final String? routePath;

  const BreadcrumbItem({required this.label, this.routePath});
}

class AppBreadcrumbConfig {
  final List<BreadcrumbItem> items;
  final void Function(BreadcrumbItem item)? onItemClicked;

  const AppBreadcrumbConfig({
    required this.items,
    this.onItemClicked,
  });
}

/// 5. AppTabs Component model.
class TabItem {
  final String id;
  final String label;
  final int? badgeCount;

  const TabItem({required this.id, required this.label, this.badgeCount});
}

class AppTabsConfig {
  final List<TabItem> tabs;
  final int selectedIndex;
  final void Function(int index)? onTabSelected;

  const AppTabsConfig({
    required this.tabs,
    this.selectedIndex = 0,
    this.onTabSelected,
  });
}
