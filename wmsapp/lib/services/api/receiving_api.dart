part of '../api_service.dart';

extension ReceivingApi on ApiService {
  Future<ApiResult<POResponse>> getPO(String poId) async {
    final response = await _get('/receiving/po/$poId');
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(POResponse.fromJson(response.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> validateReceivingSerial({
    required String partId,
    required String serialNo,
  }) async {
    final path = Uri(
      path: '/receiving/validate-serial',
      queryParameters: {
        'partId': partId,
        'serialNo': serialNo,
      },
    ).toString();

    return _get(path);
  }

  Future<ApiResult<ReceiptLineResponse>> scanReceiptPart({
    required String poId,
    required String partId,
    required int qtyReceived,
    required String operatorId,
    List<String>? serialNumbers,
  }) async {
    final response = await _post('/receiving/scan-part', {
      'poId': poId,
      'partId': partId,
      'qtyReceived': qtyReceived,
      'operatorId': operatorId,
      if (serialNumbers != null && serialNumbers.isNotEmpty)
        'serialNumbers': serialNumbers,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(ReceiptLineResponse.fromJson(response.data!));
  }

  Future<ApiResult<Map<String, dynamic>>> assignPallet({
    required String palletId,
    required String palletType,
    required String operatorId,
    required List<int> lineIds,
  }) async {
    final response = await _post('/receiving/assign-pallet', {
      'palletId': palletId,
      'palletType': palletType,
      'operatorId': operatorId,
      'lineIds': lineIds,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(response.data!);
  }

  Future<ApiResult<List<PendingPalletLine>>> getPendingPalletLines() async {
    final response = await _get('/receiving/pending-pallet-lines');
    if (!response.success) return ApiResult.error(response.error);

    final list = (response.data!['lines'] as List)
        .map((item) => PendingPalletLine.fromJson(item))
        .toList();
    return ApiResult.success(list);
  }
}
