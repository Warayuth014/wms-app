// ── Dashboard data: stations + counters ──────────────
class SortingDashboardData {
  final List<SortingStationView> stations;
  final int completedCount;
  final int queuedCount;

  SortingDashboardData({
    required this.stations,
    required this.completedCount,
    required this.queuedCount,
  });

  factory SortingDashboardData.fromJson(Map<String, dynamic> json) =>
      SortingDashboardData(
        stations: ((json['stations'] ?? []) as List)
            .map((e) => SortingStationView.fromJson(e as Map<String, dynamic>))
            .toList(),
        completedCount: json['completedCount'] ?? 0,
        queuedCount: json['queuedCount'] ?? 0,
      );
}

// ── Station view (10 cards) ──────────────────────────
class SortingStationView {
  final int stationId;
  final bool enabled;
  final String status;            // AVAILABLE | BUSY | DISABLED
  final String? palletId;
  final int? cartonsCount;
  final int? maxCapacity;
  final bool? isFull;
  final DateTime? startedAt;
  final String? disabledBy;
  final DateTime? disabledAt;
  final String? disableReason;

  SortingStationView({
    required this.stationId,
    required this.enabled,
    required this.status,
    this.palletId,
    this.cartonsCount,
    this.maxCapacity,
    this.isFull,
    this.startedAt,
    this.disabledBy,
    this.disabledAt,
    this.disableReason,
  });

  factory SortingStationView.fromJson(Map<String, dynamic> json) =>
      SortingStationView(
        stationId: json['stationId'],
        enabled: json['enabled'] ?? true,
        status: json['status'] ?? 'AVAILABLE',
        palletId: json['palletId'],
        cartonsCount: json['cartonsCount'],
        maxCapacity: json['maxCapacity'],
        isFull: json['isFull'],
        startedAt: _parseDate(json['startedAt']),
        disabledBy: json['disabledBy'],
        disabledAt: _parseDate(json['disabledAt']),
        disableReason: json['disableReason'],
      );

  SortingStationView copyWith({
    String? status,
    String? palletId,
    int? cartonsCount,
    int? maxCapacity,
    bool? isFull,
    bool? enabled,
  }) =>
      SortingStationView(
        stationId: stationId,
        enabled: enabled ?? this.enabled,
        status: status ?? this.status,
        palletId: palletId ?? this.palletId,
        cartonsCount: cartonsCount ?? this.cartonsCount,
        maxCapacity: maxCapacity ?? this.maxCapacity,
        isFull: isFull ?? this.isFull,
        startedAt: startedAt,
        disabledBy: disabledBy,
        disabledAt: disabledAt,
        disableReason: disableReason,
      );
}

// ── Station detail ──────────────────────────────────
class SortingStationDetail {
  final int stationId;
  final bool enabled;
  final String status;
  final String? palletId;
  final int cartonsCount;
  final int maxCapacity;
  final bool isFull;
  final DateTime? startedAt;
  final DateTime? fullAt;
  final List<SortingStationCarton> cartons;
  final int pendingCount;

  SortingStationDetail({
    required this.stationId,
    required this.enabled,
    required this.status,
    this.palletId,
    required this.cartonsCount,
    required this.maxCapacity,
    required this.isFull,
    this.startedAt,
    this.fullAt,
    required this.cartons,
    required this.pendingCount,
  });

  factory SortingStationDetail.fromJson(Map<String, dynamic> json) =>
      SortingStationDetail(
        stationId: json['stationId'],
        enabled: json['enabled'] ?? true,
        status: json['status'] ?? 'AVAILABLE',
        palletId: json['palletId'],
        cartonsCount: json['cartonsCount'] ?? 0,
        maxCapacity: json['maxCapacity'] ?? 0,
        isFull: json['isFull'] ?? false,
        startedAt: _parseDate(json['startedAt']),
        fullAt: _parseDate(json['fullAt']),
        cartons: ((json['cartons'] ?? []) as List)
            .map((c) => SortingStationCarton.fromJson(c))
            .toList(),
        pendingCount: json['pendingCount'] ?? 0,
      );
}

class SortingStationCarton {
  final String packingId;
  final String owner;
  final int weightGram;
  final int itemCount;
  final DateTime sortedAt;
  final int sequenceNo;

  SortingStationCarton({
    required this.packingId,
    required this.owner,
    required this.weightGram,
    required this.itemCount,
    required this.sortedAt,
    required this.sequenceNo,
  });

  factory SortingStationCarton.fromJson(Map<String, dynamic> json) =>
      SortingStationCarton(
        packingId: json['packingId'],
        owner: json['owner'] ?? '',
        weightGram: json['weightGram'] ?? 0,
        itemCount: json['itemCount'] ?? 0,
        sortedAt: _parseDate(json['sortedAt']) ?? DateTime.now(),
        sequenceNo: json['sequenceNo'] ?? 0,
      );
}

// ── Available pack for sorting (test screen) ─────────
class AvailablePackForSorting {
  final String packingId;
  final String owner;
  final String? customerOrderId;
  final int itemCount;
  final int orderCount;
  final DateTime completedAt;

  AvailablePackForSorting({
    required this.packingId,
    required this.owner,
    this.customerOrderId,
    required this.itemCount,
    required this.orderCount,
    required this.completedAt,
  });

  factory AvailablePackForSorting.fromJson(Map<String, dynamic> json) =>
      AvailablePackForSorting(
        packingId: json['packingId'],
        owner: json['owner'] ?? '',
        customerOrderId: json['customerOrderId'],
        itemCount: json['itemCount'] ?? 0,
        orderCount: json['orderCount'] ?? 0,
        completedAt: _parseDate(json['completedAt']) ?? DateTime.now(),
      );
}

// ── Create batch response ────────────────────────────
class CreateSortingBatchResponse {
  final String outcome;       // ASSIGNED | QUEUED
  final int? stationId;
  final String? palletId;
  final int batchSize;
  final int? queueId;
  final String message;

  CreateSortingBatchResponse({
    required this.outcome,
    this.stationId,
    this.palletId,
    required this.batchSize,
    this.queueId,
    required this.message,
  });

  factory CreateSortingBatchResponse.fromJson(Map<String, dynamic> json) =>
      CreateSortingBatchResponse(
        outcome: json['outcome'] ?? 'ASSIGNED',
        stationId: json['stationId'],
        palletId: json['palletId'],
        batchSize: json['batchSize'] ?? 0,
        queueId: json['queueId'],
        message: json['message'] ?? '',
      );

  bool get isQueued => outcome == 'QUEUED';
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
