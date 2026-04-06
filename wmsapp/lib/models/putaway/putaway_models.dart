import '../unload/unload_models.dart';

class PutawayPalletInfo {
  final String palletId;
  final String type;
  final String status;
  final String suggestedDestination;
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

class PreworkReceiveResult {
  final bool success;
  final String palletId;
  final String stationId;
  final List<UnloadItem> items;
  final String message;

  PreworkReceiveResult({
    required this.success,
    required this.palletId,
    required this.stationId,
    required this.items,
    required this.message,
  });

  factory PreworkReceiveResult.fromJson(Map<String, dynamic> json) =>
      PreworkReceiveResult(
        success: json['success'] ?? true,
        palletId: json['palletId'],
        stationId: json['stationId'],
        items: (json['items'] as List)
            .map((i) => UnloadItem.fromJson(i))
            .toList(),
        message: json['message'] ?? '',
      );
}
