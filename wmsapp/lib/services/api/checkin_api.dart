part of '../api_service.dart';

extension CheckInApi on ApiService {
  /// Preview Pack ก่อน Check-IN (ไม่เขียน DB)
  Future<ApiResult<PreviewCheckInResponse>> previewCheckIn(
      String packingId) async {
    final response = await _post('/checkin/preview', {
      'packingId': packingId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(PreviewCheckInResponse.fromJson(response.data!));
  }

  /// สแกน Carton (PackingId) → assign Slot ตาม Owner
  Future<ApiResult<ScanCheckInResponse>> scanCheckIn({
    required String packingId,
    required String operatorId,
  }) async {
    final response = await _post('/checkin/scan', {
      'packingId': packingId,
      'operatorId': operatorId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(ScanCheckInResponse.fromJson(response.data!));
  }

  /// ดึงรายละเอียด Slot (cartons ทั้งหมด + progress)
  Future<ApiResult<CheckInSlotDetail>> getCheckInSlot(String slotId) async {
    final response = await _get('/checkin/slot/$slotId');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(CheckInSlotDetail.fromJson(response.data!));
  }

  /// รายการ Slot ที่ active (OPEN/READY)
  Future<ApiResult<List<CheckInSlotSummary>>> getActiveCheckInSlots() async {
    final response = await _get('/checkin/slots');
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    final items = (response.data!['items'] as List? ?? [])
        .map((e) => CheckInSlotSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    return ApiResult.success(items);
  }

  /// Complete Slot → generate Tracking ID
  Future<ApiResult<CompleteCheckInResponse>> completeCheckIn({
    required String slotId,
    required String operatorId,
  }) async {
    final response = await _post('/checkin/complete', {
      'slotId': slotId,
      'operatorId': operatorId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(CompleteCheckInResponse.fromJson(response.data!));
  }

  /// Dispatch Slot → ย้ายขึ้นรถ SHIPPED
  Future<ApiResult<DispatchCheckInResponse>> dispatchCheckIn({
    required String slotId,
    required String operatorId,
  }) async {
    final response = await _post('/checkin/dispatch', {
      'slotId': slotId,
      'operatorId': operatorId,
    });
    if (!response.success) {
      return ApiResult.error(response.error, statusCode: response.statusCode);
    }
    return ApiResult.success(DispatchCheckInResponse.fromJson(response.data!));
  }
}
