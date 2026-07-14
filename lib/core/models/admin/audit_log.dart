class AuditLog {
  final String id;
  final String actionId;
  final String userId;
  final String description;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.actionId,
    required this.userId,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'actionId': actionId,
    'userId': userId,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
    id: json['id'] as String,
    actionId: json['actionId'] as String,
    userId: json['userId'] as String,
    description: json['description'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
