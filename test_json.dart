import 'package:flutter/foundation.dart';
import 'dart:convert';

void main() {
  try {
    var d = jsonDecode('{"ops": []}');
    List a = d['ops'];
    a.add(1);
    debugPrint('Success');
  } catch (e) {
    debugPrint('Error: $e');
  }
}
