/// Feedback and State UI Components for Zaynahs Ecosystem.
/// Includes AppDialog, AppLoadingIndicator, AppEmptyState, and AppErrorState.
library feedback_widgets;

enum DialogType { alert, confirmation, destructive }

/// 19. AppDialog Component model.
class AppDialogConfig {
  final String title;
  final String message;
  final DialogType type;
  final String confirmLabel;
  final String? cancelLabel;
  final void Function()? onConfirm;
  final void Function()? onCancel;

  const AppDialogConfig({
    required this.title,
    required this.message,
    this.type = DialogType.confirmation,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.onConfirm,
    this.onCancel,
  });
}

/// 20. AppLoadingIndicator Component model.
class AppLoadingIndicatorConfig {
  final String? message;
  final double size;
  final bool isOverlay;

  const AppLoadingIndicatorConfig({
    this.message,
    this.size = 32.0,
    this.isOverlay = false,
  });
}

/// 21. AppEmptyState Component model.
class AppEmptyStateConfig {
  final String title;
  final String description;
  final String? iconName;
  final String? actionLabel;
  final void Function()? onActionPressed;

  const AppEmptyStateConfig({
    required this.title,
    required this.description,
    this.iconName,
    this.actionLabel,
    this.onActionPressed,
  });
}

/// 22. AppErrorState Component model.
class AppErrorStateConfig {
  final String title;
  final String errorMessage;
  final String? technicalDetails;
  final String retryLabel;
  final void Function()? onRetry;
  final void Function()? onCopyTechnicalDetails;

  const AppErrorStateConfig({
    this.title = 'Something went wrong',
    required this.errorMessage,
    this.technicalDetails,
    this.retryLabel = 'Retry',
    this.onRetry,
    this.onCopyTechnicalDetails,
  });
}
