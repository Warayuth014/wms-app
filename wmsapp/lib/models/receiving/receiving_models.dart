class POResponse {
  final String poId;
  final String supplierId;
  final String supplierName;
  final String status;
  final DateTime createdAt;
  final List<POItem> items;
  final List<ReceiptLineResponse> pendingLines;

  POResponse({
    required this.poId,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.createdAt,
    required this.items,
    this.pendingLines = const [],
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
    pendingLines: (json['pendingLines'] as List? ?? [])
        .map((l) => ReceiptLineResponse.fromJson(l))
        .toList(),
  );
}

class POItem {
  final int id;
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final bool serialRequire;
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
    this.serialRequire = false,
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
    serialRequire: json['serialRequire'] ?? false,
    qtyOrdered: json['qtyOrdered'],
    qtyReceived: json['qtyReceived'],
    qtyRemaining: json['qtyRemaining'] ?? 0,
    status: json['status'],
    condition: json['condition'] ?? 'FG',
    lotNumber: json['lotNumber'],
    expiredDate: json['expiredDate'],
  );
}

// ── สแกน Part ID ครั้งแรก (ยังไม่มี S/N) — เอาไว้เช็คว่ามีกี่ condition/lot ให้เลือก ──
class PartLinesResponse {
  final String partId;
  final bool serialRequire;
  final List<PartLine> lines;

  PartLinesResponse({
    required this.partId,
    required this.serialRequire,
    required this.lines,
  });

  factory PartLinesResponse.fromJson(Map<String, dynamic> json) =>
      PartLinesResponse(
        partId: json['partId'],
        serialRequire: json['serialRequire'] ?? false,
        lines: (json['lines'] as List? ?? [])
            .map((l) => PartLine.fromJson(l))
            .toList(),
      );
}

class PartLine {
  final int lineId;
  final String poId;
  final String condition;
  final List<PartLot> lots;

  PartLine({
    required this.lineId,
    required this.poId,
    required this.condition,
    required this.lots,
  });

  factory PartLine.fromJson(Map<String, dynamic> json) => PartLine(
    lineId: json['lineId'],
    poId: json['poId'],
    condition: json['condition'] ?? 'FG',
    lots: (json['lots'] as List? ?? [])
        .map((l) => PartLot.fromJson(l))
        .toList(),
  );
}

class PartLot {
  final int id;
  final String lotNumber;
  final int qtyOrdered;
  final int qtyReceived;

  PartLot({
    required this.id,
    required this.lotNumber,
    required this.qtyOrdered,
    required this.qtyReceived,
  });

  factory PartLot.fromJson(Map<String, dynamic> json) => PartLot(
    id: json['id'],
    lotNumber: json['lotNumber'],
    qtyOrdered: json['qtyOrdered'],
    qtyReceived: json['qtyReceived'] ?? 0,
  );
}

// ผล validate ตอนสแกน S/N — ใช้เช็คว่า S/N นี้เป็นของ lineId/lot ที่กำลังรับอยู่จริงไหม
class ValidateSerialResponse {
  final String partId;
  final String serialNo;
  final String status;
  final int? lineId;
  final String? poId;
  final String? condition;
  final String? lotNumber;

  ValidateSerialResponse({
    required this.partId,
    required this.serialNo,
    required this.status,
    this.lineId,
    this.poId,
    this.condition,
    this.lotNumber,
  });

  factory ValidateSerialResponse.fromJson(Map<String, dynamic> json) =>
      ValidateSerialResponse(
        partId: json['partId'],
        serialNo: json['serialNo'],
        status: json['status'],
        lineId: json['lineId'],
        poId: json['poId'],
        condition: json['condition'],
        lotNumber: json['lotNumber'],
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
  // ── ผลของการผูก Pallet (ถ้า scan-part ส่ง palletId มาด้วย) ──
  final String? palletId;
  final bool autoClosed;
  final String? poStatus;
  final String? closeMessage;
  final String? palletError;

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
    this.palletId,
    this.autoClosed = false,
    this.poStatus,
    this.closeMessage,
    this.palletError,
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
        palletId: json['palletId'],
        autoClosed: json['autoClosed'] ?? false,
        poStatus: json['poStatus'],
        closeMessage: json['closeMessage'],
        palletError: json['palletError'],
      );
}

class PendingPalletLine {
  final int lineId;
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
