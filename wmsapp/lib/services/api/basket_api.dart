part of '../api_service.dart';

extension BasketApi on ApiService {
  /// ดึงรายการสินค้าที่ Unload แล้ว (group by Part+Lot)
  Future<ApiResult<UnloadedItemsResponse>> getUnloadedItems() async {
    final response = await _get('/basket/unloaded-items');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(UnloadedItemsResponse.fromJson(response.data!));
  }

  /// Load Part เข้า Basket (by PartId+LotNumber)
  Future<ApiResult<LoadToBasketResponse>> loadToBasket({
    required String partId,
    String? lotNumber,
    required String basketId,
    required int qty,
    required String operatorId,
    List<String>? serialNumbers,
  }) async {
    final response = await _post('/basket/load', {
      'partId': partId,
      'lotNumber': lotNumber,
      'basketId': basketId,
      'qty': qty,
      'operatorId': operatorId,
      // Part ไม่ require serial ต้องส่ง null/[] เสมอ (ฝั่ง backend รองรับทั้งคู่)
      'serialNumbers': serialNumbers ?? [],
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(LoadToBasketResponse.fromJson(response.data!));
  }
}
