// lib/services/connectivity_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  // Singleton
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  // ── Stream สำหรับ listen สถานะ ──────────────
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChanged => _statusController.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  // ── เริ่ม listen ─────────────────────────────
  void initialize() {
    Connectivity().onConnectivityChanged.listen((result) {
      final online = result != ConnectivityResult.none;

      // แจ้งเตือนเฉพาะตอนที่สถานะเปลี่ยน
      if (online != _isOnline) {
        _isOnline = online;
        _statusController.add(_isOnline);
      }
    });

    // เช็คสถานะตอนเริ่ม app
    checkNow();
  }

  // ── เช็คสถานะตอนนี้ ──────────────────────────
  Future<bool> checkNow() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    return _isOnline;
  }

  void dispose() {
    _statusController.close();
  }
}
