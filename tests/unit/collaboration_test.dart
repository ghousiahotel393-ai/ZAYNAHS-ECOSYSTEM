import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:collaboration/collaboration.dart';

Future<void> main() async {
  int passed = 0;
  int failed = 0;

  void test(String name, void Function() body) {
    try {
      body();
      passed++;
      // ignore: avoid_print
      print('  ✓ $name');
    } catch (e, st) {
      failed++;
      // ignore: avoid_print
      print('  ✗ $name: $e\n$st');
    }
  }

  void expect(dynamic actual, dynamic expected) {
    if (actual != expected) {
      throw AssertionError('Expected: $expected, Actual: $actual');
    }
  }

  void assertTrue(bool condition, [String? message]) {
    if (!condition) {
      throw AssertionError(message ?? 'Expected condition to be true');
    }
  }

  // ignore: avoid_print
  print('\n=== Running Collaboration & Golden Test 104 Tests ===');

  // 1. Chat Message and Receipt Lifecycle
  test('ChatService manages conversation outbox and delivery receipts', () {
    final chat = ChatService(
      localDeviceId: 'dev_pos_01',
      localUserId: 'usr_cashier',
      localUserName: 'Cashier Alice',
    );

    final msg = chat.createMessage(
      conversationId: 'conv_team_chat',
      content: 'Price check on Espresso Beans',
    );

    expect(msg.status, MessageDeliveryStatus.pending);
    expect(chat.offlineOutbox.length, 1);
    expect(chat.getMessages('conv_team_chat').length, 1);

    // Peer receives message and sends DELIVERED receipt
    final deliveredReceipt = MessageReceipt(
      messageId: msg.id,
      conversationId: 'conv_team_chat',
      recipientDeviceId: 'dev_pos_02',
      status: MessageDeliveryStatus.delivered,
      timestamp: DateTime.now().toUtc(),
    );

    final applied1 = chat.applyReceipt(deliveredReceipt);
    assertTrue(applied1);
    expect(msg.status, MessageDeliveryStatus.delivered);
    expect(chat.offlineOutbox.length, 0); // Removed from offline outbox upon delivery

    // Peer reads message -> sends READ receipt
    final readReceipt = MessageReceipt(
      messageId: msg.id,
      conversationId: 'conv_team_chat',
      recipientDeviceId: 'dev_pos_02',
      status: MessageDeliveryStatus.read,
      timestamp: DateTime.now().toUtc(),
    );

    final applied2 = chat.applyReceipt(readReceipt);
    assertTrue(applied2);
    expect(msg.status, MessageDeliveryStatus.read);

    chat.dispose();
  });

  // 2. GOLDEN TEST #104: Resumable Chunked File Transfer Protocol
  test('Golden Test 104: 6-step resumable chunked file transfer cuts at 50% and resumes with SHA-256 match', () {
    // Generate synthetic 300KB binary payload (5 chunks: 64K, 64K, 64K, 64K, 44K)
    final totalSize = 300 * 1024;
    final fileBytes = Uint8List(totalSize);
    for (int i = 0; i < totalSize; i++) {
      fileBytes[i] = (i * 13) % 256;
    }
    final originalHash = sha256.convert(fileBytes).toString();

    final meta = TransferMeta(
      transferId: 'xfer_golden_104',
      fileName: 'catalog_backup_300k.dat',
      fileSizeBytes: totalSize,
      sha256Hash: originalHash,
      chunkSize: 64 * 1024,
    );

    final sender = FileTransferSender(meta: meta, fileBytes: fileBytes);
    final receiver = FileTransferReceiver(meta);

    expect(receiver.step, TransferStep.meta);
    expect(receiver.progressPercentage, 0.0);

    // Step 1: Transfer first 2 chunks (128 KB transferred / ~42.6% progress)
    final initialChunks = sender.getChunksFromOffset(0).take(2).toList();
    expect(initialChunks.length, 2);

    for (final chunk in initialChunks) {
      final ack = receiver.receiveChunk(chunk);
      expect(ack.transferId, 'xfer_golden_104');
    }

    expect(receiver.receivedBytes, 128 * 1024);

    // Step 2: Simulate Network Cut at ~50%
    receiver.markInterrupted();
    expect(receiver.step, TransferStep.interrupted);

    // Step 3: Reconnect & Resume Protocol
    final resumeOffset = receiver.getResumeOffset();
    expect(resumeOffset, 128 * 1024);

    // Sender resumes strictly from offset without retransmitting chunks 0 and 1
    final remainingChunks = sender.getChunksFromOffset(resumeOffset).toList();
    expect(remainingChunks.length, 3); // Chunks 2, 3, and 4
    expect(remainingChunks[0].chunkIndex, 2);
    expect(remainingChunks[0].offset, 128 * 1024);

    for (final chunk in remainingChunks) {
      receiver.receiveChunk(chunk);
    }

    expect(receiver.receivedBytes, totalSize);
    expect(receiver.progressPercentage, 100.0);

    // Step 4: Verify SHA-256 and Complete Transfer
    final verified = receiver.verifyAndComplete();
    assertTrue(verified, 'Golden Test 104: Assembled file SHA-256 hash must exactly match original');
    expect(receiver.step, TransferStep.complete);

    // Verify byte-for-byte equality
    final assembledBytes = receiver.getAssembledBytes();
    assertTrue(assembledBytes != null);
    expect(assembledBytes!.length, totalSize);
    for (int i = 0; i < totalSize; i++) {
      if (assembledBytes[i] != fileBytes[i]) {
        throw AssertionError('Byte mismatch at index $i after resumed transfer');
      }
    }
  });

  // 3. WebRTC Voice & Video Call Session Coordinator
  test('CallSessionCoordinator manages call states, muting, and duration', () {
    final coordinator = CallSessionCoordinator(localDeviceId: 'dev_terminal_01');

    // Start outgoing call
    final call = coordinator.startOutgoingCall(
      recipientDeviceId: 'dev_terminal_02',
      isVideo: true,
    );

    expect(call.state, CallState.ringing);
    expect(call.isVideo, true);
    expect(call.isAudioMuted, false);
    expect(call.isVideoMuted, false);

    // Remote peer accepts call
    coordinator.acceptCall();
    expect(call.state, CallState.connected);
    assertTrue(call.connectedAt != null);

    // Toggle audio and video mute
    coordinator.toggleAudioMute();
    expect(call.isAudioMuted, true);
    coordinator.toggleVideoMute();
    expect(call.isVideoMuted, true);

    // Toggle camera facing
    expect(call.isFrontCamera, true);
    coordinator.toggleCameraFacing();
    expect(call.isFrontCamera, false);

    // End call
    coordinator.endCall();
    expect(call.state, CallState.ended);
    assertTrue(call.endedAt != null);

    coordinator.dispose();
  });

  // 4. Privacy Sharing Safeguards (Explicit Consent & Auto-Expiring Location)
  test('PrivacySharingManager enforces explicit consent gates and auto-expiring location', () {
    final privacy = PrivacySharingManager();

    // Screen sharing without explicit user consent throws exception
    bool screenCaught = false;
    try {
      privacy.startScreenSharing(userExplicitlyConsented: false);
    } on PrivacyConsentRequiredException {
      screenCaught = true;
    }
    assertTrue(screenCaught, 'Covert screen capture must be blocked');
    expect(privacy.isScreenSharing, false);

    // Screen sharing with explicit consent succeeds
    final screenStarted = privacy.startScreenSharing(userExplicitlyConsented: true);
    assertTrue(screenStarted);
    expect(privacy.isScreenSharing, true);
    privacy.stopScreenSharing();
    expect(privacy.isScreenSharing, false);

    // Camera sharing consent gate
    bool cameraCaught = false;
    try {
      privacy.startCameraSharing(userExplicitlyConsented: false);
    } on PrivacyConsentRequiredException {
      cameraCaught = true;
    }
    assertTrue(cameraCaught, 'Covert camera capture must be blocked');

    // Ephemeral location sharing with auto-expiration
    final locStarted = privacy.startEphemeralLocationSharing(
      duration: const Duration(milliseconds: 50),
      userExplicitlyConsented: true,
    );
    assertTrue(locStarted);
    expect(privacy.isLocationSharing, true);

    privacy.stopLocationSharing();
    expect(privacy.isLocationSharing, false);

    privacy.dispose();
  });

  // ignore: avoid_print
  print('\nCollaboration tests summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
