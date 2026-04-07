class PackingItem {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final String? lotNumber;
  final int qty;
  final String condition;

  PackingItem({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    this.lotNumber,
    required this.qty,
    required this.condition,
  });

  factory PackingItem.fromJson(Map<String, dynamic> json) => PackingItem(
    partId: json['partId'],
    owner: json['owner'] ?? '',
    brand: json['brand'] ?? '',
    itemDesc: json['itemDesc'] ?? '',
    imageUrl: json['imageUrl'],
    lotNumber: json['lotNumber'],
    qty: json['qty'] ?? 0,
    condition: json['condition'] ?? '',
  );
}

class PackingScanResponse {
  final String palletId;
  final String status;
  final String? location;
  final String? pickOrderId;
  final List<PackingItem> items;
  final String message;

  PackingScanResponse({
    required this.palletId,
    required this.status,
    this.location,
    this.pickOrderId,
    required this.items,
    required this.message,
  });

  factory PackingScanResponse.fromJson(Map<String, dynamic> json) =>
      PackingScanResponse(
        palletId: json['palletId'],
        status: json['status'],
        location: json['location'],
        pickOrderId: json['pickOrderId'],
        items: (json['items'] as List)
            .map((item) => PackingItem.fromJson(item))
            .toList(),
        message: json['message'] ?? '',
      );
}

class ConfirmPackResponse {
  final String palletId;
  final String trackingId;
  final String status;
  final DateTime packedAt;
  final String message;

  ConfirmPackResponse({
    required this.palletId,
    required this.trackingId,
    required this.status,
    required this.packedAt,
    required this.message,
  });

  factory ConfirmPackResponse.fromJson(Map<String, dynamic> json) =>
      ConfirmPackResponse(
        palletId: json['palletId'],
        trackingId: json['trackingId'],
        status: json['status'],
        packedAt: DateTime.tryParse(json['packedAt'] ?? '') ?? DateTime.now(),
        message: json['message'] ?? '',
      );
}
