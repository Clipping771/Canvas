import 'page.dart';

class Notebook {
  final String id;
  String title;
  List<NotePage> pages;

  Notebook({required this.id, required this.title, required this.pages});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'pages': pages.map((p) => p.toJson()).toList(),
    };
  }

  factory Notebook.fromJson(Map<String, dynamic> json) {
    return Notebook(
      id: json['id'],
      title: json['title'],
      pages: (json['pages'] as List).map((p) => NotePage.fromJson(p)).toList(),
    );
  }
}
