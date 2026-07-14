// ignore_for_file: argument_type_not_assignable
import 'package:flutter/foundation.dart';

void main() {
  List<Map<String, dynamic>> m = [
    {'a': 1},
  ];
  var r = m
      .map((e) => e.map((k, v) => MapEntry<String, String>(k, v.toString())))
      .toList();
  debugPrint(r.runtimeType);
}
