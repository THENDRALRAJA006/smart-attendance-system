// ============================================================
// SmartAttend — Offline Queue Service
// Queues attendance records locally (SQLite) when offline,
// auto-syncs when connectivity is restored.
// ============================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../network/api_client.dart';
import 'connectivity_service.dart';

class OfflineQueueService extends GetxService {
  static OfflineQueueService get to => Get.find();

  Database? _db;
  final RxInt pendingCount = 0.obs;
  final RxBool syncing = false.obs;

  static const _tableName = 'offline_attendance';

  // ─── Init ─────────────────────────────────────────────────
  Future<OfflineQueueService> init() async {
    await _openDb();
    await _countPending();

    // Listen for connectivity to trigger sync
    try {
      final conn = Get.find<ConnectivityService>();
      ever(conn.isOnline, (bool connected) {
        if (connected) _syncPending();
      });
    } catch (_) {
      debugPrint('[OfflineQueue] ConnectivityService not found — auto-sync disabled');
    }

    return this;
  }

  // ─── Database ─────────────────────────────────────────────
  Future<void> _openDb() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'smartattend_offline.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payload TEXT NOT NULL,
          endpoint TEXT NOT NULL,
          method TEXT NOT NULL DEFAULT 'POST',
          created_at TEXT NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0
        )
      '''),
    );
  }

  // ─── Enqueue ──────────────────────────────────────────────
  /// Enqueue an attendance record for later sync.
  /// [endpoint] e.g. '/attendance/mark-qr'
  /// [payload] the request body map
  Future<void> enqueue({
    required String endpoint,
    required Map<String, dynamic> payload,
    String method = 'POST',
  }) async {
    if (_db == null) await _openDb();
    await _db!.insert(_tableName, {
      'payload': jsonEncode(payload),
      'endpoint': endpoint,
      'method': method,
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
    pendingCount.value++;
    debugPrint('[OfflineQueue] Enqueued → $endpoint (pending: ${pendingCount.value})');
  }

  // ─── Sync ─────────────────────────────────────────────────
  Future<void> _syncPending() async {
    if (syncing.value) return;
    if (_db == null) await _openDb();

    final rows = await _db!.query(
      _tableName,
      orderBy: 'created_at ASC',
      where: 'retry_count < 5',
    );

    if (rows.isEmpty) return;

    syncing.value = true;
    debugPrint('[OfflineQueue] Syncing ${rows.length} queued records…');

    for (final row in rows) {
      final id = row['id'] as int;
      final endpoint = row['endpoint'] as String;
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      final retries = row['retry_count'] as int;

      try {
        final api = ApiClient.to;
        final resp = await api.post(endpoint, data: payload);
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          await _db!.delete(_tableName, where: 'id = ?', whereArgs: [id]);
          pendingCount.value = (pendingCount.value - 1).clamp(0, 9999);
          debugPrint('[OfflineQueue] Synced id=$id ✓');
        } else {
          await _incrementRetry(id, retries);
        }
      } catch (e) {
        await _incrementRetry(id, retries);
        debugPrint('[OfflineQueue] Sync failed id=$id: $e');
      }
    }

    syncing.value = false;
    await _countPending();
  }

  Future<void> _incrementRetry(int id, int current) async {
    await _db!.update(
      _tableName,
      {'retry_count': current + 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _countPending() async {
    if (_db == null) return;
    final result = await _db!.rawQuery('SELECT COUNT(*) as cnt FROM $_tableName');
    pendingCount.value = (result.first['cnt'] as int?) ?? 0;
  }

  // ─── Manual Sync ─────────────────────────────────────────
  Future<void> syncNow() => _syncPending();

  // ─── Clear All ───────────────────────────────────────────
  Future<void> clearAll() async {
    if (_db == null) return;
    await _db!.delete(_tableName);
    pendingCount.value = 0;
  }
}
