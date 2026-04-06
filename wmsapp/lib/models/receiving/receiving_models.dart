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

  factory PendingPalletLine.fromJson(Map<String, dynamic> json) =>
      PendingPalletLine(
        lineId: json['lineId'],
        sessionId: json['sessionId'],
        poId: json['poId'],
        partId: json['partId'],
        owner: json['owner'],
        brand: json['brand'],
        itemDesc: json['itemDesc'],
        imageUrl: json['imageUrl'],
        qtyReceived: json['qtyReceived'],
        condition: json['condition'],
        lotNumber: json['lotNumber'],
        receivedAt: DateTime.tryParse(json['receivedAt'] ?? '') ?? DateTime.now(),
      );
}
