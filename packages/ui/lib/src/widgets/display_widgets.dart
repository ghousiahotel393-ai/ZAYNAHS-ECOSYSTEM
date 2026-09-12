/// Display and Data UI Components for Zaynahs Ecosystem.
/// Includes AppMoneyDisplay, AppDataTable, AppBadge, AppAvatar, AppMetricTile, AppPaginationControl, and AppAuditTrailItem.
library display_widgets;

import 'package:core/core.dart';

/// 12. AppMoneyDisplay Component model.
class AppMoneyDisplayConfig {
  final Money amount;
  final bool highlightNegative;
  final bool includeSymbol;
  final double fontSize;

  const AppMoneyDisplayConfig({
    required this.amount,
    this.highlightNegative = true,
    this.includeSymbol = true,
    this.fontSize = 16.0,
  });

  String get formattedText => amount.format(includeSymbol: includeSymbol);
}

/// 13. AppDataTable Column & Table Configuration models.
class TableColumn<T> {
  final String title;
  final String Function(T item) cellValue;
  final bool isSortable;
  final double? width;

  const TableColumn({
    required this.title,
    required this.cellValue,
    this.isSortable = false,
    this.width,
  });
}

class AppDataTableConfig<T> {
  final List<TableColumn<T>> columns;
  final List<T> rows;
  final bool isLoading;
  final String? emptyMessage;
  final void Function(T item)? onRowClick;

  const AppDataTableConfig({
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.emptyMessage = 'No data available',
    this.onRowClick,
  });
}

/// 14. AppBadge Component model.
enum BadgeVariant { success, warning, danger, info, neutral }

class AppBadgeConfig {
  final String label;
  final BadgeVariant variant;
  final bool isPill;

  const AppBadgeConfig({
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.isPill = true,
  });

  /// Factory constructor for device trust states (Rule 66-68).
  factory AppBadgeConfig.forDeviceTrust(String status) {
    switch (status.toUpperCase()) {
      case 'TRUSTED':
        return const AppBadgeConfig(label: 'TRUSTED', variant: BadgeVariant.success);
      case 'PENDING':
        return const AppBadgeConfig(label: 'PENDING', variant: BadgeVariant.warning);
      case 'REVOKED':
        return const AppBadgeConfig(label: 'REVOKED', variant: BadgeVariant.danger);
      case 'BLOCKED':
        return const AppBadgeConfig(label: 'BLOCKED', variant: BadgeVariant.danger);
      default:
        return AppBadgeConfig(label: status, variant: BadgeVariant.neutral);
    }
  }
}

/// 15. AppAvatar Component model.
class AppAvatarConfig {
  final String name;
  final String? imageUrl;
  final double size;
  final String? statusDot; // e.g., 'online', 'offline', 'busy'

  const AppAvatarConfig({
    required this.name,
    this.imageUrl,
    this.size = 40.0,
    this.statusDot,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].isNotEmpty ? 1 : 0).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

/// 16. AppMetricTile Component model (Dashboard KPI summary).
class AppMetricTileConfig {
  final String title;
  final String value;
  final String? subtitle;
  final String? trendPercentage;
  final bool isTrendPositive;
  final String? iconName;

  const AppMetricTileConfig({
    required this.title,
    required this.value,
    this.subtitle,
    this.trendPercentage,
    this.isTrendPositive = true,
    this.iconName,
  });
}

/// 17. AppPaginationControl Component model.
class AppPaginationControlConfig {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final void Function(int page)? onPageChanged;
  final void Function(int size)? onPageSizeChanged;

  const AppPaginationControlConfig({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    this.pageSize = 20,
    this.onPageChanged,
    this.onPageSizeChanged,
  });

  bool get hasPrevious => currentPage > 1;
  bool get hasNext => currentPage < totalPages;
}

/// 18. AppAuditTrailItem Component model.
class AppAuditTrailItemConfig {
  final String action;
  final String actorName;
  final DateTime timestamp;
  final String details;
  final String? entityId;

  const AppAuditTrailItemConfig({
    required this.action,
    required this.actorName,
    required this.timestamp,
    required this.details,
    this.entityId,
  });
}
