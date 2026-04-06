part of '../api_service.dart';

extension UnloadApi on ApiService {
  Future<ApiResult<PalletScanResponse>> scanPalletForUnload(
    String palletId,
  ) async {
    final response = await _get('/unload/scan-pallet/$palletId');
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(PalletScanResponse.fromJson(response.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> confirmLabeling({
    required String palletId,
    required String operatorId,
  }) async {
    final response = await _post('/unload/confirm-labeling', {
      'palletId': palletId,
      'operatorId': operatorId,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(response.data!);
  }

  Future<ApiResult<UnloadSession>> openUnloadSession({
    required String palletId,
    required String operatorId,
  }) async {
    final response = await _post('/unload/open-session', {
      'palletId': palletId,
      'operatorId': operatorId,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(UnloadSession.fromJson(response.data!));
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

    final response = await _post('/unload/confirm-unload', body);
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(response.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> returnPalletToAsis({
    required String palletId,
    int? sessionId,
    required String operatorId,
  }) async {
    final response = await _post('/unload/return-pallet-to-asis', {
      'palletId': palletId,
      'sessionId': sessionId,
      'operatorId': operatorId,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(response.data!);
  }
}
