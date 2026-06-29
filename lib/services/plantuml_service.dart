import 'dart:typed_data';
import 'package:http/http.dart' as http;

class PlantUmlService {
  static const String _krokiUrl = 'https://kroki.io/plantuml/png';

  static Future<Uint8List?> fetchUmlImage(String text) async {
    try {
      // Ensure text is wrapped in @startuml and @enduml
      if (!text.trim().startsWith('@startuml')) {
        text = '@startuml\n$text\n@enduml';
      }

      // Inject transparent background
      text = text.replaceFirst(
        '@startuml',
        '@startuml\nskinparam backgroundcolor transparent',
      );

      final response = await http.post(
        Uri.parse(_krokiUrl),
        body: text,
        headers: {'Content-Type': 'text/plain'},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('Kroki returned error: \${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching UML image: $e');
    }
    return null;
  }
}
