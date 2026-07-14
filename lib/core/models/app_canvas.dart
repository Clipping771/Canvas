import 'package:vinci_board/core/models/stroke.dart';

class AppCanvas {
  final String id;
  String title;
  DateTime dateCreated;
  DateTime lastModified;
  bool isStarred;
  List<Stroke> strokes;

  AppCanvas({
    required this.id,
    this.title = 'Untitled Canvas',
    DateTime? dateCreated,
    DateTime? lastModified,
    this.isStarred = false,
    required this.strokes,
  }) : dateCreated = dateCreated ?? DateTime.now(),
       lastModified = lastModified ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'dateCreated': dateCreated.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'isStarred': isStarred,
      'strokes': strokes.map((s) => s.toJson()).toList(),
    };
  }

  factory AppCanvas.fromJson(Map<String, dynamic> json) {
    return AppCanvas(
      id: json['id'],
      title: json['title'] ?? 'Untitled Canvas',
      dateCreated: json['dateCreated'] != null
          ? DateTime.parse(json['dateCreated'])
          : DateTime.now(),
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : (json['dateCreated'] != null
                ? DateTime.parse(json['dateCreated'])
                : DateTime.now()),
      isStarred: json['isStarred'] ?? false,
      strokes: (json['strokes'] as List)
          .map((s) => Stroke.fromJson(s))
          .toList(),
    );
  }
}
