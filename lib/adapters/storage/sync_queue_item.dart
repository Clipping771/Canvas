class SyncQueueItem {
  final String id;
  final String canvasId;
  final String operation; // 'create', 'update', 'delete'
  final DateTime timestamp;
  final int retryCount;
  final String status;

  SyncQueueItem({
    required this.id,
    required this.canvasId,
    required this.operation,
    required this.timestamp,
    this.retryCount = 0,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'canvasId': canvasId,
      'operation': operation,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
      'status': status,
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      canvasId: json['canvasId'] as String,
      operation: json['operation'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
    );
  }

  SyncQueueItem copyWith({
    String? id,
    String? canvasId,
    String? operation,
    DateTime? timestamp,
    int? retryCount,
    String? status,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      canvasId: canvasId ?? this.canvasId,
      operation: operation ?? this.operation,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
    );
  }
}
