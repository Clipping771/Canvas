import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

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

  await File('test_output.png').writeAsBytes(response.bodyBytes);
  debugPrint('Saved test_output.png with size: \${response.bodyBytes.length}');
}
