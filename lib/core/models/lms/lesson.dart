class Lesson {
  final String id;
  final String title;
  final String contentUrl; // Deep link to the Vinci file or canvas state
  final DateTime createdAt;

  Lesson({
    required this.id,
    required this.title,
    required this.contentUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'contentUrl': contentUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    title: json['title'] as String,
    contentUrl: json['contentUrl'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
