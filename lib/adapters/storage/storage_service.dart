import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vinci_board/core/models/app_canvas.dart';
import 'package:vinci_board/adapters/storage/sync_metadata.dart';
import 'package:vinci_board/adapters/storage/sync_queue_item.dart';

class StorageService {
  static const String boxName = 'canvases_box';
  static const String metadataBoxName = 'sync_metadata_box';
  static const String queueBoxName = 'sync_queue_box';

  static Future<void> init() async {
    try {
      await Hive.initFlutter();
      final box = await Hive.openBox<String>(boxName);
      await Hive.openBox<String>(metadataBoxName);
      await Hive.openBox<String>(queueBoxName);

      // Phase 1: Migration Strategy
      if (box.containsKey('canvases')) {
        await _migrateLegacyData(box);
      }
    } catch (e) {
      debugPrint('StorageService: init failed ($e). Attempting recovery...');
      try {
        // Close any partially-opened boxes and retry once.
        // This handles stale lock files left by a previously killed process.
        await Hive.close();
        await Hive.initFlutter();
        final box = await Hive.openBox<String>(boxName);
        await Hive.openBox<String>(metadataBoxName);
        await Hive.openBox<String>(queueBoxName);
        if (box.containsKey('canvases')) {
          await _migrateLegacyData(box);
        }
        debugPrint('StorageService: Recovery succeeded.');
      } catch (retryError) {
        debugPrint(
          'StorageService: Recovery failed ($retryError). App will start with empty state.',
        );
        // Do not rethrow — allow the app to start with empty state rather than crash.
      }
    }
  }

  static Future<void> _migrateLegacyData(Box<String> box) async {
    debugPrint(
      'StorageService: Found legacy "canvases" key. Starting migration...',
    );

    final legacyData = box.get('canvases');
    if (legacyData == null) return;

    try {
      // 1. Create Backup
      await box.put('canvases_backup_v0', legacyData);

      // 2. Migrate
      final List<dynamic> decoded = jsonDecode(legacyData);
      final legacyCanvases = decoded
          .map((jsonStr) => AppCanvas.fromJson(jsonStr as Map<String, dynamic>))
          .toList();

      final Map<String, String> newEntries = {};
      for (final canvas in legacyCanvases) {
        newEntries['canvas_${canvas.id}'] = jsonEncode(canvas.toJson());
      }

      await box.putAll(newEntries);

      // 3. Verify
      final migratedKeys = box.keys
          .where((k) => k.toString().startsWith('canvas_'))
          .toList();
      if (migratedKeys.length >= legacyCanvases.length) {
        // Success: Remove legacy key
        debugPrint('StorageService: Migration verified. Removing legacy key.');
        await box.delete('canvases');
      } else {
        throw Exception('Migration verification failed: Count mismatch.');
      }
    } catch (e) {
      // 4. Rollback
      debugPrint('StorageService: Migration failed. Rolling back. Error: $e');
      final keysToDelete = box.keys
          .where((k) => k.toString().startsWith('canvas_'))
          .toList();
      await box.deleteAll(keysToDelete);
    }
  }

  /// Granular API: Save a single canvas and mark it as dirty.
  static Future<void> saveCanvas(AppCanvas canvas) async {
    final box = Hive.box<String>(boxName);

    // Update local lastModified
    canvas.lastModified = DateTime.now();
    await box.put('canvas_${canvas.id}', jsonEncode(canvas.toJson()));

    await _markCanvasDirty(canvas.id);
    await _enqueueSyncOperation(canvas.id, 'update');
  }

  /// Granular API: Delete a single canvas and mark it for sync deletion.
  static Future<void> deleteCanvas(String id) async {
    final box = Hive.box<String>(boxName);
    await box.delete('canvas_$id');
    // Also mark it dirty so CloudSyncService knows to delete it remotely
    await _markCanvasDirty(id);
    await _enqueueSyncOperation(id, 'delete');
  }

  static Future<void> _enqueueSyncOperation(
    String canvasId,
    String operation,
  ) async {
    final queueBox = Hive.box<String>(queueBoxName);

    // Prevent duplicates by removing existing pending operations for the same canvas
    final keysToRemove = <dynamic>[];
    for (final key in queueBox.keys) {
      final itemStr = queueBox.get(key);
      if (itemStr != null) {
        final item = SyncQueueItem.fromJson(jsonDecode(itemStr));
        if (item.canvasId == canvasId && item.status == 'pending') {
          keysToRemove.add(key);
        }
      }
    }

    if (keysToRemove.isNotEmpty) {
      await queueBox.deleteAll(keysToRemove);
    }

    final id = const Uuid().v4();
    final newItem = SyncQueueItem(
      id: id,
      canvasId: canvasId,
      operation: operation,
      timestamp: DateTime.now(),
    );
    await queueBox.put(id, jsonEncode(newItem.toJson()));
  }

  static Future<void> _markCanvasDirty(String canvasId) async {
    final metadataBox = Hive.box<String>(metadataBoxName);
    final data = metadataBox.get(canvasId);

    SyncMetadata meta;
    if (data != null) {
      meta = SyncMetadata.fromJson(
        jsonDecode(data),
      ).copyWith(isDirty: true, syncStatus: 'pending');
    } else {
      meta = SyncMetadata(
        canvasId: canvasId,
        isDirty: true,
        syncStatus: 'pending',
      );
    }
    await metadataBox.put(canvasId, jsonEncode(meta.toJson()));
  }

  /// Retained for backwards compatibility with Phase 1 logic if needed by CanvasNotifier.
  static Future<void> saveCanvases(List<AppCanvas> canvases) async {
    final box = Hive.box<String>(boxName);
    final metadataBox = Hive.box<String>(metadataBoxName);

    // Create new entries map
    final Map<String, String> entries = {};
    final Set<String> activeKeys = {};

    for (final canvas in canvases) {
      final key = 'canvas_${canvas.id}';
      activeKeys.add(key);
      entries[key] = jsonEncode(canvas.toJson());

      // Mark dirty
      final metaStr = metadataBox.get(canvas.id);
      SyncMetadata meta = metaStr != null
          ? SyncMetadata.fromJson(
              jsonDecode(metaStr),
            ).copyWith(isDirty: true, syncStatus: 'pending')
          : SyncMetadata(
              canvasId: canvas.id,
              isDirty: true,
              syncStatus: 'pending',
            );
      await metadataBox.put(canvas.id, jsonEncode(meta.toJson()));
    }

    // Find keys to delete (canvases that were removed)
    final keysToDelete = box.keys
        .where(
          (k) =>
              k.toString().startsWith('canvas_') &&
              !activeKeys.contains(k.toString()),
        )
        .toList();

    // Perform operations
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
    await box.putAll(entries);
  }

  static List<AppCanvas> loadCanvases() {
    // Guard: if init() failed, the box may not be open. Return empty list gracefully.
    if (!Hive.isBoxOpen(boxName)) {
      debugPrint(
        'StorageService: loadCanvases called before box was opened. Returning empty list.',
      );
      return [];
    }
    final box = Hive.box<String>(boxName);
    final metadataBox = Hive.isBoxOpen(metadataBoxName)
        ? Hive.box<String>(metadataBoxName)
        : null;

    final canvasKeys = box.keys
        .where((k) => k.toString().startsWith('canvas_'))
        .toList();
    final List<AppCanvas> canvases = [];

    for (final key in canvasKeys) {
      final data = box.get(key);
      if (data != null) {
        try {
          final canvas = AppCanvas.fromJson(
            jsonDecode(data) as Map<String, dynamic>,
          );
          canvases.add(canvas);

          // Backward compatibility: If a canvas exists but lacks metadata, assume it is synced.
          if (metadataBox != null && !metadataBox.containsKey(canvas.id)) {
            final meta = SyncMetadata(
              canvasId: canvas.id,
              isDirty: false,
              syncStatus: 'synced',
            );
            // We use unawaited put to avoid slowing down load
            metadataBox.put(canvas.id, jsonEncode(meta.toJson()));
          }
        } catch (e) {
          debugPrint(
            'StorageService: Failed to decode canvas for key $key. Error: $e',
          );
        }
      }
    }

    return canvases;
  }
}
