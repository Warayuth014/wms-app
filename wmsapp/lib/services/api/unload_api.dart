part of '../api_service.dart';

extension UnloadApi on ApiService {
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
    required int lineId,
    required String operatorId,
    int? qtyUnloaded,
    List<String>? serialNumbers,
  }) async {
    final body = <String, dynamic>{
      'sessionId': sessionId,
      'palletId': palletId,
      'partId': partId,
      'lineId': lineId,
      'operatorId': operatorId,
      // Part ไม่ require serial ต้องส่ง null/[] เสมอ (ฝั่ง backend รองรับทั้งคู่)
      'serialNumbers': serialNumbers ?? [],
    };
    if (qtyUnloaded != null) body['qtyUnloaded'] = qtyUnloaded;

    final response = await _post('/unload/confirm-unload', body);
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(response.data!);
  }

  Future<ApiResult<Map<String, dynamic>>> returnPalletToAsis({
    required String palletId,
    int? sessionId,
  }) async {
    final response = await _post('/unload/return-pallet-to-asis', {
      'palletId': palletId,
      'sessionId': sessionId,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(response.data!);
  }
}
