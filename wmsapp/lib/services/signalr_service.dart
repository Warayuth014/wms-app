// lib/services/signalr_service.dart

import 'dart:developer' as dev;
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'api_service.dart';

typedef SignalRCallback = void Function(Map<String, dynamic> data);

/// Singleton SignalR service สำหรับ Putaway screens
/// ใช้ ref-counting เพื่อ connect/disconnect อัตโนมัติ
class SignalRService {
  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  HubConnection? _connection;
  int _refCount = 0;

  // ── Listener lists ──────────────────────────
  final List<SignalRCallback> _stationDispatchedListeners = [];
  final List<SignalRCallback> _palletArrivedListeners = [];
  final List<SignalRCallback> _palletReturnedListeners = [];
  final List<SignalRCallback> _labelingCompletedListeners = [];

  // ── Connect / Disconnect ────────────────────
  Future<void> connect() async {
    _refCount++;
    if (_connection != null &&
        _connection!.state != HubConnectionState.Disconnected) {
      return; // already connected
    }

    try {
      final serverUrl = await ApiService.resolveServerUrl();
      final hubUrl = '$serverUrl/hubs/putaway';

      _connection = HubConnectionBuilder()
          .withUrl(hubUrl)
          .withAutomaticReconnect()
          .build();

      _connection!.on('StationDispatched', _onStationDispatched);
      _connection!.on('PalletArrived', _onPalletArrived);
      _connection!.on('PalletReturned', _onPalletReturned);
      _connection!.on('LabelingCompleted', _onLabelingCompleted);

      await _connection!.start();
      dev.log('[SignalR] Connected to $hubUrl');
    } catch (e) {
      dev.log('[SignalR] Connect error: $e');
    }
  }

  Future<void> disconnect() async {
    _refCount--;
    if (_refCount <= 0) {
      _refCount = 0;
      if (_connection != null) {
        await _connection!.stop();
        _connection = null;
        dev.log('[SignalR] Disconnected');
      }
    }
  }

  // ── Register / Unregister listeners ─────────
  void addStationDispatchedListener(SignalRCallback cb) =>
      _stationDispatchedListeners.add(cb);
  void removeStationDispatchedListener(SignalRCallback cb) =>
      _stationDispatchedListeners.remove(cb);

  void addPalletArrivedListener(SignalRCallback cb) =>
      _palletArrivedListeners.add(cb);
  void removePalletArrivedListener(SignalRCallback cb) =>
      _palletArrivedListeners.remove(cb);

  void addPalletReturnedListener(SignalRCallback cb) =>
      _palletReturnedListeners.add(cb);
  void removePalletReturnedListener(SignalRCallback cb) =>
      _palletReturnedListeners.remove(cb);

  void addLabelingCompletedListener(SignalRCallback cb) =>
      _labelingCompletedListeners.add(cb);
  void removeLabelingCompletedListener(SignalRCallback cb) =>
      _labelingCompletedListeners.remove(cb);

  // ── Internal handlers ───────────────────────
  void _onStationDispatched(List<Object?>? args) {
    final data = _parseArgs(args);
    for (final cb in List.of(_stationDispatchedListeners)) {
      cb(data);
    }
  }

  void _onPalletArrived(List<Object?>? args) {
    final data = _parseArgs(args);
    for (final cb in List.of(_palletArrivedListeners)) {
      cb(data);
    }
  }

  void _onPalletReturned(List<Object?>? args) {
    final data = _parseArgs(args);
    for (final cb in List.of(_palletReturnedListeners)) {
      cb(data);
    }
  }

  void _onLabelingCompleted(List<Object?>? args) {
    final data = _parseArgs(args);
    for (final cb in List.of(_labelingCompletedListeners)) {
      cb(data);
    }
  }

  // ignore: unintended_html_in_doc_comment
  /// Parse SignalR args → Map<String, dynamic>
  Map<String, dynamic> _parseArgs(List<Object?>? args) {
    if (args == null || args.isEmpty) return {};
    final first = args.first;
    if (first is Map<String, dynamic>) {
      return first;
    }
    if (first is Map) {
      return Map<String, dynamic>.from(first);
    }
    return {};
  }
}
