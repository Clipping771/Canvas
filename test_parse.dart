// ignore_for_file: argument_type_not_assignable
import 'package:flutter/foundation.dart';

void main() {
  try {
    debugPrint(int.parse("0xFF000000"));
  } catch (e) {
    debugPrint("Error: $e");
  }
}
