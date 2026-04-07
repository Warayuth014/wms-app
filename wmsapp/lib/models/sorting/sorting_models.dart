class SortStation {
  final String stationId;
  final String name;
  final String status;

  SortStation({
    required this.stationId,
    required this.name,
    required this.status,
  });

  factory SortStation.fromJson(Map<String, dynamic> json) => SortStation(
    stationId: json['stationId'],
    name: json['name'] ?? '',
    status: json['status'] ?? 'AVAILABLE',
  );
}

class SortSessionItem {
  final int id;
  final String sourcePalletId;
  final String? trackingId;
  final DateTime scannedAt;

  SortSessionItem({
    required this.id,
    required this.sourcePalletId,
    this.trackingId,
    required this.scannedAt,
  });

  factory SortSessionItem.fromJson(Map<String, dynamic> json) => SortSessionItem(
    id: json['id'],
    sourcePalletId: json['sourcePalletId'],
    trackingId: json['trackingId'],
    scannedAt: DateTime.tryParse(json['scannedAt'] ?? '') ?? DateTime.now(),
  );
}

class SortSession {
  final int sessionId;
  final String stationId;
  final String sortPalletId;
  final String status;
  final DateTime createdAt;
  final DateTime? closedAt;
  final List<SortSessionItem> items;

  SortSession({
    required this.sessionId,
    required this.stationId,
    required this.sortPalletId,
    required this.status,
    required this.createdAt,
    this.closedAt,
    required this.items,
  });

  factory SortSession.fromJson(Map<String, dynamic> json) => SortSession(
    sessionId: json['sessionId'],
    stationId: json['stationId'],
    sortPalletId: json['sortPalletId'],
    status: json['status'],
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    closedAt: json['closedAt'] != null
        ? DateTime.tryParse(json['closedAt'])
        : null,
    items: (json['items'] as List)
        .map((i) => SortSessionItem.fromJson(i))
        .toList(),
  );
}
