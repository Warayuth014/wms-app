part of '../api_service.dart';

extension PickingApi on ApiService {
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
