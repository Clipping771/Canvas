class SyncMetadata {
  final String canvasId;
  final bool isDirty;
  final DateTime? lastSyncedAt;
  final int retryCount;
  final String syncStatus;

  SyncMetadata({
    required this.canvasId,
    this.isDirty = false,
    this.lastSyncedAt,
    this.retryCount = 0,
    this.syncStatus = 'synced',
  });

  Map<String, dynamic> toJson() {
    return {
      'canvasId': canvasId,
      'isDirty': isDirty,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'retryCount': retryCount,
      'syncStatus': syncStatus,
    };
  }

  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      canvasId: json['canvasId'] as String,
      isDirty: json['isDirty'] as bool? ?? false,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
      retryCount: json['retryCount'] as int? ?? 0,
      syncStatus: json['syncStatus'] as String? ?? 'synced',
    );
  }

  SyncMetadata copyWith({
    String? canvasId,
    bool? isDirty,
    DateTime? lastSyncedAt,
    int? retryCount,
    String? syncStatus,
  }) {
    return SyncMetadata(
      canvasId: canvasId ?? this.canvasId,
      isDirty: isDirty ?? this.isDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      retryCount: retryCount ?? this.retryCount,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
