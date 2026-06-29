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
  final int pipelineTotal;
  final int pickDone;
  final int packDone;
  final int sortingDone;
  final int checkInDone;

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
    this.pipelineTotal = 0,
    this.pickDone = 0,
    this.packDone = 0,
    this.sortingDone = 0,
    this.checkInDone = 0,
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
        pipelineTotal: json['pipelineTotal'] ?? 0,
        pickDone: json['pickDone'] ?? 0,
        packDone: json['packDone'] ?? 0,
        sortingDone: json['sortingDone'] ?? 0,
        checkInDone: json['checkInDone'] ?? 0,
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
  final bool isReadyToComplete;

  ScanCheckInResponse({
    required this.slotId,
    required this.isReadyToComplete,
  });

  factory ScanCheckInResponse.fromJson(Map<String, dynamic> json) =>
      ScanCheckInResponse(
        slotId: json['slotId'],
        isReadyToComplete: json['isReadyToComplete'] ?? false,
      );
}

// ── Slot Detail ──────────────────────────────────
class CheckInSlotDetail {
  final String status;
  final List<CheckInCartonItem> cartons;
  final String? customerOrderId;
  final int pipelineTotal;
  final int pickDone;
  final int packDone;
  final int sortingDone;
  final int checkInDone;

  CheckInSlotDetail({
    required this.status,
    required this.cartons,
    this.customerOrderId,
    this.pipelineTotal = 0,
    this.pickDone = 0,
    this.packDone = 0,
    this.sortingDone = 0,
    this.checkInDone = 0,
  });

  factory CheckInSlotDetail.fromJson(Map<String, dynamic> json) =>
      CheckInSlotDetail(
        status: json['status'],
        cartons: (json['cartons'] as List)
            .map((c) => CheckInCartonItem.fromJson(c))
            .toList(),
        customerOrderId: json['customerOrderId'],
        pipelineTotal: json['pipelineTotal'] ?? 0,
        pickDone: json['pickDone'] ?? 0,
        packDone: json['packDone'] ?? 0,
        sortingDone: json['sortingDone'] ?? 0,
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
