/// WebRTC Voice & Video Call Session Coordinator.
/// Enforces Section 03: Opus/VP8 call states, muting, camera toggle, and session duration.
library call_session_coordinator;

import 'dart:async';
import 'package:core/core.dart';

enum CallState {
  idle,
  ringing,
  connected,
  ended,
  missed,
  rejected;
}

class CallSession {
  final String callId;
  final String callerDeviceId;
  final String recipientDeviceId;
  final bool isVideo;
  CallState state;
  bool isAudioMuted;
  bool isVideoMuted;
  bool isFrontCamera;
  final DateTime startedAt;
  DateTime? connectedAt;
  DateTime? endedAt;

  CallSession({
    String? callId,
    required this.callerDeviceId,
    required this.recipientDeviceId,
    this.isVideo = false,
    this.state = CallState.ringing,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    this.isFrontCamera = true,
    DateTime? startedAt,
  })  : callId = callId ?? 'cal_${EntityId.generateUuidV4()}',
        startedAt = startedAt ?? DateTime.now().toUtc();

  Duration get duration {
    if (connectedAt == null) return Duration.zero;
    final end = endedAt ?? DateTime.now().toUtc();
    return end.difference(connectedAt!);
  }
}

class CallSessionCoordinator {
  final String localDeviceId;
  CallSession? _currentCall;

  final StreamController<CallSession> _callUpdateController =
      StreamController<CallSession>.broadcast();

  CallSessionCoordinator({required this.localDeviceId});

  Stream<CallSession> get onCallUpdate => _callUpdateController.stream;
  CallSession? get currentCall => _currentCall;

  /// Initiates an outgoing audio or video call.
  CallSession startOutgoingCall({
    required String recipientDeviceId,
    bool isVideo = false,
  }) {
    if (_currentCall != null &&
        _currentCall!.state != CallState.ended &&
        _currentCall!.state != CallState.rejected &&
        _currentCall!.state != CallState.missed) {
      throw StateError('Cannot initiate call while another call is active');
    }

    final call = CallSession(
      callerDeviceId: localDeviceId,
      recipientDeviceId: recipientDeviceId,
      isVideo: isVideo,
      state: CallState.ringing,
    );

    _currentCall = call;
    _callUpdateController.add(call);
    return call;
  }

  /// Ingests an incoming call from a remote peer.
  CallSession receiveIncomingCall({
    required String callerDeviceId,
    bool isVideo = false,
  }) {
    final call = CallSession(
      callerDeviceId: callerDeviceId,
      recipientDeviceId: localDeviceId,
      isVideo: isVideo,
      state: CallState.ringing,
    );

    _currentCall = call;
    _callUpdateController.add(call);
    return call;
  }

  /// Answers active ringing call.
  void acceptCall() {
    if (_currentCall == null || _currentCall!.state != CallState.ringing) return;

    _currentCall!.state = CallState.connected;
    _currentCall!.connectedAt = DateTime.now().toUtc();
    _callUpdateController.add(_currentCall!);
  }

  /// Rejects active ringing call.
  void rejectCall() {
    if (_currentCall == null || _currentCall!.state != CallState.ringing) return;

    _currentCall!.state = CallState.rejected;
    _currentCall!.endedAt = DateTime.now().toUtc();
    _callUpdateController.add(_currentCall!);
  }

  /// Terminates active call.
  void endCall() {
    if (_currentCall == null) return;

    _currentCall!.state = CallState.ended;
    _currentCall!.endedAt = DateTime.now().toUtc();
    _callUpdateController.add(_currentCall!);
  }

  /// Toggles microphone mute.
  void toggleAudioMute() {
    if (_currentCall == null) return;
    _currentCall!.isAudioMuted = !_currentCall!.isAudioMuted;
    _callUpdateController.add(_currentCall!);
  }

  /// Toggles camera mute/blank.
  void toggleVideoMute() {
    if (_currentCall == null) return;
    _currentCall!.isVideoMuted = !_currentCall!.isVideoMuted;
    _callUpdateController.add(_currentCall!);
  }

  /// Toggles front vs back camera facing.
  void toggleCameraFacing() {
    if (_currentCall == null) return;
    _currentCall!.isFrontCamera = !_currentCall!.isFrontCamera;
    _callUpdateController.add(_currentCall!);
  }

  void dispose() {
    _callUpdateController.close();
  }
}
