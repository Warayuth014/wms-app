// ── Pallet level ──────────────────────────────────
class PackingPalletResponse {
  final String palletId;
  final String status;
  final String? location;
  final List<PackingSummary> packs;
  final String message;

  PackingPalletResponse({
    required this.palletId,
    required this.status,
    this.location,
    required this.packs,
    required this.message,
  });

  factory PackingPalletResponse.fromJson(Map<String, dynamic> json) =>
      PackingPalletResponse(
        palletId: json['palletId'],
        status: json['status'],
        location: json['location'],
        packs: (json['packs'] as List)
            .map((p) => PackingSummary.fromJson(p))
            .toList(),
        message: json['message'] ?? '',
      );
}

class PackingSummary {
  final String packingId;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int orderCount;
  final int orderDoneCount;

  PackingSummary({
    required this.packingId,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.orderCount,
    required this.orderDoneCount,
  });

  factory PackingSummary.fromJson(Map<String, dynamic> json) => PackingSummary(
    packingId: json['packingId'],
    status: json['status'],
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    completedAt: json['completedAt'] != null
        ? DateTime.tryParse(json['completedAt'])
        : null,
    orderCount: json['orderCount'] ?? 0,
    orderDoneCount: json['orderDoneCount'] ?? 0,
  );

  bool get isDone => status == 'DONE';
}

// ── Pack level ──────────────────────────────────
class PackingDetailResponse {
  final String packingId;
  final String palletId;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? trackingId;
  final List<PackingOrderSummary> orders;

  PackingDetailResponse({
    required this.packingId,
    required this.palletId,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.trackingId,
    required this.orders,
  });

  factory PackingDetailResponse.fromJson(Map<String, dynamic> json) =>
      PackingDetailResponse(
        packingId: json['packingId'],
        palletId: json['palletId'],
        status: json['status'],
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'])
            : null,
        trackingId: json['trackingId'],
        orders: (json['orders'] as List)
            .map((o) => PackingOrderSummary.fromJson(o))
            .toList(),
      );

  bool get isDone => status == 'DONE';
}

class PackingOrderSummary {
  final String pickOrderId;
  final String status;
  final int partCount;
  final int partDoneCount;

  PackingOrderSummary({
    required this.pickOrderId,
    required this.status,
    required this.partCount,
    required this.partDoneCount,
  });

  factory PackingOrderSummary.fromJson(Map<String, dynamic> json) =>
      PackingOrderSummary(
        pickOrderId: json['pickOrderId'],
        status: json['status'],
        partCount: json['partCount'] ?? 0,
        partDoneCount: json['partDoneCount'] ?? 0,
      );

  bool get isDone => status == 'DONE';
}

// ── Order level ──────────────────────────────────
class PackingOrderResponse {
  final String packingId;
  final String pickOrderId;
  final String status;
  final List<PackingPartItem> parts;

  PackingOrderResponse({
    required this.packingId,
    required this.pickOrderId,
    required this.status,
    required this.parts,
  });

  factory PackingOrderResponse.fromJson(Map<String, dynamic> json) =>
      PackingOrderResponse(
        packingId: json['packingId'],
        pickOrderId: json['pickOrderId'],
        status: json['status'],
        parts: (json['parts'] as List)
            .map((p) => PackingPartItem.fromJson(p))
            .toList(),
      );

  bool get isDone => status == 'DONE';
}

class PackingPartItem {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;
  final int requiredQty;
  final int scannedQty;

  PackingPartItem({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
    required this.requiredQty,
    required this.scannedQty,
  });

  factory PackingPartItem.fromJson(Map<String, dynamic> json) =>
      PackingPartItem(
        partId: json['partId'],
        owner: json['owner'] ?? '',
        brand: json['brand'] ?? '',
        itemDesc: json['itemDesc'] ?? '',
        imageUrl: json['imageUrl'],
        requiredQty: json['requiredQty'] ?? 0,
        scannedQty: json['scannedQty'] ?? 0,
      );

  bool get isDone => scannedQty >= requiredQty;
  int get remaining => (requiredQty - scannedQty).clamp(0, requiredQty);
}

// ── Confirm response ──────────────────────────────────
class ConfirmPackResponse {
  final String packingId;
  final String status;
  final String? trackingId;
  final bool palletShipped;
  final DateTime completedAt;
  final String message;

  ConfirmPackResponse({
    required this.packingId,
    required this.status,
    this.trackingId,
    required this.palletShipped,
    required this.completedAt,
    required this.message,
  });

  factory ConfirmPackResponse.fromJson(Map<String, dynamic> json) =>
      ConfirmPackResponse(
        packingId: json['packingId'],
        status: json['status'],
        trackingId: json['trackingId'],
        palletShipped: json['palletShipped'] ?? false,
        completedAt: DateTime.tryParse(json['completedAt'] ?? '') ?? DateTime.now(),
        message: json['message'] ?? '',
      );
}
