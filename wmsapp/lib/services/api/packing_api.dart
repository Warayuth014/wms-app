part of '../api_service.dart';

extension PackingApi on ApiService {
  /// Scan Pallet → ดึง list ของ Pack ที่ต้อง pack บน Pallet นี้
  Future<ApiResult<PackingPalletResponse>> scanPalletForPacking(
    String palletId,
  ) async {
    final response = await _get('/packing/pallet/$palletId');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(PackingPalletResponse.fromJson(response.data!));
  }

  /// ดึงรายละเอียด Pack → list ของ Order
  Future<ApiResult<PackingDetailResponse>> getPack(String packingId) async {
    final response = await _get('/packing/pack/$packingId');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(PackingDetailResponse.fromJson(response.data!));
  }

  /// ดึง Order → list ของ Part + จำนวนที่สแกนแล้ว
  Future<ApiResult<PackingOrderResponse>> getPackOrder({
    required String packingId,
    required String pickOrderId,
  }) async {
    final response = await _get('/packing/pack/$packingId/order/$pickOrderId');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(PackingOrderResponse.fromJson(response.data!));
  }

  /// สแกน Part 1 ครั้ง (เพิ่ม scanned qty)
  Future<ApiResult<PackingOrderResponse>> scanPackPart({
    required String packingId,
    required String pickOrderId,
    required String partId,
    required int qty,
    required String operatorId,
  }) async {
    final response = await _post('/packing/scan-part', {
      'packingId': packingId,
      'pickOrderId': pickOrderId,
      'partId': partId,
      'qty': qty,
      'operatorId': operatorId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(PackingOrderResponse.fromJson(response.data!));
  }

  /// ยืนยัน Pack → DONE + (auto-ship Pallet ถ้าเป็น Pack สุดท้าย)
  Future<ApiResult<ConfirmPackResponse>> confirmPack({
    required String packingId,
    required String operatorId,
  }) async {
    final response = await _post('/packing/confirm-pack', {
      'packingId': packingId,
      'operatorId': operatorId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(ConfirmPackResponse.fromJson(response.data!));
  }
}
