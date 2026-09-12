/// System and Hardware-Integrated UI Components for Zaynahs Ecosystem.
/// Includes AppBarcodeScannerWidget, AppReceiptPreview, AppVideoPlayerPlaceholder,
/// AppNetworkStatusBanner, and the mandatory AppRedRecordingBanner (Rule 54).
library system_widgets;

import 'package:core/core.dart';

/// 23. AppBarcodeScannerWidget Component model.
class AppBarcodeScannerConfig {
  final bool isScanning;
  final String promptText;
  final void Function(String barcode)? onBarcodeDetected;
  final void Function()? onToggleFlashlight;
  final void Function()? onSwitchCamera;

  const AppBarcodeScannerConfig({
    this.isScanning = true,
    this.promptText = 'Align barcode or QR within frame',
    this.onBarcodeDetected,
    this.onToggleFlashlight,
    this.onSwitchCamera,
  });
}

/// 24. AppReceiptPreview Component model (58mm or 80mm ESC/POS layout preview).
class ReceiptLineItem {
  final String itemName;
  final int quantity;
  final Money unitPrice;
  final Money totalPrice;

  const ReceiptLineItem({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}

class AppReceiptPreviewConfig {
  final String businessName;
  final String receiptNumber;
  final DateTime date;
  final List<ReceiptLineItem> items;
  final Money subtotal;
  final Money tax;
  final Money discount;
  final Money grandTotal;
  final String paymentMethod;
  final PaperSize paperSize;
  final String cashierName;

  const AppReceiptPreviewConfig({
    required this.businessName,
    required this.receiptNumber,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.grandTotal,
    required this.paymentMethod,
    this.paperSize = PaperSize.mm80,
    required this.cashierName,
  });
}

/// 25. AppVideoPlayerPlaceholder Component model (CCTV stream playback).
class AppVideoPlayerConfig {
  final String cameraName;
  final String? streamUrl;
  final bool isLive;
  final DateTime? recordedTimestamp;
  final bool isMuted;
  final void Function()? onTogglePlay;
  final void Function()? onToggleMute;
  final void Function()? onFullscreen;

  const AppVideoPlayerConfig({
    required this.cameraName,
    this.streamUrl,
    this.isLive = true,
    this.recordedTimestamp,
    this.isMuted = true,
    this.onTogglePlay,
    this.onToggleMute,
    this.onFullscreen,
  });
}

/// 26. AppNetworkStatusBanner Component model.
enum NetworkBannerStatus { online, lanOnly, offline, syncing }

class AppNetworkStatusBannerConfig {
  final NetworkBannerStatus status;
  final int pendingSyncEventCount;
  final void Function()? onRetrySync;

  const AppNetworkStatusBannerConfig({
    required this.status,
    this.pendingSyncEventCount = 0,
    this.onRetrySync,
  });

  String get bannerText {
    switch (status) {
      case NetworkBannerStatus.online:
        return 'Online • All peer events synchronized';
      case NetworkBannerStatus.lanOnly:
        return 'LAN Mode • Syncing directly with local peers';
      case NetworkBannerStatus.offline:
        return 'Offline Mode • $pendingSyncEventCount events saved locally to outbox';
      case NetworkBannerStatus.syncing:
        return 'Synchronizing with peers ($pendingSyncEventCount remaining)...';
    }
  }
}

/// 27. AppRedRecordingBanner Component model.
/// Strictly mandatory under Rule 54: Whenever camera, microphone, or screen sharing
/// is actively capturing, a persistent, un-dismissible red indicator must be visible.
class AppRedRecordingBannerConfig {
  final bool isVisible;
  final String activeMediaTypes; // e.g. "Screen Sharing", "CCTV Camera", "Microphone"
  final DateTime startedAt;
  final void Function() onStopRecording;

  const AppRedRecordingBannerConfig({
    required this.isVisible,
    required this.activeMediaTypes,
    required this.startedAt,
    required this.onStopRecording,
  });

  String get message =>
      'RECORDING ACTIVE: $activeMediaTypes is recording. Click to stop.';
}
