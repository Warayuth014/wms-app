part of '../api_service.dart';

extension ReceivingApi on ApiService {
  Future<ApiResult<POResponse>> getPO(String poId) async {
    final response = await _get('/receiving/po/$poId');
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(POResponse.fromJson(response.data!));
  }

  Future<ApiResult<ValidateSerialResponse>> validateReceivingSerial({
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

    final response = await _get(path);
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(ValidateSerialResponse.fromJson(response.data!));
  }

  // สแกน Part ID อย่างเดียว (ยังไม่มี S/N) — เช็คว่า part นี้มีกี่ condition/lot ให้เลือก
  Future<ApiResult<PartLinesResponse>> getPartLines(String partId) async {
    final path = Uri(
      path: '/receiving/validate-serial',
      queryParameters: {'partId': partId},
    ).toString();

    final response = await _get(path);
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(PartLinesResponse.fromJson(response.data!));
  }

  Future<ApiResult<ReceiptLineResponse>> scanReceiptPart({
    required String poId,
    required String partId,
    required int lineId,
    required int qtyReceived,
    required String operatorId,
    List<String>? serialNumbers,
    String? palletId,
  }) async {
    final response = await _post('/receiving/scan-part', {
      'poId': poId,
      'partId': partId,
      'lineId': lineId,
      'qtyReceived': qtyReceived,
      'operatorId': operatorId,
      // serialRequire=false ต้องส่ง null/[] ไม่ require เสมอ (ฝั่ง backend รองรับทั้งคู่)
      'serialNumbers': serialNumbers ?? [],
      if (palletId != null) 'palletId': palletId,
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
