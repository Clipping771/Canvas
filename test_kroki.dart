import 'package:http/http.dart' as http;

void main() async {
  String text = "@startuml\nA->B\n@enduml";
  var response = await http.post(
    Uri.parse('https://kroki.io/plantuml/png'),
    body: text,
    headers: {'Content-Type': 'text/plain'},
  );

  print('Kroki POST status: ${response.statusCode}');
  print('Kroki POST bytes: ${response.bodyBytes.length}');
}
