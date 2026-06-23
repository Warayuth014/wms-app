part of '../api_service.dart';

extension PickingApi on ApiService {
  // ── New 2-page flow ─────────────────────────────────
  /// หน้า 1: list pick orders (WAITING + PICKING)
  Future<ApiResult<List<PickOrderListItem>>> getPickOrdersList() async {
    final response = await _get('/picking/orders-list');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    final items = (response.data!['items'] as List? ?? [])
        .map((e) => PickOrderListItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ApiResult.success(items);
  }

  /// หน้า 2: order detail (pallets + parts)
  Future<ApiResult<PickOrderDetailFull>> getPickOrderDetailFull(
      String pickOrderId) async {
    final response = await _get('/picking/orders/$pickOrderId/detail');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(PickOrderDetailFull.fromJson(response.data!));
  }

  /// แนะนำ pallet ปลายทาง — ถ้า order นี้กำลังใช้ pallet เดิมอยู่ → ส่ง pallet เดิม
  /// ไม่งั้นส่ง pallet ว่างถัดไป (Type=NULL + AVAILABLE)
  /// คืน (palletId, continued) — continued=true แปลว่าเป็น pallet เดิมที่ pick ก่อนหน้าไว้
  Future<ApiResult<({String palletId, bool continued})?>>
      getSuggestedDestPallet({String? pickOrderId}) async {
    final qs = pickOrderId != null
        ? '?pickOrderId=${Uri.encodeQueryComponent(pickOrderId)}'
        : '';
    final response = await _get('/picking/suggest-dest-pallets$qs');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    final list = (response.data!['items'] as List? ?? []);
    if (list.isEmpty) return ApiResult.success(null);
    final first = list.first as Map<String, dynamic>;
    return ApiResult.success((
      palletId: first['palletId'] as String,
      continued: (first['continued'] as bool?) ?? false,
    ));
  }

  /// Robot simulator: WAITING → PICKING + assign pallets
  Future<ApiResult<NotifyArrivalResponse>> notifyArrival(
      String pickOrderId) async {
    final response = await _post('/picking/orders/$pickOrderId/notify-arrival', {});
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(NotifyArrivalResponse.fromJson(response.data!));
  }

  // ── Existing endpoints ──────────────────────────────
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

    final response = await _post('/picking/assign-station', body);
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }

    return ApiResult.success(AssignPickStationResponse.fromJson(response.data!));
  }

  Future<ApiResult<ConfirmPickResponse>> confirmPickV2({
    required String pickOrderId,
    required String sourcePalletId,
    required String destPalletId,
    required List<Map<String, dynamic>> items,
    required String operatorId,
  }) async {
    final response = await _post('/picking/confirm-pick', {
      'pickOrderId': pickOrderId,
      'sourcePalletId': sourcePalletId,
      'destPalletId': destPalletId,
      'items': items,
      'operatorId': operatorId,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(ConfirmPickResponse.fromJson(response.data!));
  }

  Future<ApiResult<void>> returnPallet({
    required String palletId,
    required String destination,
  }) async {
    final response = await _post('/picking/return-pallet', {
      'palletId': palletId,
      'destination': destination,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(null);
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getAvailableLines() async {
    final response = await _get('/picking/available-lines');
    if (!response.success) return ApiResult.error(response.error);

    final list = (response.data!['items'] as List).cast<Map<String, dynamic>>();
    return ApiResult.success(list);
  }

  Future<ApiResult<Map<String, dynamic>>> sendToPack({
    required String palletId,
  }) async {
    final response = await _post('/picking/send-to-pack/$palletId', {});
    if (!response.success) return ApiResult.error(response.error);
    return ApiResult.success(response.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> createTestOrder({
    required String operatorId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _post('/picking/create-test-order', {
      'operatorId': operatorId,
      'items': items,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(response.data!);
  }
}
