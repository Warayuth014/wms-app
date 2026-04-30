// ── รายการสินค้าที่ Unload แล้ว (group by Part+Lot) ──────────

class UnloadedItemsResponse {
  final List<UnloadedItem> items;
  final int totalItems;
  final int totalLoaded;
  final String message;

  UnloadedItemsResponse({
    required this.items,
    required this.totalItems,
    required this.totalLoaded,
    required this.message,
  });

  factory UnloadedItemsResponse.fromJson(Map<String, dynamic> json) =>
      UnloadedItemsResponse(
        items: (json['items'] as List)
            .map((e) => UnloadedItem.fromJson(e))
            .toList(),
        totalItems: json['totalItems'] ?? 0,
        totalLoaded: json['totalLoaded'] ?? 0,
        message: json['message'] ?? '',
      );
}

class UnloadedItem {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final String? lotNumber;
  final String? expiredDate;
  final int qtyUnloaded;
  final int qtyLoaded;
  final int qtyRemaining;
  final String? basketId;
  final List<int> unloadLineIds;

  UnloadedItem({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    this.lotNumber,
    this.expiredDate,
    required this.qtyUnloaded,
    required this.qtyLoaded,
    required this.qtyRemaining,
    this.basketId,
    required this.unloadLineIds,
  });

  factory UnloadedItem.fromJson(Map<String, dynamic> json) => UnloadedItem(
        partId: json['partId'],
        owner: json['owner'] ?? '',
        brand: json['brand'] ?? '',
        itemDesc: json['itemDesc'] ?? '',
        imageUrl: json['imageUrl'],
        lotNumber: json['lotNumber'],
        expiredDate: json['expiredDate'],
        qtyUnloaded: json['qtyUnloaded'] ?? 0,
        qtyLoaded: json['qtyLoaded'] ?? 0,
        qtyRemaining: json['qtyRemaining'] ?? 0,
        basketId: json['basketId'],
        unloadLineIds: (json['unloadLineIds'] as List?)
                ?.map((e) => e as int)
                .toList() ??
            [],
      );

  bool get isDone => qtyRemaining <= 0;
}

// ── Load to Basket response ──────────

class LoadToBasketResponse {
  final String basketId;
  final String partId;
  final int qtyLoaded;
  final String basketLabel;
  final String message;

  LoadToBasketResponse({
    required this.basketId,
    required this.partId,
    required this.qtyLoaded,
    required this.basketLabel,
    required this.message,
  });

  factory LoadToBasketResponse.fromJson(Map<String, dynamic> json) =>
      LoadToBasketResponse(
        basketId: json['basketId'],
        partId: json['partId'],
        qtyLoaded: json['qtyLoaded'] ?? 0,
        basketLabel: json['basketLabel'] ?? '',
        message: json['message'] ?? '',
      );
}
