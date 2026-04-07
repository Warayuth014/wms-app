part of '../api_service.dart';

extension SortingApi on ApiService {
  Future<ApiResult<List<SortStation>>> getSortStations() async {
    final response = await _get('/sorting/stations');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }

    final list = (response.data!['items'] as List)
        .map((e) => SortStation.fromJson(e as Map<String, dynamic>))
        .toList();
    return ApiResult.success(list);
  }

  Future<ApiResult<SortSession>> openSortSession({
    required String stationId,
    required String sortPalletId,
    required String operatorId,
  }) async {
    final response = await _post('/sorting/open-session', {
      'stationId': stationId,
      'sortPalletId': sortPalletId,
      'operatorId': operatorId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }

    return ApiResult.success(SortSession.fromJson(response.data!));
  }

  Future<ApiResult<SortSession>> scanSortCarton({
    required int sessionId,
    required String cartonId,
    required String operatorId,
  }) async {
    final response = await _post('/sorting/scan-carton', {
      'sessionId': sessionId,
      'cartonId': cartonId,
      'operatorId': operatorId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }

    return ApiResult.success(SortSession.fromJson(response.data!));
  }

  Future<ApiResult<SortSession>> closeSortSession({
    required int sessionId,
    required String operatorId,
  }) async {
    final response = await _post('/sorting/close-session', {
      'sessionId': sessionId,
      'operatorId': operatorId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }

    return ApiResult.success(SortSession.fromJson(response.data!));
  }
}
