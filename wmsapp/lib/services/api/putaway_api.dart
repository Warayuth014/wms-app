part of '../api_service.dart';

extension PutawayApi on ApiService {
  Future<ApiResult<List<Map<String, dynamic>>>> getStationStatus() async {
    final response = await _get('/putaway/station-status');
    if (!response.success) return ApiResult.error(response.error);

    final items = response.data!['items'] as List;
    return ApiResult.success(items.cast<Map<String, dynamic>>());
  }

  Future<ApiResult<PutawayPalletInfo>> scanPalletForPutaway(
    String palletId, {
    String? stationId,
  }) async {
    final query = stationId != null ? '?stationId=$stationId' : '';
    final response = await _get('/putaway/scan-pallet/$palletId$query');
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(PutawayPalletInfo.fromJson(response.data!));
  }

  Future<ApiResult<PutawayResult>> confirmPutaway({
    required String stationId,
    required String palletId,
    required String destination,
    required String operatorId,
    bool wrappingRequired = false,
  }) async {
    final response = await _post('/putaway/confirm', {
      'stationId': stationId,
      'palletId': palletId,
      'destination': destination,
      'operatorId': operatorId,
      'wrappingRequired': wrappingRequired,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(PutawayResult.fromJson(response.data!));
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getPreworkStationStatus() async {
    final response = await _get('/putaway/prework-station-status');
    if (!response.success) return ApiResult.error(response.error);

    final stations = (response.data!['stations'] as List).cast<Map<String, dynamic>>();
    return ApiResult.success(stations);
  }

  Future<ApiResult<Map<String, dynamic>>> preworkReturnPallet({
    required String palletId,
    required String stationId,
  }) async {
    final response = await _post('/putaway/prework-return-pallet', {
      'palletId': palletId,
      'stationId': stationId,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(response.data!);
  }
}
