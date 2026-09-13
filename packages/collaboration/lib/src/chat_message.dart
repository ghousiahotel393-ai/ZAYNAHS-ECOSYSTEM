/// Chat Message and Delivery Receipt Models.
/// Enforces Section 01: 1:1 and group conversations with PENDING -> SENT -> DELIVERED -> READ receipts.
library chat_message;

import 'dart:convert';
import 'package:core/core.dart';

enum MessageDeliveryStatus {
  pending,
  sent,
  delivered,
  read;

  static MessageDeliveryStatus fromString(String val) {
    return MessageDeliveryStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => MessageDeliveryStatus.pending,
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderDeviceId;
  final String senderUserId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  MessageDeliveryStatus status;
  final String? attachmentFileId;

  ChatMessage({
    String? id,
    required this.conversationId,
    required this.senderDeviceId,
    required this.senderUserId,
    required this.senderName,
    required this.content,
    DateTime? timestamp,
    this.status = MessageDeliveryStatus.pending,
    this.attachmentFileId,
  })  : id = id ?? 'msg_${EntityId.generateUuidV4()}',
        timestamp = timestamp ?? DateTime.now().toUtc();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_device_id': senderDeviceId,
      'sender_user_id': senderUserId,
      'sender_name': senderName,
      'content': content,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'status': status.name,
      'attachment_file_id': attachmentFileId,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderDeviceId: map['sender_device_id'] as String,
      senderUserId: map['sender_user_id'] as String,
      senderName: map['sender_name'] as String? ?? 'User',
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: MessageDeliveryStatus.fromString(map['status'] as String? ?? 'pending'),
      attachmentFileId: map['attachment_file_id'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ChatMessage.fromJson(String jsonStr) =>
      ChatMessage.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}

class MessageReceipt {
  final String messageId;
  final String conversationId;
  final String recipientDeviceId;
  final MessageDeliveryStatus status;
  final DateTime timestamp;

  const MessageReceipt({
    required this.messageId,
    required this.conversationId,
    required this.recipientDeviceId,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'conversation_id': conversationId,
      'recipient_device_id': recipientDeviceId,
      'status': status.name,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory MessageReceipt.fromMap(Map<String, dynamic> map) {
    return MessageReceipt(
      messageId: map['message_id'] as String,
      conversationId: map['conversation_id'] as String,
      recipientDeviceId: map['recipient_device_id'] as String,
      status: MessageDeliveryStatus.fromString(map['status'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MessageReceipt.fromJson(String jsonStr) =>
      MessageReceipt.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}
