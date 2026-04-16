// ── Scan Carton ──────────────────────────────────
class ScanCheckInResponse {
  final String slotId;
  final String owner;
  final String packingId;
  final int cartonsInSlot;
  final int expectedCartons;
  final bool isReadyToComplete;
  final String message;

  ScanCheckInResponse({
    required this.slotId,
    required this.owner,
    required this.packingId,
    required this.cartonsInSlot,
    required this.expectedCartons,
    required this.isReadyToComplete,
    required this.message,
  });

  factory ScanCheckInResponse.fromJson(Map<String, dynamic> json) =>
      ScanCheckInResponse(
        slotId: json['slotId'],
        owner: json['owner'],
        packingId: json['packingId'],
        cartonsInSlot: json['cartonsInSlot'] ?? 0,
        expectedCartons: json['expectedCartons'] ?? 0,
        isReadyToComplete: json['isReadyToComplete'] ?? false,
        message: json['message'] ?? '',
      );
}

// ── Slot Detail ──────────────────────────────────
class CheckInSlotDetail {
  final String slotId;
  final String owner;
  final String status;
  final String? trackingId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int cartonsInSlot;
  final int expectedCartons;
  final bool isReadyToComplete;
  final List<CheckInCartonItem> cartons;

  CheckInSlotDetail({
    required this.slotId,
    required this.owner,
    required this.status,
    this.trackingId,
    required this.createdAt,
    this.completedAt,
    required this.cartonsInSlot,
    required this.expectedCartons,
    required this.isReadyToComplete,
    required this.cartons,
  });

  factory CheckInSlotDetail.fromJson(Map<String, dynamic> json) =>
      CheckInSlotDetail(
        slotId: json['slotId'],
        owner: json['owner'],
        status: json['status'],
        trackingId: json['trackingId'],
        createdAt:
            DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'])
            : null,
        cartonsInSlot: json['cartonsInSlot'] ?? 0,
        expectedCartons: json['expectedCartons'] ?? 0,
        isReadyToComplete: json['isReadyToComplete'] ?? false,
        cartons: (json['cartons'] as List)
            .map((c) => CheckInCartonItem.fromJson(c))
            .toList(),
      );
}

class CheckInCartonItem {
  final String packingId;
  final String palletId;
  final String status;
  final DateTime scannedAt;

  CheckInCartonItem({
    required this.packingId,
    required this.palletId,
    required this.status,
    required this.scannedAt,
  });

  factory CheckInCartonItem.fromJson(Map<String, dynamic> json) =>
      CheckInCartonItem(
        packingId: json['packingId'],
        palletId: json['palletId'] ?? '',
        status: json['status'] ?? '',
        scannedAt:
            DateTime.tryParse(json['scannedAt'] ?? '') ?? DateTime.now(),
      );
}

// ── Slot Summary (list) ──────────────────────────────────
class CheckInSlotSummary {
  final String slotId;
  final String owner;
  final String status;
  final int cartonsInSlot;
  final int expectedCartons;
  final DateTime createdAt;

  CheckInSlotSummary({
    required this.slotId,
    required this.owner,
    required this.status,
    required this.cartonsInSlot,
    required this.expectedCartons,
    required this.createdAt,
  });

  factory CheckInSlotSummary.fromJson(Map<String, dynamic> json) =>
      CheckInSlotSummary(
        slotId: json['slotId'],
        owner: json['owner'],
        status: json['status'],
        cartonsInSlot: json['cartonsInSlot'] ?? 0,
        expectedCartons: json['expectedCartons'] ?? 0,
        createdAt:
            DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );

  bool get isReady =>
      status == 'READY' ||
      (expectedCartons > 0 && cartonsInSlot >= expectedCartons);
}

// ── Complete response ──────────────────────────────────
class CompleteCheckInResponse {
  final String slotId;
  final String owner;
  final String trackingId;
  final DateTime completedAt;
  final int cartonsCount;
  final String message;

  CompleteCheckInResponse({
    required this.slotId,
    required this.owner,
    required this.trackingId,
    required this.completedAt,
    required this.cartonsCount,
    required this.message,
  });

  factory CompleteCheckInResponse.fromJson(Map<String, dynamic> json) =>
      CompleteCheckInResponse(
        slotId: json['slotId'],
        owner: json['owner'],
        trackingId: json['trackingId'],
        completedAt:
            DateTime.tryParse(json['completedAt'] ?? '') ?? DateTime.now(),
        cartonsCount: json['cartonsCount'] ?? 0,
        message: json['message'] ?? '',
      );
}

// ── Dispatch response ──────────────────────────────────
class DispatchCheckInResponse {
  final String slotId;
  final String owner;
  final DateTime shippedAt;
  final int cartonsCount;
  final String message;

  DispatchCheckInResponse({
    required this.slotId,
    required this.owner,
    required this.shippedAt,
    required this.cartonsCount,
    required this.message,
  });

  factory DispatchCheckInResponse.fromJson(Map<String, dynamic> json) =>
      DispatchCheckInResponse(
        slotId: json['slotId'],
        owner: json['owner'],
        shippedAt:
            DateTime.tryParse(json['shippedAt'] ?? '') ?? DateTime.now(),
        cartonsCount: json['cartonsCount'] ?? 0,
        message: json['message'] ?? '',
      );
}
