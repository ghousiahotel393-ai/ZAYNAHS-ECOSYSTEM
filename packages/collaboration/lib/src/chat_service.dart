/// Chat Service and Offline Message Outbox.
/// Enforces Section 01: Offline message queuing and delivery receipts.
library chat_service;

import 'dart:async';
import 'chat_message.dart';

class ChatService {
  final String localDeviceId;
  final String localUserId;
  final String localUserName;

  final Map<String, List<ChatMessage>> _conversations = {};
  final List<ChatMessage> _offlineOutbox = [];

  final StreamController<ChatMessage> _messageStreamController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<MessageReceipt> _receiptStreamController =
      StreamController<MessageReceipt>.broadcast();

  ChatService({
    required this.localDeviceId,
    required this.localUserId,
    required this.localUserName,
  });

  Stream<ChatMessage> get onMessage => _messageStreamController.stream;
  Stream<MessageReceipt> get onReceipt => _receiptStreamController.stream;

  List<ChatMessage> get offlineOutbox => List.unmodifiable(_offlineOutbox);

  /// Creates and enqueues a new outgoing message.
  ChatMessage createMessage({
    required String conversationId,
    required String content,
    String? attachmentFileId,
  }) {
    final msg = ChatMessage(
      conversationId: conversationId,
      senderDeviceId: localDeviceId,
      senderUserId: localUserId,
      senderName: localUserName,
      content: content,
      attachmentFileId: attachmentFileId,
      status: MessageDeliveryStatus.pending,
    );

    _conversations.putIfAbsent(conversationId, () => []).add(msg);
    _offlineOutbox.add(msg);
    return msg;
  }

  /// Ingests an inbound chat message from a peer device.
  void receiveInboundMessage(ChatMessage message) {
    _conversations.putIfAbsent(message.conversationId, () => []).add(message);
    _messageStreamController.add(message);
  }

  /// Updates status based on an incoming delivery or read receipt.
  bool applyReceipt(MessageReceipt receipt) {
    final messages = _conversations[receipt.conversationId];
    if (messages == null) return false;

    for (final msg in messages) {
      if (msg.id == receipt.messageId) {
        msg.status = receipt.status;
        if (receipt.status == MessageDeliveryStatus.delivered ||
            receipt.status == MessageDeliveryStatus.read) {
          _offlineOutbox.removeWhere((m) => m.id == receipt.messageId);
        }
        _receiptStreamController.add(receipt);
        return true;
      }
    }
    return false;
  }

  /// Retrieves messages for a specific conversation.
  List<ChatMessage> getMessages(String conversationId) {
    return List.unmodifiable(_conversations[conversationId] ?? []);
  }

  void dispose() {
    _messageStreamController.close();
    _receiptStreamController.close();
  }
}
