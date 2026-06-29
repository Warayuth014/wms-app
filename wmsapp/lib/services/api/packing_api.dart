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

  /// ดึง Order → list ของ Part + จำนวนที่สแกนแล้ว (per-pallet)
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

  /// สแกน Part (เพิ่ม scanned qty) — ส่ง serialNumbers ได้ (optional)
  /// Auto-finalize เมื่อทุก Detail ใน Pack เป็น DONE — response จะมี
  /// packFinalized=true + trackingId + palletReleased
  Future<ApiResult<PackingOrderResponse>> scanPackPart({
    required String packingId,
    required String pickOrderId,
    required String partId,
    required int qty,
    required String operatorId,
    List<String>? serialNumbers,
  }) async {
    final response = await _post('/packing/scan-part', {
      'packingId': packingId,
      'pickOrderId': pickOrderId,
      'partId': partId,
      'qty': qty,
      'operatorId': operatorId,
      if (serialNumbers != null && serialNumbers.isNotEmpty)
        'serialNumbers': serialNumbers,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(PackingOrderResponse.fromJson(response.data!));
  }
}
