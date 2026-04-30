// lib/services/sorting_signalr_service.dart

import 'dart:developer' as dev;
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'api_service.dart';

typedef SortingCallback = void Function(Map<String, dynamic> data);

/// SignalR singleton สำหรับ Sorting hub
class SortingSignalRService {
  static final SortingSignalRService _instance =
      SortingSignalRService._internal();
  factory SortingSignalRService() => _instance;
  SortingSignalRService._internal();

  HubConnection? _connection;
  int _refCount = 0;

  // listeners
  final List<SortingCallback> _counterUpdated = [];
  final List<SortingCallback> _stationFull = [];
  final List<SortingCallback> _stationCleared = [];
  final List<SortingCallback> _stationToggled = [];
  final List<SortingCallback> _batchQueued = [];
  final List<SortingCallback> _batchAssigned = [];

  Future<void> connect() async {
    _refCount++;
    if (_connection != null &&
        _connection!.state != HubConnectionState.Disconnected) {
      return;
    }

    try {
      final serverUrl = await ApiService.resolveServerUrl();
      final hubUrl = '$serverUrl/hubs/sorting';

      _connection = HubConnectionBuilder()
          .withUrl(hubUrl)
          .withAutomaticReconnect()
          .build();

      _connection!.on('StationCounterUpdated', _on(_counterUpdated));
      _connection!.on('StationFull', _on(_stationFull));
      _connection!.on('StationCleared', _on(_stationCleared));
      _connection!.on('StationToggled', _on(_stationToggled));
      _connection!.on('BatchQueued', _on(_batchQueued));
      _connection!.on('BatchAssigned', _on(_batchAssigned));

      await _connection!.start();
      dev.log('[Sorting SignalR] Connected to $hubUrl');
    } catch (e) {
      dev.log('[Sorting SignalR] Connect error: $e');
    }
  }

  Future<void> disconnect() async {
    _refCount--;
    if (_refCount <= 0) {
      _refCount = 0;
      if (_connection != null) {
        await _connection!.stop();
        _connection = null;
        dev.log('[Sorting SignalR] Disconnected');
      }
    }
  }

  // helper: build handler ที่ broadcast ไปทุก listener ใน list
  void Function(List<Object?>?) _on(List<SortingCallback> listeners) =>
      (args) {
        final data = _parseArgs(args);
        for (final cb in List.of(listeners)) {
          cb(data);
        }
      };

  // ── add/remove listeners ────────────────────
  void onCounterUpdated(SortingCallback cb) => _counterUpdated.add(cb);
  void offCounterUpdated(SortingCallback cb) => _counterUpdated.remove(cb);

  void onStationFull(SortingCallback cb) => _stationFull.add(cb);
  void offStationFull(SortingCallback cb) => _stationFull.remove(cb);

  void onStationCleared(SortingCallback cb) => _stationCleared.add(cb);
  void offStationCleared(SortingCallback cb) => _stationCleared.remove(cb);

  void onStationToggled(SortingCallback cb) => _stationToggled.add(cb);
  void offStationToggled(SortingCallback cb) => _stationToggled.remove(cb);

  void onBatchQueued(SortingCallback cb) => _batchQueued.add(cb);
  void offBatchQueued(SortingCallback cb) => _batchQueued.remove(cb);

  void onBatchAssigned(SortingCallback cb) => _batchAssigned.add(cb);
  void offBatchAssigned(SortingCallback cb) => _batchAssigned.remove(cb);

  Map<String, dynamic> _parseArgs(List<Object?>? args) {
    if (args == null || args.isEmpty) return {};
    final first = args.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
    return {};
  }
}
