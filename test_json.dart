import 'dart:convert';
void main() {
  try {
    var d = jsonDecode('{"ops": []}');
    List a = d['ops'];
    a.add(1);
    print('Success');
  } catch(e) {
    print('Error: $e');
  }
}
