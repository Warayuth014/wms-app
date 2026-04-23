// ── Preview (ยังไม่ commit) ──────────────────────────────────
class PreviewCheckInResponse {
  final String packingId;
  final String owner;
  final String? customerOrderId;
  final String packStatus;
  final int itemCount;
  final int orderCount;
  final List<String> pickOrderIds;
  final String slotId;
  final bool isNewSlot;
  final bool isAlreadyCheckedIn;
  final String? dispatchDestination;
  final List<PreviewCheckInItem> items;
  final String message;

  PreviewCheckInResponse({
    required this.packingId,
    required this.owner,
    this.customerOrderId,
    required this.packStatus,
    required this.itemCount,
    required this.orderCount,
    required this.pickOrderIds,
    required this.slotId,
    required this.isNewSlot,
    required this.isAlreadyCheckedIn,
    this.dispatchDestination,
    required this.items,
    required this.message,
  });

  factory PreviewCheckInResponse.fromJson(Map<String, dynamic> json) =>
      PreviewCheckInResponse(
        packingId: json['packingId'],
        owner: json['owner'] ?? '',
        customerOrderId: json['customerOrderId'],
        packStatus: json['packStatus'] ?? '',
        itemCount: json['itemCount'] ?? 0,
        orderCount: json['orderCount'] ?? 0,
        pickOrderIds: ((json['pickOrderIds'] ?? []) as List)
            .map((e) => e.toString())
            .toList(),
        slotId: json['slotId'],
        isNewSlot: json['isNewSlot'] ?? false,
        isAlreadyCheckedIn: json['isAlreadyCheckedIn'] ?? false,
        dispatchDestination: json['dispatchDestination'],
        items: ((json['items'] ?? []) as List)
            .map((e) => PreviewCheckInItem.fromJson(e))
            .toList(),
        message: json['message'] ?? '',
      );

  int get skuCount => items.length;
}

class PreviewCheckInItem {
  final String partId;
  final String itemDesc;
  final String brand;
  final String? imageUrl;
  final int qty;

  PreviewCheckInItem({
    required this.partId,
    required this.itemDesc,
    required this.brand,
    this.imageUrl,
    required this.qty,
  });

  factory PreviewCheckInItem.fromJson(Map<String, dynamic> json) =>
      PreviewCheckInItem(
        partId: json['partId'] ?? '',
        itemDesc: json['itemDesc'] ?? '',
        brand: json['brand'] ?? '',
        imageUrl: json['imageUrl'],
        qty: json['qty'] ?? 0,
      );
}

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
  final DateTime createdAt;
  final DateTime? completedAt;
  final int cartonsInSlot;
  final int expectedCartons;
  final bool isReadyToComplete;
  final List<CheckInCartonItem> cartons;
  final String? customerOrderId;
  final int pipelineTotal;
  final int pickDone;
  final int packDone;
  final int checkInDone;

  CheckInSlotDetail({
    required this.slotId,
    required this.owner,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.cartonsInSlot,
    required this.expectedCartons,
    required this.isReadyToComplete,
    required this.cartons,
    this.customerOrderId,
    this.pipelineTotal = 0,
    this.pickDone = 0,
    this.packDone = 0,
    this.checkInDone = 0,
  });

  factory CheckInSlotDetail.fromJson(Map<String, dynamic> json) =>
      CheckInSlotDetail(
        slotId: json['slotId'],
        owner: json['owner'],
        status: json['status'],
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
        customerOrderId: json['customerOrderId'],
        pipelineTotal: json['pipelineTotal'] ?? 0,
        pickDone: json['pickDone'] ?? 0,
        packDone: json['packDone'] ?? 0,
        checkInDone: json['checkInDone'] ?? 0,
      );
}

class CheckInCartonItem {
  final String packingId;
  final String? trackingId;
  final String status;
  final DateTime scannedAt;
  final int itemCount;
  final int orderCount;

  CheckInCartonItem({
    required this.packingId,
    this.trackingId,
    required this.status,
    required this.scannedAt,
    required this.itemCount,
    required this.orderCount,
  });

  factory CheckInCartonItem.fromJson(Map<String, dynamic> json) =>
      CheckInCartonItem(
        packingId: json['packingId'],
        trackingId: json['trackingId'],
        status: json['status'] ?? '',
        scannedAt:
            DateTime.tryParse(json['scannedAt'] ?? '') ?? DateTime.now(),
        itemCount: json['itemCount'] ?? 0,
        orderCount: json['orderCount'] ?? 0,
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
  final List<PackTrackingItem> trackings;
  final DateTime completedAt;
  final int cartonsCount;
  final String message;

  CompleteCheckInResponse({
    required this.slotId,
    required this.owner,
    required this.trackings,
    required this.completedAt,
    required this.cartonsCount,
    required this.message,
  });

  factory CompleteCheckInResponse.fromJson(Map<String, dynamic> json) =>
      CompleteCheckInResponse(
        slotId: json['slotId'],
        owner: json['owner'],
        trackings: ((json['trackings'] ?? []) as List)
            .map((t) => PackTrackingItem.fromJson(t))
            .toList(),
        completedAt:
            DateTime.tryParse(json['completedAt'] ?? '') ?? DateTime.now(),
        cartonsCount: json['cartonsCount'] ?? 0,
        message: json['message'] ?? '',
      );
}

class PackTrackingItem {
  final String packingId;
  final String? trackingId;

  PackTrackingItem({required this.packingId, this.trackingId});

  factory PackTrackingItem.fromJson(Map<String, dynamic> json) =>
      PackTrackingItem(
        packingId: json['packingId'],
        trackingId: json['trackingId'],
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
