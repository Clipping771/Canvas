void main() { 
  List<Map<String, dynamic>> m = [{'a': 1}]; 
  var r = m.map((e) => e.map((k, v) => MapEntry<String, String>(k as String, v.toString()))).toList(); 
  print(r.runtimeType); 
}
