import 'package:http/http.dart' as http;

void main() async {
  String text = """
@startuml

start

:Collect city data;

:Analyze population,
traffic, environment,
and resources;

if (Identify city needs) then (Housing)
    :Plan residential areas;
elseif (Transport)
    :Design roads and public transport;
elseif (Environment)
    :Create green spaces
    and sustainability plans;
elseif (Economy)
    :Develop commercial
    and industrial zones;
endif

:Create city development plan;

:Review plan with
authorities and community;

if (Plan approved?) then (Yes)
    :Implement city plan;
    :Monitor progress;
    :Evaluate results;
    :Update future plans;
else (No)
    :Modify and improve plan;
    :Review again;
endif

stop

@enduml
""";

  var response = await http.post(
    Uri.parse('https://kroki.io/plantuml/png'),
    body: text,
    headers: {'Content-Type': 'text/plain'},
  );

  print('Kroki POST status: \${response.statusCode}');
  print('Kroki POST bytes: \${response.bodyBytes.length}');

  if (response.bodyBytes.length < 1500) {
    print('Small image, might be an error image or invalid PNG?');
  }
}
