// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/wms_models.dart';

// =============================================
// ApiResult — wrapper สำหรับทุก API call
// =============================================
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult.success(this.data) : success = true, error = null;

  ApiResult.error(this.error) : success = false, data = null;
}

// =============================================
// ApiService
// =============================================
class ApiService {
  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── Base URL (auto-detect) ────────────────────
  // ลำดับการ probe:
  //   Android  → 10.0.2.2 (emulator) → physicalIp
  //   อื่นๆ    → localhost           → physicalIp
  static const _physicalIp = '192.168.1.141'; // แก้ IP ตรงนี้เมื่อ server ย้าย
  static const _port = 5000;
  static String? _cachedBase;

  static Future<String> _resolveBase() async {
    if (_cachedBase != null) return _cachedBase!;

    final candidates = <String>[
      if (Platform.isAndroid) 'http://10.0.2.2:$_port',
      if (!Platform.isAndroid) 'http://localhost:$_port',
      'http://$_physicalIp:$_port',
    ];

    for (final base in candidates) {
      final uri = Uri.parse(base);
      try {
        final sock = await Socket.connect(
          uri.host,
          uri.port,
          timeout: const Duration(seconds: 1),
        );
        sock.destroy();
        _cachedBase = '$base/api';
        return _cachedBase!;
      } catch (_) {}
    }

    // ถ้าทุก candidate ล้มเหลว ใช้ physicalIp เป็น fallback
    _cachedBase = 'http://$_physicalIp:$_port/api';
    return _cachedBase!;
  }

  /// รีเซ็ต cache (ใช้เมื่อต้องการให้ probe ใหม่ เช่น เปลี่ยน network)
  static void resetBaseUrl() => _cachedBase = null;

  final _headers = {'Content-Type': 'application/json'};

  // ── HTTP helpers ─────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> _get(String path) async {
    try {
      final base = await ApiService._resolveBase();
      final res = await http
          .get(Uri.parse('$base$path'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return _handle(res);
    } on SocketException {
      return ApiResult.error('ไม่สามารถเชื่อมต่อ server ได้');
    } on TimeoutException {
      return ApiResult.error('การเชื่อมต่อหมดเวลา กรุณาลองใหม่');
    } catch (e) {
      return ApiResult.error('เกิดข้อผิดพลาด: $e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final base = await ApiService._resolveBase();
      final res = await http
          .post(
            Uri.parse('$base$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return _handle(res);
    } on SocketException {
      return ApiResult.error('ไม่สามารถเชื่อมต่อ server ได้');
    } on TimeoutException {
      return ApiResult.error('การเชื่อมต่อหมดเวลา กรุณาลองใหม่');
    } catch (e) {
      return ApiResult.error('เกิดข้อผิดพลาด: $e');
    }
  }

  ApiResult<Map<String, dynamic>> _handle(http.Response res) {
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      return ApiResult.error('Server ส่งข้อมูลไม่ถูกต้อง (${res.statusCode})');
    }
    // ถ้า server ส่งมาเป็น array ให้ wrap ไว้ใน {"items": [...]}
    final body = decoded is List
        ? <String, dynamic>{'items': decoded}
        : decoded as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ApiResult.success(body);
    }
    final msg = body['error'] ?? body['detail'] ?? 'เกิดข้อผิดพลาด';
    return ApiResult.error(msg.toString());
  }

  // =============================================
  // FLOW 1 — Receiving
  // =============================================

  Future<ApiResult<POResponse>> getPO(String poId) async {
    final r = await _get('/receiving/po/$poId');
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(POResponse.fromJson(r.data!));
  }

  Future<ApiResult<ReceivingSession>> openReceivingSession({
    required String poId,
    required String operatorId,
  }) async {
    final r = await _post('/receiving/open-session', {
      'poId': poId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(ReceivingSession.fromJson(r.data!));
  }

  Future<ApiResult<ReceiptLineResponse>> scanReceiptPart({
    required int sessionId,
    required String poId,
    required String partId,
    required int qtyReceived,
    String? lotNumber,
    String? expiredDate,
    required String condition,
    required String operatorId,
  }) async {
    final r = await _post('/receiving/scan-part', {
      'sessionId': sessionId,
      'poId': poId,
      'partId': partId,
      'qtyReceived': qtyReceived,
      'lotNumber': lotNumber,
      'expiredDate': expiredDate,
      'condition': condition,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(ReceiptLineResponse.fromJson(r.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> assignPallet({
    required int sessionId,
    required String palletId,
    required String palletType,
    required String operatorId,
    required List<int> lineIds,
  }) async {
    final r = await _post('/receiving/assign-pallet', {
      'sessionId': sessionId,
      'palletId': palletId,
      'palletType': palletType,
      'operatorId': operatorId,
      'lineIds': lineIds,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> closeReceivingSession(
    int sessionId,
  ) async {
    final r = await _post('/receiving/close-session/$sessionId', {});
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  // =============================================
  // FLOW 2 — Unload
  // =============================================

  Future<ApiResult<PalletScanResponse>> scanPalletForUnload(
    String palletId,
  ) async {
    final r = await _get('/unload/scan-pallet/$palletId');
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(PalletScanResponse.fromJson(r.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> confirmLabeling({
    required String palletId,
    required String operatorId,
  }) async {
    final r = await _post('/unload/confirm-labeling', {
      'palletId': palletId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<UnloadSession>> openUnloadSession({
    required String palletId,
    required String operatorId,
  }) async {
    final r = await _post('/unload/open-session', {
      'palletId': palletId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(UnloadSession.fromJson(r.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> confirmUnload({
    required int sessionId,
    required String palletId,
    required String partId,
    required String operatorId,
  }) async {
    final r = await _post('/unload/confirm-unload', {
      'sessionId': sessionId,
      'palletId': palletId,
      'partId': partId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<BasketScanResponse>> scanBasket(String basketId) async {
    final r = await _get('/unload/scan-basket/$basketId');
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(BasketScanResponse.fromJson(r.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> loadToBasket({
    required int sessionId,
    required String basketId,
    required String partId,
    required String palletId,
    required String operatorId,
  }) async {
    final r = await _post('/unload/load-to-basket', {
      'sessionId': sessionId,
      'basketId': basketId,
      'partId': partId,
      'palletId': palletId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  // =============================================
  // Cancel
  // =============================================

  Future<ApiResult<CancelLog>> requestCancel({
    required String refType,
    required int refId,
    required String reason,
    required String requestBy,
  }) async {
    final r = await _post('/cancel/request', {
      'refType': refType,
      'refId': refId,
      'reason': reason,
      'requestBy': requestBy,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(CancelLog.fromJson(r.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> approveCancel({
    required int cancelId,
    required String approvedBy,
  }) async {
    final r = await _post('/cancel/approve', {
      'cancelId': cancelId,
      'approvedBy': approvedBy,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> rejectCancel({
    required int cancelId,
    required String supervisorId,
  }) async {
    final r = await _post(
      '/cancel/reject/$cancelId?supervisorId=$supervisorId',
      {},
    );
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<List<CancelLog>>> getPendingCancels() async {
    final r = await _get('/cancel/pending');
    if (!r.success) return ApiResult.error(r.error);
    final list = r.data!['items'] as List;
    return ApiResult.success(list.map((i) => CancelLog.fromJson(i)).toList());
  }
}
