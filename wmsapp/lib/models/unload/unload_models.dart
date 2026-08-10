// LineId = UnloadLine.LineId — ระบุ Part+Lot ที่แน่นอน (1 Part อาจมีหลาย Lot บน pallet เดียวกัน)
class UnloadItem {
  final int lineId;
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final String? lotNumber;
  final String? expiredDate;
  final int qty;
  final String condition;
  final List<String> serialNumbers;

  UnloadItem({
    required this.lineId,
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    this.lotNumber,
    this.expiredDate,
    required this.qty,
    required this.condition,
    this.serialNumbers = const [],
  });

  factory UnloadItem.fromJson(Map<String, dynamic> json) => UnloadItem(
    lineId: json['lineId'],
    partId: json['partId'],
    owner: json['owner'],
    brand: json['brand'],
    itemDesc: json['itemDesc'],
    imageUrl: json['imageUrl'],
    lotNumber: json['lotNumber'],
    expiredDate: json['expiredDate'],
    qty: json['qty'],
    condition: json['condition'],
    serialNumbers: (json['serialNumbers'] as List?)
            ?.map((e) => e as String)
            .toList() ??
        [],
  );

  bool get serialRequire => serialNumbers.isNotEmpty;
}

class UnloadSession {
  final int sessionId;
  final String palletId;
  final String status;
  final List<UnloadItem> items;
  final List<int> confirmedLineIds;

  UnloadSession({
    required this.sessionId,
    required this.palletId,
    required this.status,
    required this.items,
    this.confirmedLineIds = const [],
  });

  factory UnloadSession.fromJson(Map<String, dynamic> json) => UnloadSession(
    sessionId: json['sessionId'],
    palletId: json['palletId'],
    status: json['status'],
    items: (json['items'] as List).map((i) => UnloadItem.fromJson(i)).toList(),
    confirmedLineIds: (json['confirmedLineIds'] as List? ?? [])
        .map((e) => e as int)
        .toList(),
  );
}

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

  factory GroupedUnloadItem.fromJson(Map<String, dynamic> json) =>
      GroupedUnloadItem(
        partId: json['partId'],
        owner: json['owner'],
        brand: json['brand'],
        itemDesc: json['itemDesc'],
        imageUrl: json['imageUrl'],
        lotNumber: json['lotNumber'],
        totalQty: json['totalQty'],
      );
}
