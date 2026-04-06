class PickOrder {
  final String pickOrderId;
  final String status;
  final DateTime createdAt;
  final List<PickOrderDetail> details;

  PickOrder({
    required this.pickOrderId,
    required this.status,
    required this.createdAt,
    required this.details,
  });

  int get totalRequired => details.fold(0, (sum, detail) => sum + detail.requiredQty);
  int get totalPicked => details.fold(0, (sum, detail) => sum + detail.reservedQty);

  factory PickOrder.fromJson(Map<String, dynamic> json) => PickOrder(
    pickOrderId: json['pickOrderId'],
    status: json['status'],
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    details: (json['details'] as List)
        .map((detail) => PickOrderDetail.fromJson(detail))
        .toList(),
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
  final List<PickOrderSub> subs;

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
    this.subs = const [],
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
    subs: (json['subs'] as List? ?? [])
        .map((sub) => PickOrderSub.fromJson(sub))
        .toList(),
  );
}

class PickOrderSub {
  final int id;
  final int pickOrderDetailId;
  final int receiptLineId;
  final String? palletId;
  final int allocatedQty;
  final int pickedQty;
  final String status;

  PickOrderSub({
    required this.id,
    required this.pickOrderDetailId,
    required this.receiptLineId,
    this.palletId,
    required this.allocatedQty,
    required this.pickedQty,
    required this.status,
  });

  factory PickOrderSub.fromJson(Map<String, dynamic> json) => PickOrderSub(
    id: json['id'],
    pickOrderDetailId: json['pickOrderDetailId'],
    receiptLineId: json['receiptLineId'],
    palletId: json['palletId'],
    allocatedQty: json['allocatedQty'],
    pickedQty: json['pickedQty'],
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
