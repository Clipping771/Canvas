class AiMetadata {
  final int version;
  final String model;
  final String tool;
  final String? parentObjectId;
  final String spawnReason;
  final String? conversationId;
  final DateTime createdAt;

  AiMetadata({
    this.version = 1,
    required this.model,
    required this.tool,
    this.parentObjectId,
    required this.spawnReason,
    this.conversationId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'model': model,
      'tool': tool,
      'parentObjectId': parentObjectId,
      'spawnReason': spawnReason,
      'conversationId': conversationId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AiMetadata.fromJson(Map<String, dynamic> json) {
    return AiMetadata(
      version: json['version'] ?? 1,
      model: json['model'] ?? 'unknown',
      tool: json['tool'] ?? 'unknown',
      parentObjectId: json['parentObjectId'],
      spawnReason: json['spawnReason'] ?? 'unknown',
      conversationId: json['conversationId'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
