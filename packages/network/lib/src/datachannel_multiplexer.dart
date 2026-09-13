/// WebRTC 4-Channel DataChannel Multiplexer.
/// Enforces Section 03: 4 dedicated channels for sync, file transfers, chat, and control.
library datachannel_multiplexer;

import 'dart:async';

enum P2PChannelType {
  sync('sync-channel', isReliable: true, isOrdered: true),
  file('file-channel', isReliable: true, isOrdered: true),
  chat('chat-channel', isReliable: true, isOrdered: false),
  control('control-channel', isReliable: false, isOrdered: false);

  final String channelLabel;
  final bool isReliable;
  final bool isOrdered;

  const P2PChannelType(
    this.channelLabel, {
    required this.isReliable,
    required this.isOrdered,
  });

  static P2PChannelType fromLabel(String label) {
    return P2PChannelType.values.firstWhere(
      (c) => c.channelLabel == label,
      orElse: () => P2PChannelType.control,
    );
  }
}

class P2PMessage {
  final P2PChannelType channel;
  final String senderDeviceId;
  final List<int> payload;
  final DateTime receivedAt;

  const P2PMessage({
    required this.channel,
    required this.senderDeviceId,
    required this.payload,
    required this.receivedAt,
  });
}

class DataChannelMultiplexer {
  final Map<P2PChannelType, StreamController<P2PMessage>> _channelControllers = {
    P2PChannelType.sync: StreamController<P2PMessage>.broadcast(),
    P2PChannelType.file: StreamController<P2PMessage>.broadcast(),
    P2PChannelType.chat: StreamController<P2PMessage>.broadcast(),
    P2PChannelType.control: StreamController<P2PMessage>.broadcast(),
  };

  Stream<P2PMessage> get onSyncMessage =>
      _channelControllers[P2PChannelType.sync]!.stream;

  Stream<P2PMessage> get onFileMessage =>
      _channelControllers[P2PChannelType.file]!.stream;

  Stream<P2PMessage> get onChatMessage =>
      _channelControllers[P2PChannelType.chat]!.stream;

  Stream<P2PMessage> get onControlMessage =>
      _channelControllers[P2PChannelType.control]!.stream;

  /// Routes incoming bytes received on a specific data channel to its dedicated stream.
  void routeIncoming({
    required P2PChannelType channel,
    required String senderDeviceId,
    required List<int> payload,
    DateTime? timestamp,
  }) {
    final message = P2PMessage(
      channel: channel,
      senderDeviceId: senderDeviceId,
      payload: payload,
      receivedAt: timestamp ?? DateTime.now().toUtc(),
    );

    _channelControllers[channel]?.add(message);
  }

  void dispose() {
    for (final controller in _channelControllers.values) {
      controller.close();
    }
  }
}
