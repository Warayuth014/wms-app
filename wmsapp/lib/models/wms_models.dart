// lib/models/wms_models.dart

// =============================================
// User
// =============================================
class User {
  final String userId;
  final String fullName;
  final String role; // OPERATOR | SUPERVISOR

  User({required this.userId, required this.fullName, required this.role});

  factory User.fromJson(Map<String, dynamic> json) => User(
    userId: json['userId'],
    fullName: json['fullName'],
    role: json['role'],
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'fullName': fullName,
    'role': role,
  };
}

// =============================================
// Part (Master)
// =============================================
class Part {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;

  Part({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
  });

  factory Part.fromJson(Map<String, dynamic> json) => Part(
    partId: json['partId'],
    owner: json['owner'],
    brand: json['brand'],
    itemDesc: json['itemDesc'],
    imageUrl: json['imageUrl'],
  );
}

// =============================================
// PO
// =============================================
class POResponse {
  final String poId;
  final String supplierId;
  final String supplierName;
  final String status;
  final DateTime createdAt;
  final List<POItem> items;

  POResponse({
    required this.poId,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory POResponse.fromJson(Map<String, dynamic> json) => POResponse(
    poId: json['poId'],
    supplierId: json['supplierId'],
    supplierName: json['supplierName'],
    status: json['status'],
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
        : DateTime.now(),
    items: (json['items'] as List).map((i) => POItem.fromJson(i)).toList(),
  );
}

class POItem {
  final int id;
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final int qtyOrdered;
  final int qtyReceived;
  final int qtyRemaining;
  final String status;
  final String condition;
  final String? lotNumber;
  final String? expiredDate;

  POItem({
    required this.id,
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    required this.qtyOrdered,
    required this.qtyReceived,
    required this.qtyRemaining,
    required this.status,
    required this.condition,
    this.lotNumber,
    this.expiredDate,
  });

  factory POItem.fromJson(Map<String, dynamic> json) => POItem(
    id: json['id'],
    partId: json['partId'],
    owner: json['owner'],
    brand: json['brand'],
    itemDesc: json['itemDesc'],
    imageUrl: json['imageUrl'],
    qtyOrdered: json['qtyOrdered'],
    qtyReceived: json['qtyReceived'],
    qtyRemaining: json['qtyRemaining'] ?? 0,
    status: json['status'],
    condition: json['condition'] ?? 'FG',
    lotNumber: json['lotNumber'],
    expiredDate: json['expiredDate'],
  );
}

// =============================================
// Receiving
// =============================================
class ReceivingSession {
  final int sessionId;
  final String poId;
  final String supplierName;
  final String status;
  final List<POItem> pendingItems;
  final List<ReceiptLineResponse> pendingLines;

  ReceivingSession({
    required this.sessionId,
    required this.poId,
    required this.supplierName,
    required this.status,
    required this.pendingItems,
    this.pendingLines = const [],
  });

  factory ReceivingSession.fromJson(Map<String, dynamic> json) =>
      ReceivingSession(
        sessionId: json['sessionId'],
        poId: json['poId'],
        supplierName: json['supplierName'],
        status: json['status'],
        pendingItems: (json['pendingItems'] as List)
            .map((i) => POItem.fromJson(i))
            .toList(),
        pendingLines: (json['pendingLines'] as List? ?? [])
            .map((l) => ReceiptLineResponse.fromJson(l))
            .toList(),
      );
}

class ReceiptLineResponse {
  final int lineId;
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final int qtyOrdered;
  final int qtyReceived;
  final String condition;
  final String? lotNumber;
  final String poItemStatus;
  final String message;

  ReceiptLineResponse({
    required this.lineId,
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    required this.qtyOrdered,
    required this.qtyReceived,
    required this.condition,
    this.lotNumber,
    required this.poItemStatus,
    required this.message,
  });

  factory ReceiptLineResponse.fromJson(Map<String, dynamic> json) =>
      ReceiptLineResponse(
        lineId: json['lineId'],
        partId: json['partId'],
        owner: json['owner'],
        brand: json['brand'],
        itemDesc: json['itemDesc'],
        imageUrl: json['imageUrl'],
        qtyOrdered: json['qtyOrdered'],
        qtyReceived: json['qtyReceived'],
        condition: json['condition'],
        lotNumber: json['lotNumber'],
        poItemStatus: json['poItemStatus'],
        message: json['message'],
      );
}

// =============================================
// Pallet
// =============================================
class PalletScanResponse {
  final String palletId;
  final String type;
  final String status;
  final bool needsLabeling;
  final List<UnloadItem> items;
  final String message;

  PalletScanResponse({
    required this.palletId,
    required this.type,
    required this.status,
    required this.needsLabeling,
    required this.items,
    required this.message,
  });

  factory PalletScanResponse.fromJson(Map<String, dynamic> json) =>
      PalletScanResponse(
        palletId: json['palletId'],
        type: json['type'],
        status: json['status'],
        needsLabeling: json['needsLabeling'],
        items: (json['items'] as List)
            .map((i) => UnloadItem.fromJson(i))
            .toList(),
        message: json['message'],
      );
}

class UnloadItem {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final String? lotNumber;
  final String? expiredDate;
  final int qty;
  final String condition;

  UnloadItem({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    this.lotNumber,
    this.expiredDate,
    required this.qty,
    required this.condition,
  });

  factory UnloadItem.fromJson(Map<String, dynamic> json) => UnloadItem(
    partId: json['partId'],
    owner: json['owner'],
    brand: json['brand'],
    itemDesc: json['itemDesc'],
    imageUrl: json['imageUrl'],
    lotNumber: json['lotNumber'],
    expiredDate: json['expiredDate'],
    qty: json['qty'],
    condition: json['condition'],
  );
}

// =============================================
// Unload Session
// =============================================
class UnloadSession {
  final int sessionId;
  final String palletId;
  final String status;
  final List<UnloadItem> items;
  final List<String> confirmedPartIds;

  UnloadSession({
    required this.sessionId,
    required this.palletId,
    required this.status,
    required this.items,
    this.confirmedPartIds = const [],
  });

  factory UnloadSession.fromJson(Map<String, dynamic> json) => UnloadSession(
    sessionId: json['sessionId'],
    palletId: json['palletId'],
    status: json['status'],
    items: (json['items'] as List).map((i) => UnloadItem.fromJson(i)).toList(),
    confirmedPartIds: (json['confirmedPartIds'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}

// =============================================
// Basket
// =============================================
class BasketScanResponse {
  final String basketId;
  final String label;
  final String? zone;
  final String? destination;
  final String status;
  final String message;

  BasketScanResponse({
    required this.basketId,
    required this.label,
    this.zone,
    this.destination,
    required this.status,
    required this.message,
  });

  factory BasketScanResponse.fromJson(Map<String, dynamic> json) =>
      BasketScanResponse(
        basketId: json['basketId'],
        label: json['label'],
        zone: json['zone'],
        destination: json['destination'],
        status: json['status'],
        message: json['message'],
      );
}

// =============================================
// Cancel Log
// =============================================
class CancelLog {
  final int cancelId;
  final String refType;
  final int refId;
  final String reason;
  final String requestBy;
  final String? approvedBy;
  final String status;

  CancelLog({
    required this.cancelId,
    required this.refType,
    required this.refId,
    required this.reason,
    required this.requestBy,
    this.approvedBy,
    required this.status,
  });

  factory CancelLog.fromJson(Map<String, dynamic> json) => CancelLog(
    cancelId: json['cancelId'],
    refType: json['refType'],
    refId: json['refId'],
    reason: json['reason'],
    requestBy: json['requestBy'],
    approvedBy: json['approvedBy'],
    status: json['status'],
  );
}

// ── Return Models ─────────────────────────

class OrderResponse {
  final String orderId;
  final String customerId;
  final String customerName;
  final String status;
  final DateTime createdAt;
  final List<OrderItemResponse> items;

  OrderResponse({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> j) => OrderResponse(
    orderId: j['orderId'],
    customerId: j['customerId'],
    customerName: j['customerName'],
    status: j['status'],
    createdAt: DateTime.parse(j['createdAt']),
    items: (j['items'] as List)
        .map((i) => OrderItemResponse.fromJson(i))
        .toList(),
  );
}

class OrderItemResponse {
  final int id;
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final int qtySold;
  String status;

  OrderItemResponse({
    required this.id,
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    required this.qtySold,
    required this.status,
  });

  factory OrderItemResponse.fromJson(Map<String, dynamic> j) =>
      OrderItemResponse(
        id: j['id'],
        partId: j['partId'],
        owner: j['owner'],
        brand: j['brand'],
        itemDesc: j['itemDesc'],
        imageUrl: j['imageUrl'],
        qtySold: j['qtySold'],
        status: j['status'],
      );

  OrderItemResponse copyWith({String? status}) => OrderItemResponse(
    id: id,
    partId: partId,
    owner: owner,
    brand: brand,
    itemDesc: itemDesc,
    imageUrl: imageUrl,
    qtySold: qtySold,
    status: status ?? this.status,
  );
}

class OpenReturnResponse {
  final int returnId;
  final String orderId;
  final String customerName;
  final String status;
  final List<OrderItemResponse> items;

  OpenReturnResponse({
    required this.returnId,
    required this.orderId,
    required this.customerName,
    required this.status,
    required this.items,
  });

  factory OpenReturnResponse.fromJson(Map<String, dynamic> j) =>
      OpenReturnResponse(
        returnId: j['returnId'],
        orderId: j['orderId'],
        customerName: j['customerName'],
        status: j['status'],
        items: (j['items'] as List)
            .map((i) => OrderItemResponse.fromJson(i))
            .toList(),
      );
}

class ReceiveReturnItemResponse {
  final int lineId;
  final String partId;
  final int qtyReturned;
  final String status;
  final String message;

  ReceiveReturnItemResponse({
    required this.lineId,
    required this.partId,
    required this.qtyReturned,
    required this.status,
    required this.message,
  });

  factory ReceiveReturnItemResponse.fromJson(Map<String, dynamic> j) =>
      ReceiveReturnItemResponse(
        lineId: j['lineId'],
        partId: j['partId'],
        qtyReturned: j['qtyReturned'],
        status: j['status'],
        message: j['message'],
      );
}

class CloseReturnResponse {
  final bool success;
  final String orderStatus;
  final String message;
  final int totalParts;
  final int returnedParts;

  CloseReturnResponse({
    required this.success,
    required this.orderStatus,
    required this.message,
    required this.totalParts,
    required this.returnedParts,
  });

  factory CloseReturnResponse.fromJson(Map<String, dynamic> j) =>
      CloseReturnResponse(
        success: j['success'],
        orderStatus: j['orderStatus'],
        message: j['message'],
        totalParts: j['totalParts'],
        returnedParts: j['returnedParts'],
      );
}

class LoadedBasketItem {
  final int lineId;
  final String partId;
  final String palletId;
  final String owner;
  final String itemDesc;
  final int qtyLoaded;
  final String? lotNumber;
  final String basketId;
  final String basketLabel;
  final String? basketDestination;

  LoadedBasketItem({
    required this.lineId,
    required this.partId,
    required this.palletId,
    required this.owner,
    required this.itemDesc,
    required this.qtyLoaded,
    this.lotNumber,
    required this.basketId,
    required this.basketLabel,
    this.basketDestination,
  });

  factory LoadedBasketItem.fromJson(Map<String, dynamic> j) => LoadedBasketItem(
    lineId: j['lineId'],
    partId: j['partId'],
    palletId: j['palletId'],
    owner: j['owner'],
    itemDesc: j['itemDesc'],
    qtyLoaded: j['qtyLoaded'],
    lotNumber: j['lotNumber'],
    basketId: j['basketId'],
    basketLabel: j['basketLabel'],
    basketDestination: j['basketDestination'],
  );
}

// =============================================
// Putaway
// =============================================
class PutawayPalletInfo {
  final String palletId;
  final String type; // FG | PW
  final String status;
  final String suggestedDestination; // ASRS | PREWORK
  final List<UnloadItem> items;
  final String message;

  PutawayPalletInfo({
    required this.palletId,
    required this.type,
    required this.status,
    required this.suggestedDestination,
    required this.items,
    required this.message,
  });

  factory PutawayPalletInfo.fromJson(Map<String, dynamic> json) =>
      PutawayPalletInfo(
        palletId: json['palletId'],
        type: json['type'],
        status: json['status'],
        suggestedDestination: json['suggestedDestination'] ?? 'ASRS',
        items: (json['items'] as List)
            .map((i) => UnloadItem.fromJson(i))
            .toList(),
        message: json['message'] ?? '',
      );
}

class PutawayResult {
  final bool success;
  final String palletId;
  final String stationId;
  final String destination;
  final String message;

  PutawayResult({
    required this.success,
    required this.palletId,
    required this.stationId,
    required this.destination,
    required this.message,
  });

  factory PutawayResult.fromJson(Map<String, dynamic> json) => PutawayResult(
    success: json['success'] ?? true,
    palletId: json['palletId'],
    stationId: json['stationId'],
    destination: json['destination'],
    message: json['message'],
  );
}

// =============================================
// Picking
// =============================================
class PickingSession {
  final int sessionId;
  final String packPalletId;
  final String status;
  final List<PickingLineItem> pickedLines;

  PickingSession({
    required this.sessionId,
    required this.packPalletId,
    required this.status,
    this.pickedLines = const [],
  });

  factory PickingSession.fromJson(Map<String, dynamic> json) => PickingSession(
    sessionId: json['sessionId'],
    packPalletId: json['packPalletId'],
    status: json['status'],
    pickedLines: (json['pickedLines'] as List? ?? [])
        .map((l) => PickingLineItem.fromJson(l))
        .toList(),
  );
}

class PickingLineItem {
  final int lineId;
  final String sourceId;
  final String sourceType;   // PALLET | BASKET
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? lotNumber;
  final String? expiredDate;
  final int qtyPicked;
  final String status;

  PickingLineItem({
    required this.lineId,
    required this.sourceId,
    required this.sourceType,
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.lotNumber,
    this.expiredDate,
    required this.qtyPicked,
    required this.status,
  });

  factory PickingLineItem.fromJson(Map<String, dynamic> json) =>
      PickingLineItem(
        lineId: json['lineId'],
        sourceId: json['sourceId'],
        sourceType: json['sourceType'] ?? 'PALLET',
        partId: json['partId'],
        owner: json['owner'],
        brand: json['brand'],
        itemDesc: json['itemDesc'],
        lotNumber: json['lotNumber'],
        expiredDate: json['expiredDate'],
        qtyPicked: json['qtyPicked'],
        status: json['status'],
      );
}

class ScanSourceResponse {
  final String sourceId;
  final String sourceType;   // PALLET | BASKET
  final String type;
  final String status;
  final List<SourceItem> items;
  final String message;

  ScanSourceResponse({
    required this.sourceId,
    required this.sourceType,
    required this.type,
    required this.status,
    required this.items,
    required this.message,
  });

  factory ScanSourceResponse.fromJson(Map<String, dynamic> json) =>
      ScanSourceResponse(
        sourceId: json['sourceId'],
        sourceType: json['sourceType'],
        type: json['type'],
        status: json['status'],
        items: (json['items'] as List)
            .map((i) => SourceItem.fromJson(i))
            .toList(),
        message: json['message'],
      );
}

class SourceItem {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final String? lotNumber;
  final String? expiredDate;
  final int qty;
  final String condition;

  SourceItem({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    this.lotNumber,
    this.expiredDate,
    required this.qty,
    required this.condition,
  });

  factory SourceItem.fromJson(Map<String, dynamic> json) => SourceItem(
    partId: json['partId'],
    owner: json['owner'],
    brand: json['brand'],
    itemDesc: json['itemDesc'],
    imageUrl: json['imageUrl'],
    lotNumber: json['lotNumber'],
    expiredDate: json['expiredDate'],
    qty: json['qty'],
    condition: json['condition'],
  );
}

class PickItemResult {
  final bool success;
  final int lineId;
  final String partId;
  final int qtyPicked;
  final int remainingOnSource;
  final String message;

  PickItemResult({
    required this.success,
    required this.lineId,
    required this.partId,
    required this.qtyPicked,
    required this.remainingOnSource,
    required this.message,
  });

  factory PickItemResult.fromJson(Map<String, dynamic> json) => PickItemResult(
    success: json['success'],
    lineId: json['lineId'],
    partId: json['partId'],
    qtyPicked: json['qtyPicked'],
    remainingOnSource: json['remainingOnSource'],
    message: json['message'],
  );
}

class CompletePickingResult {
  final bool success;
  final int totalItemsPicked;
  final String packPalletId;
  final String message;

  CompletePickingResult({
    required this.success,
    required this.totalItemsPicked,
    required this.packPalletId,
    required this.message,
  });

  factory CompletePickingResult.fromJson(Map<String, dynamic> json) =>
      CompletePickingResult(
        success: json['success'],
        totalItemsPicked: json['totalItemsPicked'],
        packPalletId: json['packPalletId'],
        message: json['message'],
      );
}

// =============================================
// Pending Pallet Line (ค้างการผูก Pallet)
// =============================================
class PendingPalletLine {
  final int lineId;
  final int sessionId;
  final String poId;
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final int qtyReceived;
  final String condition;
  final String? lotNumber;
  final DateTime receivedAt;

  PendingPalletLine({
    required this.lineId,
    required this.sessionId,
    required this.poId,
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    required this.qtyReceived,
    required this.condition,
    this.lotNumber,
    required this.receivedAt,
  });

  factory PendingPalletLine.fromJson(Map<String, dynamic> j) => PendingPalletLine(
    lineId: j['lineId'],
    sessionId: j['sessionId'],
    poId: j['poId'],
    partId: j['partId'],
    owner: j['owner'],
    brand: j['brand'],
    itemDesc: j['itemDesc'],
    imageUrl: j['imageUrl'],
    qtyReceived: j['qtyReceived'],
    condition: j['condition'],
    lotNumber: j['lotNumber'],
    receivedAt: DateTime.tryParse(j['receivedAt'] ?? '') ?? DateTime.now(),
  );
}

// =============================================
// Picking v2 — Pick Order flow
// =============================================

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

  int get totalRequired => details.fold(0, (s, d) => s + d.requiredQty);
  int get totalPicked   => details.fold(0, (s, d) => s + d.reservedQty);

  factory PickOrder.fromJson(Map<String, dynamic> j) => PickOrder(
    pickOrderId: j['pickOrderId'],
    status: j['status'],
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
    details: (j['details'] as List)
        .map((d) => PickOrderDetail.fromJson(d))
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

  factory PickOrderDetail.fromJson(Map<String, dynamic> j) => PickOrderDetail(
    id: j['id'],
    partId: j['partId'],
    owner: j['owner'],
    brand: j['brand'],
    itemDesc: j['itemDesc'],
    imageUrl: j['imageUrl'],
    requiredQty: j['requiredQty'],
    reservedQty: j['reservedQty'],
    remainingQty: j['remainingQty'],
    status: j['status'],
    subs: (j['subs'] as List? ?? [])
        .map((s) => PickOrderSub.fromJson(s))
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

  factory PickOrderSub.fromJson(Map<String, dynamic> j) => PickOrderSub(
    id: j['id'],
    pickOrderDetailId: j['pickOrderDetailId'],
    receiptLineId: j['receiptLineId'],
    palletId: j['palletId'],
    allocatedQty: j['allocatedQty'],
    pickedQty: j['pickedQty'],
    status: j['status'],
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

  factory AssignPickStationResponse.fromJson(Map<String, dynamic> j) =>
      AssignPickStationResponse(
        stationId: j['stationId'],
        stationName: j['stationName'],
        palletId: j['palletId'],
        pickOrderId: j['pickOrderId'],
        palletItems: (j['palletItems'] as List)
            .map((i) => PickItemOnPallet.fromJson(i))
            .toList(),
        pickOrderItems: (j['pickOrderItems'] as List)
            .map((i) => PickOrderDetail.fromJson(i))
            .toList(),
        message: j['message'],
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

  factory PickItemOnPallet.fromJson(Map<String, dynamic> j) => PickItemOnPallet(
    partId: j['partId'],
    owner: j['owner'],
    brand: j['brand'],
    itemDesc: j['itemDesc'],
    imageUrl: j['imageUrl'],
    lotNumber: j['lotNumber'],
    qtyOnPallet: j['qtyOnPallet'],
    qtyToPickSuggested: j['qtyToPickSuggested'],
    condition: j['condition'],
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

  factory ConfirmPickResponse.fromJson(Map<String, dynamic> j) =>
      ConfirmPickResponse(
        isPickOrderComplete: j['isPickOrderComplete'],
        sourcePalletEmpty: j['sourcePalletEmpty'],
        sourcePickDone: j['sourcePickDone'] ?? false,
        pickOrderStatus: j['pickOrderStatus'],
        remainingItems: (j['remainingItems'] as List)
            .map((i) => PickRemainingItem.fromJson(i))
            .toList(),
        message: j['message'],
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

  factory PickRemainingItem.fromJson(Map<String, dynamic> j) => PickRemainingItem(
    partId: j['partId'],
    itemDesc: j['itemDesc'],
    requiredQty: j['requiredQty'],
    pickedQty: j['pickedQty'],
    remainingQty: j['remainingQty'],
  );
}

class GroupedUnloadItem {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final String? lotNumber;
  final int totalQty;

  GroupedUnloadItem({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    this.lotNumber,
    required this.totalQty,
  });

  factory GroupedUnloadItem.fromJson(Map<String, dynamic> j) =>
      GroupedUnloadItem(
        partId: j['partId'],
        owner: j['owner'],
        brand: j['brand'],
        itemDesc: j['itemDesc'],
        imageUrl: j['imageUrl'],
        lotNumber: j['lotNumber'],
        totalQty: j['totalQty'],
      );
}
