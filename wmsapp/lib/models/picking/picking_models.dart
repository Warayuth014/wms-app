// ── Return Pallet preview (popup ก่อน confirm) ──────
class ReturnPalletPreview {
  final String palletId;
  final String currentStatus;
  final String? currentLocation;
  final bool canReturn;
  final String? destination; // ASRS | ZONE_PACK | null
  final String reason;

  ReturnPalletPreview({
    required this.palletId,
    required this.currentStatus,
    this.currentLocation,
    required this.canReturn,
    this.destination,
    required this.reason,
  });

  factory ReturnPalletPreview.fromJson(Map<String, dynamic> json) =>
      ReturnPalletPreview(
        palletId: json['palletId'],
        currentStatus: json['currentStatus'] ?? '',
        currentLocation: json['currentLocation'],
        canReturn: json['canReturn'] ?? false,
        destination: json['destination'],
        reason: json['reason'] ?? '',
      );
}

// ── New flow: 2-page picking entry ─────────────────
// หน้า 1: list orders summary
class PickOrderListItem {
  final String pickOrderId;
  final String status;          // WAITING | PICKING
  final String owner;
  final String? customerOrderId;
  final int partCount;
  final int totalRequiredQty;
  final int palletCount;
  final DateTime createdAt;

  PickOrderListItem({
    required this.pickOrderId,
    required this.status,
    required this.owner,
    this.customerOrderId,
    required this.partCount,
    required this.totalRequiredQty,
    required this.palletCount,
    required this.createdAt,
  });

  factory PickOrderListItem.fromJson(Map<String, dynamic> json) =>
      PickOrderListItem(
        pickOrderId: json['pickOrderId'],
        status: json['status'] ?? 'WAITING',
        owner: json['owner'] ?? '',
        customerOrderId: json['customerOrderId'],
        partCount: json['partCount'] ?? 0,
        totalRequiredQty: json['totalRequiredQty'] ?? 0,
        palletCount: json['palletCount'] ?? 0,
        createdAt:
            DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );

  bool get isWaiting => status == 'WAITING';
  bool get isPicking => status == 'PICKING';
}

// หน้า 2: order detail (pallets + parts)
class PickOrderDetailFull {
  final String pickOrderId;
  final String status;
  final String owner;
  final String? customerOrderId;
  final DateTime createdAt;
  final List<PickOrderPalletInfo> pallets;
  final List<PickOrderPartInfo> parts;

  PickOrderDetailFull({
    required this.pickOrderId,
    required this.status,
    required this.owner,
    this.customerOrderId,
    required this.createdAt,
    required this.pallets,
    required this.parts,
  });

  factory PickOrderDetailFull.fromJson(Map<String, dynamic> json) =>
      PickOrderDetailFull(
        pickOrderId: json['pickOrderId'],
        status: json['status'] ?? 'WAITING',
        owner: json['owner'] ?? '',
        customerOrderId: json['customerOrderId'],
        createdAt:
            DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        pallets: ((json['pallets'] ?? []) as List)
            .map((e) => PickOrderPalletInfo.fromJson(e))
            .toList(),
        parts: ((json['parts'] ?? []) as List)
            .map((e) => PickOrderPartInfo.fromJson(e))
            .toList(),
      );
}

class PickOrderPalletInfo {
  final String palletId;
  final String palletStatus;
  final String? stationId;
  final String? stationName;
  final int partCount;
  final int totalQty;
  final List<PickOrderPalletPartInfo> parts;

  PickOrderPalletInfo({
    required this.palletId,
    required this.palletStatus,
    this.stationId,
    this.stationName,
    required this.partCount,
    required this.totalQty,
    required this.parts,
  });

  factory PickOrderPalletInfo.fromJson(Map<String, dynamic> json) =>
      PickOrderPalletInfo(
        palletId: json['palletId'],
        palletStatus: json['palletStatus'] ?? 'UNKNOWN',
        stationId: json['stationId'],
        stationName: json['stationName'],
        partCount: json['partCount'] ?? 0,
        totalQty: json['totalQty'] ?? 0,
        parts: ((json['parts'] ?? []) as List)
            .map((e) => PickOrderPalletPartInfo.fromJson(e))
            .toList(),
      );
}

class PickOrderPalletPartInfo {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final int allocatedQty;
  final int pickedQty;
  final String status;        // PENDING | PARTIAL | PICKED

  PickOrderPalletPartInfo({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    required this.allocatedQty,
    required this.pickedQty,
    required this.status,
  });

  factory PickOrderPalletPartInfo.fromJson(Map<String, dynamic> json) =>
      PickOrderPalletPartInfo(
        partId: json['partId'],
        owner: json['owner'] ?? '',
        brand: json['brand'] ?? '',
        itemDesc: json['itemDesc'] ?? '',
        imageUrl: json['imageUrl'],
        allocatedQty: json['allocatedQty'] ?? 0,
        pickedQty: json['pickedQty'] ?? 0,
        status: json['status'] ?? 'PENDING',
      );

  bool get isPicked => status == 'PICKED';
}

class PickOrderPartInfo {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final int requiredQty;
  final int reservedQty;
  final int remainingQty;
  final String status;

  PickOrderPartInfo({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    required this.requiredQty,
    required this.reservedQty,
    required this.remainingQty,
    required this.status,
  });

  factory PickOrderPartInfo.fromJson(Map<String, dynamic> json) =>
      PickOrderPartInfo(
        partId: json['partId'],
        owner: json['owner'] ?? '',
        brand: json['brand'] ?? '',
        itemDesc: json['itemDesc'] ?? '',
        imageUrl: json['imageUrl'],
        requiredQty: json['requiredQty'] ?? 0,
        reservedQty: json['reservedQty'] ?? 0,
        remainingQty: json['remainingQty'] ?? 0,
        status: json['status'] ?? 'PENDING',
      );
}

// Notify Arrival response
class NotifyArrivalResponse {
  final String pickOrderId;
  final String status;
  final List<NotifyArrivalAssignment> assignments;
  final String message;

  NotifyArrivalResponse({
    required this.pickOrderId,
    required this.status,
    required this.assignments,
    required this.message,
  });

  factory NotifyArrivalResponse.fromJson(Map<String, dynamic> json) =>
      NotifyArrivalResponse(
        pickOrderId: json['pickOrderId'],
        status: json['status'] ?? 'PICKING',
        assignments: ((json['assignments'] ?? []) as List)
            .map((e) => NotifyArrivalAssignment.fromJson(e))
            .toList(),
        message: json['message'] ?? '',
      );
}

class NotifyArrivalAssignment {
  final String palletId;
  final String? stationId;
  final String outcome;       // ASSIGNED | ALREADY_AT_STATION | NO_FREE_STATION

  NotifyArrivalAssignment({
    required this.palletId,
    this.stationId,
    required this.outcome,
  });

  factory NotifyArrivalAssignment.fromJson(Map<String, dynamic> json) =>
      NotifyArrivalAssignment(
        palletId: json['palletId'],
        stationId: json['stationId'],
        outcome: json['outcome'] ?? 'ASSIGNED',
      );
}

class PickOrderDetail {
  final int id;
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final int requiredQty;
  final int reservedQty;
  final int remainingQty;
  final String status;

  PickOrderDetail({
    required this.id,
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    required this.requiredQty,
    required this.reservedQty,
    required this.remainingQty,
    required this.status,
  });

  factory PickOrderDetail.fromJson(Map<String, dynamic> json) => PickOrderDetail(
    id: json['id'],
    partId: json['partId'],
    owner: json['owner'],
    brand: json['brand'],
    itemDesc: json['itemDesc'],
    imageUrl: json['imageUrl'],
    requiredQty: json['requiredQty'],
    reservedQty: json['reservedQty'],
    remainingQty: json['remainingQty'],
    status: json['status'],
  );
}

class AssignPickStationResponse {
  final String stationId;
  final String stationName;
  final String palletId;
  final String pickOrderId;
  final List<PickItemOnPallet> palletItems;
  final List<PickOrderDetail> pickOrderItems;
  final String message;

  AssignPickStationResponse({
    required this.stationId,
    required this.stationName,
    required this.palletId,
    required this.pickOrderId,
    required this.palletItems,
    required this.pickOrderItems,
    required this.message,
  });

  factory AssignPickStationResponse.fromJson(Map<String, dynamic> json) =>
      AssignPickStationResponse(
        stationId: json['stationId'],
        stationName: json['stationName'],
        palletId: json['palletId'],
        pickOrderId: json['pickOrderId'],
        palletItems: (json['palletItems'] as List)
            .map((item) => PickItemOnPallet.fromJson(item))
            .toList(),
        pickOrderItems: (json['pickOrderItems'] as List)
            .map((item) => PickOrderDetail.fromJson(item))
            .toList(),
        message: json['message'],
      );
}

class PickItemOnPallet {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final String? lotNumber;
  final int qtyOnPallet;
  final int qtyToPickSuggested;
  final String condition;
  final bool serialRequire;
  final List<String> availableSerials;

  PickItemOnPallet({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    this.lotNumber,
    required this.qtyOnPallet,
    required this.qtyToPickSuggested,
    required this.condition,
    this.serialRequire = false,
    this.availableSerials = const [],
  });

  factory PickItemOnPallet.fromJson(Map<String, dynamic> json) => PickItemOnPallet(
    partId: json['partId'],
    owner: json['owner'],
    brand: json['brand'],
    itemDesc: json['itemDesc'],
    imageUrl: json['imageUrl'],
    lotNumber: json['lotNumber'],
    qtyOnPallet: json['qtyOnPallet'],
    qtyToPickSuggested: json['qtyToPickSuggested'],
    condition: json['condition'],
    serialRequire: json['serialRequire'] ?? false,
    availableSerials: (json['availableSerials'] as List? ?? [])
        .map((serial) => serial.toString())
        .toList(),
  );
}

class ConfirmPickResponse {
  final bool isPickOrderComplete;
  final bool sourcePalletEmpty;
  final bool sourcePickDone;
  final String pickOrderStatus;
  final List<PickRemainingItem> remainingItems;
  final String message;

  ConfirmPickResponse({
    required this.isPickOrderComplete,
    required this.sourcePalletEmpty,
    required this.sourcePickDone,
    required this.pickOrderStatus,
    required this.remainingItems,
    required this.message,
  });

  factory ConfirmPickResponse.fromJson(Map<String, dynamic> json) =>
      ConfirmPickResponse(
        isPickOrderComplete: json['isPickOrderComplete'],
        sourcePalletEmpty: json['sourcePalletEmpty'],
        sourcePickDone: json['sourcePickDone'] ?? false,
        pickOrderStatus: json['pickOrderStatus'],
        remainingItems: (json['remainingItems'] as List)
            .map((item) => PickRemainingItem.fromJson(item))
            .toList(),
        message: json['message'],
      );
}

class PickRemainingItem {
  final String partId;
  final String itemDesc;
  final int requiredQty;
  final int pickedQty;
  final int remainingQty;

  PickRemainingItem({
    required this.partId,
    required this.itemDesc,
    required this.requiredQty,
    required this.pickedQty,
    required this.remainingQty,
  });

  factory PickRemainingItem.fromJson(Map<String, dynamic> json) => PickRemainingItem(
    partId: json['partId'],
    itemDesc: json['itemDesc'],
    requiredQty: json['requiredQty'],
    pickedQty: json['pickedQty'],
    remainingQty: json['remainingQty'],
  );
}
