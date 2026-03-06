// lib/services/offline_service.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/wms_models.dart';
import 'api_service.dart';

class OfflineService {
  // Singleton
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  Database? _db;

  // =============================================
  // Initialize Database
  // =============================================
  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wms_offline.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // ── Cache Tables ───────────────────────
        await db.execute('''
          CREATE TABLE po_cache (
            poId        TEXT PRIMARY KEY,
            data        TEXT NOT NULL,
            cachedAt    TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE parts_cache (
            partId      TEXT PRIMARY KEY,
            data        TEXT NOT NULL,
            cachedAt    TEXT NOT NULL
          )
        ''');

        // ── Queue Table ────────────────────────
        await db.execute('''
          CREATE TABLE action_queue (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            action      TEXT NOT NULL,
            data        TEXT NOT NULL,
            createdAt   TEXT NOT NULL,
            synced      INTEGER NOT NULL DEFAULT 0,
            syncError   TEXT
          )
        ''');
      },
    );
  }

  Database get db {
    if (_db == null) throw Exception('OfflineService not initialized');
    return _db!;
  }

  // =============================================
  // Cache — PO
  // =============================================
  Future<void> savePO(POResponse po) async {
    await db.insert('po_cache', {
      'poId': po.poId,
      'data': jsonEncode({
        'poId': po.poId,
        'supplierId': po.supplierId,
        'supplierName': po.supplierName,
        'status': po.status,
        'createdAt': po.createdAt.toIso8601String(),
        'items': po.items
            .map(
              (i) => {
                'id': i.id,
                'partId': i.partId,
                'owner': i.owner,
                'brand': i.brand,
                'itemDesc': i.itemDesc,
                'qtyOrdered': i.qtyOrdered,
                'qtyReceived': i.qtyReceived,
                'status': i.status,
              },
            )
            .toList(),
      }),
      'cachedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<POResponse?> getCachedPO(String poId) async {
    final rows = await db.query(
      'po_cache',
      where: 'poId = ?',
      whereArgs: [poId],
    );
    if (rows.isEmpty) return null;
    return POResponse.fromJson(jsonDecode(rows.first['data'] as String));
  }

  // =============================================
  // Cache — Parts
  // =============================================
  Future<void> savePart(Part part) async {
    await db.insert('parts_cache', {
      'partId': part.partId,
      'data': jsonEncode({
        'partId': part.partId,
        'owner': part.owner,
        'brand': part.brand,
        'itemDesc': part.itemDesc,
      }),
      'cachedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Part?> getCachedPart(String partId) async {
    final rows = await db.query(
      'parts_cache',
      where: 'partId = ?',
      whereArgs: [partId],
    );
    if (rows.isEmpty) return null;
    return Part.fromJson(jsonDecode(rows.first['data'] as String));
  }

  // =============================================
  // Queue — เพิ่ม action รอ sync
  // =============================================
  Future<int> addToQueue({
    required String action,
    required Map<String, dynamic> data,
  }) async {
    return await db.insert('action_queue', {
      'action': action,
      'data': jsonEncode(data),
      'createdAt': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    return await db.query(
      'action_queue',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'id ASC', // sync ตามลำดับที่ทำ
    );
  }

  Future<void> markSynced(int id) async {
    await db.update(
      'action_queue',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSyncError(int id, String error) async {
    await db.update(
      'action_queue',
      {'syncError': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =============================================
  // Sync Queue → Server
  // =============================================
  Future<SyncResult> syncQueue() async {
    final queue = await getPendingQueue();
    int success = 0;
    int failed = 0;
    final errors = <String>[];

    for (final item in queue) {
      final id = item['id'] as int;
      final action = item['action'] as String;
      final data = jsonDecode(item['data'] as String) as Map<String, dynamic>;

      try {
        ApiResult result = await _executeAction(action, data);

        if (result.success) {
          await markSynced(id);
          success++;
        } else {
          await markSyncError(id, result.error ?? 'Unknown error');
          errors.add('[$action] ${result.error}');
          failed++;
        }
      } catch (e) {
        await markSyncError(id, e.toString());
        errors.add('[$action] $e');
        failed++;
      }
    }

    return SyncResult(
      total: queue.length,
      success: success,
      failed: failed,
      errors: errors,
    );
  }

  // ── Map action → API call ───────────────────
  Future<ApiResult> _executeAction(
    String action,
    Map<String, dynamic> data,
  ) async {
    final api = ApiService();

    switch (action) {
      case 'scan-part':
        return api.scanReceiptPart(
          sessionId: data['sessionId'],
          poId: data['poId'],
          partId: data['partId'],
          qtyReceived: data['qtyReceived'],
          lotNumber: data['lotNumber'],
          expiredDate: data['expiredDate'],
          condition: data['condition'],
          operatorId: data['operatorId'],
        );

      case 'assign-pallet':
        return api.assignPallet(
          sessionId: data['sessionId'],
          palletId: data['palletId'],
          palletType: data['palletType'],
          operatorId: data['operatorId'],
          lineIds: List<int>.from(data['lineIds']),
        );

      case 'confirm-unload':
        return api.confirmUnload(
          sessionId: data['sessionId'],
          palletId: data['palletId'],
          partId: data['partId'],
          operatorId: data['operatorId'],
        );

      case 'load-to-basket':
        return api.loadToBasket(
          sessionId: data['sessionId'],
          basketId: data['basketId'],
          partId: data['partId'],
          palletId: data['palletId'],
          operatorId: data['operatorId'],
        );

      default:
        return ApiResult.error('Unknown action: $action');
    }
  }

  // =============================================
  // Pending count (แสดงใน UI)
  // =============================================
  Future<int> getPendingCount() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM action_queue WHERE synced = 0',
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }
}

// =============================================
// SyncResult
// =============================================
class SyncResult {
  final int total;
  final int success;
  final int failed;
  final List<String> errors;

  SyncResult({
    required this.total,
    required this.success,
    required this.failed,
    required this.errors,
  });

  bool get hasErrors => failed > 0;

  String get summary =>
      'Sync เสร็จ: $success/$total สำเร็จ'
      '${failed > 0 ? ', $failed ล้มเหลว' : ''}';
}
