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

  Part({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
  });

  factory Part.fromJson(Map<String, dynamic> json) => Part(
    partId: json['partId'],
    owner: json['owner'],
    brand: json['brand'],
    itemDesc: json['itemDesc'],
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
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) ?? DateTime.now() : DateTime.now(),
    items: (json['items'] as List).map((i) => POItem.fromJson(i)).toList(),
  );
}

class POItem {
  final int id;
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final int qtyOrdered;
  final int qtyReceived;
  final String status;

  POItem({
    required this.id,
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    required this.qtyOrdered,
    required this.qtyReceived,
    required this.status,
  });

  factory POItem.fromJson(Map<String, dynamic> json) => POItem(
    id: json['id'],
    partId: json['partId'],
    owner: json['owner'],
    brand: json['brand'],
    itemDesc: json['itemDesc'],
    qtyOrdered: json['qtyOrdered'],
    qtyReceived: json['qtyReceived'],
    status: json['status'],
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

  ReceivingSession({
    required this.sessionId,
    required this.poId,
    required this.supplierName,
    required this.status,
    required this.pendingItems,
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
      );
}

class ReceiptLineResponse {
  final int lineId;
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final int qtyOrdered;
  final int qtyReceived;
  final String condition;
  final String poItemStatus;
  final String message;

  ReceiptLineResponse({
    required this.lineId,
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    required this.qtyOrdered,
    required this.qtyReceived,
    required this.condition,
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
        qtyOrdered: json['qtyOrdered'],
        qtyReceived: json['qtyReceived'],
        condition: json['condition'],
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
  final String? lotNumber;
  final String? expiredDate;
  final int qty;
  final String condition;

  UnloadItem({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
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

  UnloadSession({
    required this.sessionId,
    required this.palletId,
    required this.status,
    required this.items,
  });

  factory UnloadSession.fromJson(Map<String, dynamic> json) => UnloadSession(
    sessionId: json['sessionId'],
    palletId: json['palletId'],
    status: json['status'],
    items: (json['items'] as List).map((i) => UnloadItem.fromJson(i)).toList(),
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
