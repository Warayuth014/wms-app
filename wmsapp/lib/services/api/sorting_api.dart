part of '../api_service.dart';

extension SortingApi on ApiService {
  /// Grid 10 stations
  Future<ApiResult<List<SortingStationView>>> getSortingStations() async {
    final response = await _get('/sorting/stations');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    final items = (response.data!['items'] as List? ?? [])
        .map((e) => SortingStationView.fromJson(e as Map<String, dynamic>))
        .toList();
    return ApiResult.success(items);
  }

  /// Station detail (sheet)
  Future<ApiResult<SortingStationDetail>> getSortingStation(int stationId) async {
    final response = await _get('/sorting/stations/$stationId');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(SortingStationDetail.fromJson(response.data!));
  }

  /// Toggle station enabled/disabled
  Future<ApiResult<Map<String, dynamic>>> toggleSortingStation({
    required int stationId,
    required bool enable,
    required String operatorId,
    String? reason,
  }) async {
    final response = await _post('/sorting/stations/toggle', {
      'stationId': stationId,
      'enable': enable,
      'operatorId': operatorId,
      if (reason != null) 'reason': reason,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(response.data!);
  }

  /// Clear FULL station
  Future<ApiResult<Map<String, dynamic>>> clearSortingStation({
    required int stationId,
    required String operatorId,
  }) async {
    final response = await _post('/sorting/stations/clear', {
      'stationId': stationId,
      'operatorId': operatorId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(response.data!);
  }

  /// Test: list available DONE packs
  Future<ApiResult<List<AvailablePackForSorting>>>
      getAvailablePacksForSorting() async {
    final response = await _get('/sorting/test/available-packs');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    final items = (response.data!['items'] as List? ?? [])
        .map((e) => AvailablePackForSorting.fromJson(e as Map<String, dynamic>))
        .toList();
    return ApiResult.success(items);
  }

  /// Test: create batch from selected packs
  Future<ApiResult<CreateSortingBatchResponse>> createSortingBatch({
    required String operatorId,
    required List<String> packingIds,
  }) async {
    final response = await _post('/sorting/test/create-batch', {
      'operatorId': operatorId,
      'packingIds': packingIds,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(
        CreateSortingBatchResponse.fromJson(response.data!));
  }
}
