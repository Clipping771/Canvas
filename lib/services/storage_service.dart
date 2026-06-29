import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/notebook.dart';

class StorageService {
  static const String boxName = 'notebooks_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(boxName);
  }

  static Future<void> saveNotebooks(List<Notebook> notebooks) async {
    final box = Hive.box<String>(boxName);
    final jsonList = notebooks.map((n) => n.toJson()).toList();
    await box.put('notebooks', jsonEncode(jsonList));
  }

  static List<Notebook> loadNotebooks() {
    final box = Hive.box<String>(boxName);
    final data = box.get('notebooks');
    if (data == null) return [];

    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((jsonStr) {
      // jsonEncode of list of Map gives list of map in decoded
      return Notebook.fromJson(jsonStr as Map<String, dynamic>);
    }).toList();
  }
}
