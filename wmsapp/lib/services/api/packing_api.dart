part of '../api_service.dart';

extension PackingApi on ApiService {
  Future<ApiResult<PackingScanResponse>> scanPalletForPacking(
    String palletId,
  ) async {
    final response = await _get('/packing/scan-pallet/$palletId');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }

    return ApiResult.success(PackingScanResponse.fromJson(response.data!));
  }

  Future<ApiResult<ConfirmPackResponse>> confirmPack({
    required String palletId,
    required String operatorId,
  }) async {
    final response = await _post('/packing/confirm-pack', {
      'palletId': palletId,
      'operatorId': operatorId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }

    return ApiResult.success(ConfirmPackResponse.fromJson(response.data!));
  }
}
