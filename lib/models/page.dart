import 'stroke.dart';

class NotePage {
  final String id;
  String title;
  DateTime dateCreated;
  bool isStarred;
  List<Stroke> strokes;

  NotePage({
    required this.id,
    this.title = 'Untitled Note',
    DateTime? dateCreated,
    this.isStarred = false,
    required this.strokes,
  }) : dateCreated = dateCreated ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'dateCreated': dateCreated.toIso8601String(),
      'isStarred': isStarred,
      'strokes': strokes.map((s) => s.toJson()).toList(),
    };
  }

  factory NotePage.fromJson(Map<String, dynamic> json) {
    return NotePage(
      id: json['id'],
      title: json['title'] ?? 'Untitled Note',
      dateCreated: json['dateCreated'] != null
          ? DateTime.parse(json['dateCreated'])
          : DateTime.now(),
      isStarred: json['isStarred'] ?? false,
      strokes: (json['strokes'] as List)
          .map((s) => Stroke.fromJson(s))
          .toList(),
    );
  }
}
