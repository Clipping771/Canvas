import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vinci_board/core/models/app_canvas.dart';
import 'package:vinci_board/adapters/storage/sync_metadata.dart';
import 'package:vinci_board/adapters/storage/sync_queue_item.dart';

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();

  factory CloudSyncService() {
    return _instance;
  }

  CloudSyncService._internal();

  bool _isSyncing = false;

  /// Process the sync queue sequentially with exponential backoff and conflict resolution
  Future<void> syncDirtyCanvases() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final queueBox = Hive.box<String>('sync_queue_box');
      final canvasesBox = Hive.box<String>('canvases_box');
      final metadataBox = Hive.box<String>('sync_metadata_box');

      final queueItems =
          queueBox.values
              .map((itemStr) => SyncQueueItem.fromJson(jsonDecode(itemStr)))
              .where(
                (item) => item.status == 'pending' || item.status == 'error',
              )
              .toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (final item in queueItems) {
        if (item.retryCount >= 5) {
          debugPrint(
            'CloudSyncService: Max retries reached for ${item.id}. Marking permanently failed.',
          );
          final failedItem = item.copyWith(status: 'failed_permanently');
          await queueBox.put(item.id, jsonEncode(failedItem.toJson()));
          continue;
        }

        try {
          if (item.operation == 'delete') {
            await deleteCanvasFromCloud(item.canvasId);
          } else {
            final canvasData = canvasesBox.get('canvas_${item.canvasId}');
            if (canvasData != null) {
              final canvas = AppCanvas.fromJson(
                jsonDecode(canvasData) as Map<String, dynamic>,
              );

              // MVP Conflict Resolution (Timestamp-based LWW)
              final cloudTimestamp = await _fetchCloudLastModified(canvas.id);
              if (cloudTimestamp != null &&
                  cloudTimestamp.isAfter(canvas.lastModified)) {
                debugPrint(
                  'CloudSyncService: Conflict detected for ${canvas.id}. Cloud is newer. Rejecting local overwrite.',
                );
                // In a full implementation, we'd fetch the cloud version and overwrite local.
                // For MVP, we prevent the stale local version from overwriting the cloud.
                final metaStr = metadataBox.get(canvas.id);
                if (metaStr != null) {
                  final meta = SyncMetadata.fromJson(jsonDecode(metaStr));
                  await metadataBox.put(
                    canvas.id,
                    jsonEncode(
                      meta
                          .copyWith(isDirty: false, syncStatus: 'conflict')
                          .toJson(),
                    ),
                  );
                }
                await queueBox.delete(item.id);
                continue;
              }

              await syncCanvasToCloud(canvas);

              // Update local metadata
              final metaStr = metadataBox.get(canvas.id);
              if (metaStr != null) {
                final meta = SyncMetadata.fromJson(jsonDecode(metaStr));
                await metadataBox.put(
                  canvas.id,
                  jsonEncode(
                    meta
                        .copyWith(
                          isDirty: false,
                          syncStatus: 'synced',
                          lastSyncedAt: DateTime.now(),
                        )
                        .toJson(),
                  ),
                );
              }
            }
          }
          // Success: remove from queue
          await queueBox.delete(item.id);
        } catch (e) {
          debugPrint(
            'CloudSyncService: Failed to process queue item ${item.id}. Error: $e',
          );
          final delayMs = pow(2, item.retryCount) * 1000;
          debugPrint('CloudSyncService: Backing off for $delayMs ms');
          await Future.delayed(Duration(milliseconds: delayMs.toInt()));

          final updatedItem = item.copyWith(
            status: 'error',
            retryCount: item.retryCount + 1,
          );
          await queueBox.put(item.id, jsonEncode(updatedItem.toJson()));
          // Break here if we want strict sequential backoff, but for MVP we can continue trying others.
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Mock fetching cloud's last modified timestamp
  Future<DateTime?> _fetchCloudLastModified(String canvasId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Simulate cloud having a very old timestamp, so local wins by default.
    return DateTime.now().subtract(const Duration(days: 1));
  }

  /// Simulates syncing a canvas to a remote database.
  Future<void> syncCanvasToCloud(AppCanvas canvas) async {
    final jsonString = jsonEncode(canvas.toJson());
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint(
      'CloudSyncService: Successfully synced canvas "${canvas.title}" to the cloud. Payload size: ${jsonString.length} bytes.',
    );
  }

  Future<void> deleteCanvasFromCloud(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('CloudSyncService: Deleted canvas $id from cloud.');
  }

  Future<List<AppCanvas>> fetchCanvasesFromCloud() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    debugPrint('CloudSyncService: Fetched canvases from cloud.');
    return [];
  }
}
