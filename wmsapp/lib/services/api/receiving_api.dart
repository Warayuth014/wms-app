part of '../api_service.dart';

extension ReceivingApi on ApiService {
  Future<ApiResult<POResponse>> getPO(String poId) async {
    final response = await _get('/receiving/po/$poId');
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(POResponse.fromJson(response.data!));
  }

  Future<ApiResult<ReceivingSession>> openReceivingSession({
    required String poId,
    required String operatorId,
  }) async {
    final response = await _post('/receiving/open-session', {
      'poId': poId,
      'operatorId': operatorId,
    });
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(ReceivingSession.fromJson(response.data!));
  }

  Future<ReceivingSession?> getActiveReceivingSession(String poId) async {
    try {
      final base = await ApiService._resolveBase();
      final response = await http
          .get(
            Uri.parse('$base/receiving/active-session/$poId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return ReceivingSession.fromJson(body);
      }

      return null;
    } catch (_) {
      return null;
    }
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
    required int sessionId,
    required String poId,
    required String partId,
    required int qtyReceived,
    required String operatorId,
    List<String>? serialNumbers,
  }) async {
    final response = await _post('/receiving/scan-part', {
      'sessionId': sessionId,
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
    required int sessionId,
    required String palletId,
    required String palletType,
    required String operatorId,
    required List<int> lineIds,
  }) async {
    final response = await _post('/receiving/assign-pallet', {
      'sessionId': sessionId,
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

  Future<ApiResult<Map<String, dynamic>>> closeReceivingSession(
    int sessionId,
  ) async {
    final response = await _post('/receiving/close-session/$sessionId', {});
    if (!response.success) return ApiResult.error(response.error);

    return ApiResult.success(response.data!);
  }
}
