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
  final int? statusCode;

  ApiResult.success(this.data) : success = true, error = null, statusCode = 200;

  ApiResult.error(this.error, {this.statusCode}) : success = false, data = null;

  bool get isNotFound => statusCode == 404;
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
  static const _physicalIp = '192.168.1.159'; // แก้ IP ตรงนี้เมื่อ server ย้าย
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
    // รองรับ camelCase จาก ApiError DTO: { error: "...", detail: "..." }
    final error = body['error']?.toString();
    final detail = body['detail']?.toString();
    final msg = (error != null && detail != null)
        ? '$error\n$detail'
        : error ?? detail ?? 'เกิดข้อผิดพลาด (${res.statusCode})';
    return ApiResult.error(msg, statusCode: res.statusCode);
  }

  // ── Multipart upload helper ─────────────────
  Future<ApiResult<Map<String, dynamic>>> _uploadFile(
    String path,
    File file, {
    Map<String, String> fields = const {},
  }) async {
    try {
      final base = await ApiService._resolveBase();
      final uri = Uri.parse('$base$path');
      final req = http.MultipartRequest('POST', uri);
      req.fields.addAll(fields);
      req.files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      return _handle(res);
    } on SocketException {
      return ApiResult.error('ไม่สามารถเชื่อมต่อ server ได้');
    } on TimeoutException {
      return ApiResult.error('การเชื่อมต่อหมดเวลา กรุณาลองใหม่');
    } catch (e) {
      return ApiResult.error('เกิดข้อผิดพลาด: $e');
    }
  }

  // =============================================
  // Upload — Part Image
  // =============================================

  /// ดึงรายการ Parts ทั้งหมด (สำหรับหน้าจัดการรูป)
  Future<ApiResult<List<Map<String, dynamic>>>> getAllParts() async {
    final r = await _get('/upload/parts');
    if (!r.success) return ApiResult.error(r.error);
    final items = r.data!['items'] as List;
    return ApiResult.success(items.cast<Map<String, dynamic>>());
  }

  /// อัปโหลดรูป Part
  Future<ApiResult<Map<String, dynamic>>> uploadPartImage({
    required String partId,
    required File imageFile,
  }) async {
    return _uploadFile(
      '/upload/part-image',
      imageFile,
      fields: {'partId': partId},
    );
  }

  /// สร้าง full URL ของรูปจาก relative path
  Future<String> getImageFullUrl(String relativePath) async {
    final base = await _resolveBase();
    // base = "http://x.x.x.x:5000/api" → ตัด /api ออก
    final serverBase = base.replaceAll('/api', '');
    return '$serverBase$relativePath';
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

  /// ดึง session ที่ยังเปิดอยู่ของ PO (ถ้ามี)
  /// คืน null ถ้าไม่มี session ที่ค้างอยู่ (404 หรือ error ใดๆ = ไม่มี)
  Future<ReceivingSession?> getActiveReceivingSession(String poId) async {
    try {
      final base = await ApiService._resolveBase();
      final res = await http
          .get(
            Uri.parse('$base/receiving/active-session/$poId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return ReceivingSession.fromJson(body);
      }
      return null; // 404 หรือ error อื่น = ไม่มี session ค้างอยู่
    } catch (_) {
      return null;
    }
  }

  Future<ApiResult<ReceiptLineResponse>> scanReceiptPart({
    required int sessionId,
    required String poId,
    required String partId,
    required int qtyReceived,
    required String operatorId,
  }) async {
    final r = await _post('/receiving/scan-part', {
      'sessionId': sessionId,
      'poId': poId,
      'partId': partId,
      'qtyReceived': qtyReceived,
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

  Future<ApiResult<List<PendingPalletLine>>> getPendingPalletLines() async {
    final r = await _get('/receiving/pending-pallet-lines');
    if (!r.success) return ApiResult.error(r.error);
    final list = (r.data!['lines'] as List)
        .map((i) => PendingPalletLine.fromJson(i))
        .toList();
    return ApiResult.success(list);
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
    int? qtyUnloaded,
  }) async {
    final body = <String, dynamic>{
      'sessionId': sessionId,
      'palletId': palletId,
      'partId': partId,
      'operatorId': operatorId,
    };
    if (qtyUnloaded != null) body['qtyUnloaded'] = qtyUnloaded;
    final r = await _post('/unload/confirm-unload', body);
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<BasketScanResponse>> scanBasket(String basketId) async {
    final r = await _get('/unload/scan-basket/$basketId');
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(BasketScanResponse.fromJson(r.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> loadToBasketBySession({
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
  // PUTAWAY
  // =============================================

  /// ดึงสถานะ Station ทั้งหมด (station ไหนมี pallet อยู่)
  Future<ApiResult<List<Map<String, dynamic>>>> getStationStatus() async {
    final r = await _get('/putaway/station-status');
    if (!r.success) return ApiResult.error(r.error);
    final items = r.data!['items'] as List;
    return ApiResult.success(items.cast<Map<String, dynamic>>());
  }

  Future<ApiResult<PutawayPalletInfo>> scanPalletForPutaway(
    String palletId, {
    String? stationId,
  }) async {
    final query = stationId != null ? '?stationId=$stationId' : '';
    final r = await _get('/putaway/scan-pallet/$palletId$query');
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(PutawayPalletInfo.fromJson(r.data!));
  }

  Future<ApiResult<PutawayResult>> confirmPutaway({
    required String stationId,
    required String palletId,
    required String destination,
    required String operatorId,
    bool wrappingRequired = false,
    bool convertToFG = true,
  }) async {
    final r = await _post('/putaway/confirm', {
      'stationId': stationId,
      'palletId': palletId,
      'destination': destination,
      'operatorId': operatorId,
      'wrappingRequired': wrappingRequired,
      'convertToFG': convertToFG,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(PutawayResult.fromJson(r.data!));
  }

  Future<ApiResult<PutawayResult>> recallToPrework({
    required String palletId,
    required String stationId,
    required String operatorId,
  }) async {
    final r = await _post('/putaway/recall-to-prework', {
      'palletId': palletId,
      'stationId': stationId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(PutawayResult.fromJson(r.data!));
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getPreworkPallets() async {
    final r = await _get('/putaway/prework-pallets');
    if (!r.success) return ApiResult.error(r.error);
    final items = (r.data!['items'] as List).cast<Map<String, dynamic>>();
    return ApiResult.success(items);
  }

  Future<ApiResult<PreworkReceiveResult>> preworkReceive({
    required String palletId,
    required String stationId,
    required String operatorId,
  }) async {
    final r = await _post('/putaway/prework-receive', {
      'palletId': palletId,
      'stationId': stationId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(PreworkReceiveResult.fromJson(r.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> preworkReturnPallet({
    required String palletId,
    required String stationId,
    required String operatorId,
  }) async {
    final r = await _post('/putaway/prework-return-pallet', {
      'palletId': palletId,
      'stationId': stationId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  // ── Return ────────────────────────────────

  Future<ApiResult<OrderResponse>> getReturnOrder(String orderId) async {
    final r = await _get('/return/order/$orderId');
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(OrderResponse.fromJson(r.data!));
  }

  Future<ApiResult<OpenReturnResponse>> openReturnSession({
    required String orderId,
    required String operatorId,
  }) async {
    final r = await _post('/return/open-session', {
      'orderId': orderId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(OpenReturnResponse.fromJson(r.data!));
  }

  Future<ApiResult<ReceiveReturnItemResponse>> receiveReturnItem({
    required int returnId,
    required String orderId,
    required String partId,
    required int qtyReturned,
    String? note,
    required String operatorId,
  }) async {
    final r = await _post('/return/receive-item', {
      'returnId': returnId,
      'orderId': orderId,
      'partId': partId,
      'qtyReturned': qtyReturned,
      'note': note,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(ReceiveReturnItemResponse.fromJson(r.data!));
  }

  Future<ApiResult<CloseReturnResponse>> closeReturnSession(
    int returnId,
  ) async {
    final r = await _post('/return/close-session/$returnId', {});
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(CloseReturnResponse.fromJson(r.data!));
  }

  // GET confirmed items สำหรับ Load Basket (grouped by PartId)
  Future<ApiResult<List<GroupedUnloadItem>>> getConfirmedUnloadItems() async {
    final r = await _get('/unload/confirmed-items');
    if (!r.success) return ApiResult.error(r.error);
    final list = (r.data!['items'] as List)
        .map((i) => GroupedUnloadItem.fromJson(i))
        .toList();
    return ApiResult.success(list);
  }


  Future<ApiResult<Map<String, dynamic>>> returnPalletToAsis({
    required String palletId,
    int? sessionId,
    required String operatorId,
  }) async {
    final r = await _post('/unload/return-pallet-to-asis', {
      'palletId': palletId,
      'sessionId': sessionId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> returnBasket({
    required String basketId,
    required String operatorId,
  }) async {
    final r = await _post('/unload/return-basket', {
      'basketId': basketId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  // =============================================
  // PICKING
  // =============================================

  Future<PickingSession?> getActivePickingSession(String packPalletId) async {
    try {
      final base = await ApiService._resolveBase();
      final res = await http
          .get(
            Uri.parse('$base/picking/active-session/$packPalletId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return PickingSession.fromJson(body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ApiResult<AssignPickStationResponse>> assignPickStation({
    required String palletId,
    required String operatorId,
    String? pickOrderId,
  }) async {
    final body = <String, dynamic>{
      'palletId': palletId,
      'operatorId': operatorId,
    };
    if (pickOrderId != null) body['pickOrderId'] = pickOrderId;
    final r = await _post('/picking/assign-station', body);
    if (!r.success) return ApiResult.error(r.error, statusCode: r.statusCode);
    return ApiResult.success(AssignPickStationResponse.fromJson(r.data!));
  }

  Future<ApiResult<ConfirmPickResponse>> confirmPickV2({
    required String pickOrderId,
    required String sourcePalletId,
    required String destPalletId,
    required List<Map<String, dynamic>> items,
    required String operatorId,
  }) async {
    final r = await _post('/picking/confirm-pick', {
      'pickOrderId': pickOrderId,
      'sourcePalletId': sourcePalletId,
      'destPalletId': destPalletId,
      'items': items,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(ConfirmPickResponse.fromJson(r.data!));
  }

  Future<ApiResult<void>> returnPallet({
    required String palletId,
    required String destination,
  }) async {
    final r = await _post('/picking/return-pallet', {
      'palletId': palletId,
      'destination': destination,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(null);
  }

  // =============================================
  // TEST — สร้าง Pick Order สำหรับทดสอบ
  // =============================================

  Future<ApiResult<List<Map<String, dynamic>>>> getAvailableLines() async {
    final r = await _get('/picking/available-lines');
    if (!r.success) return ApiResult.error(r.error);
    final list = (r.data!['items'] as List).cast<Map<String, dynamic>>();
    return ApiResult.success(list);
  }

  Future<ApiResult<Map<String, dynamic>>> createTestOrder({
    required String operatorId,
    required List<Map<String, dynamic>> items,
  }) async {
    final r = await _post('/picking/create-test-order', {
      'operatorId': operatorId,
      'items': items,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  // =============================================
  // SIMULATION — จำลองระบบอัตโนมัติ (AGV/ASRS/Labeling)
  // =============================================

  Future<ApiResult<Map<String, dynamic>>> simulateAsrsRetrieve({
    required String palletId,
    required String destination,
  }) async {
    final r = await _post('/simulate/asrs/retrieve-pallet', {
      'palletId': palletId,
      'destination': destination,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> simulateAsrsReceive(
    String palletId,
  ) async {
    final r = await _post('/simulate/asrs/receive-pallet/$palletId', {});
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> simulateAgvDeliver({
    required String palletId,
    required String destination,
  }) async {
    final r = await _post('/simulate/agv/deliver-pallet', {
      'palletId': palletId,
      'destination': destination,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> simulateAgvPickup(
    String palletId,
  ) async {
    final r = await _post('/simulate/agv/pickup-pallet/$palletId', {});
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> simulateLabelingComplete(
    String palletId,
  ) async {
    final r = await _post('/simulate/labeling/complete/$palletId', {});
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> simulatePalletReturnComplete({
    required String palletId,
    String? destination,
  }) async {
    final r = await _post('/simulate/pallet/return-complete', {
      'palletId': palletId,
      'destination': destination ?? 'ASRS',
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> simulateBasketReturnComplete(
    String basketId,
  ) async {
    final r = await _post('/simulate/basket/return-complete/$basketId', {});
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<CompletePickingResult>> completePickingSession(
    int sessionId,
  ) async {
    final r = await _post('/picking/complete-session/$sessionId', {});
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(CompletePickingResult.fromJson(r.data!));
  }

  // Load to basket (by PartId + Qty)
  Future<ApiResult<Map<String, dynamic>>> loadToBasket({
    required String partId,
    required String basketId,
    required int qty,
    required String operatorId,
  }) async {
    final r = await _post('/unload/load-basket', {
      'partId': partId,
      'basketId': basketId,
      'qty': qty,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  // =============================================
  // REPLENISHMENT
  // =============================================

  Future<ApiResult<CheckTriggerResponse>> checkReplenishTrigger() async {
    final r = await _get('/replenish/check-trigger');
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(CheckTriggerResponse.fromJson(r.data!));
  }

  Future<ApiResult<ReplenishOrderResponse>> createReplenishOrder({
    required String triggeredBy,
    required List<Map<String, dynamic>> lines,
  }) async {
    final r = await _post('/replenish/create-order', {
      'triggeredBy': triggeredBy,
      'lines': lines,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(ReplenishOrderResponse.fromJson(r.data!));
  }

  Future<ApiResult<List<ReplenishOrderResponse>>> getReplenishOrders() async {
    final r = await _get('/replenish/orders');
    if (!r.success) return ApiResult.error(r.error);
    final items = r.data!['items'] as List;
    return ApiResult.success(
      items.map((e) => ReplenishOrderResponse.fromJson(e)).toList(),
    );
  }

  Future<ApiResult<ToteScanResponse>> scanTote(String toteId) async {
    final r = await _get('/replenish/scan-tote/$toteId');
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(ToteScanResponse.fromJson(r.data!));
  }

  Future<ApiResult<ReplenishSessionResponse>> openReplenishSession({
    required int orderId,
    required String toteId,
    required String palletId,
    required String operatorId,
  }) async {
    final r = await _post('/replenish/open-session', {
      'orderId': orderId,
      'toteId': toteId,
      'palletId': palletId,
      'operatorId': operatorId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(ReplenishSessionResponse.fromJson(r.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> confirmReplenishLine({
    required int sessionId,
    required int sessionLineId,
    required int qtyFilled,
  }) async {
    final r = await _post('/replenish/confirm-line', {
      'sessionId': sessionId,
      'sessionLineId': sessionLineId,
      'qtyFilled': qtyFilled,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> completeReplenishSession(
      int sessionId) async {
    final r = await _post('/replenish/complete-session', {
      'sessionId': sessionId,
    });
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }

  // ── Haipick ──────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> getHaipickInventory() async {
    final r = await _get('/haipick/inventory');
    if (!r.success) return ApiResult.error(r.error);
    return ApiResult.success(r.data!);
  }
}
