import 'package:shared_preferences/shared_preferences.dart';

class MemoryService {
  static const String _rulesKey = 'ai_learned_rules';

  static Future<List<String>> getRules() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_rulesKey) ?? [];
  }

  static Future<void> addRule(String rule) async {
    final prefs = await SharedPreferences.getInstance();
    final rules = prefs.getStringList(_rulesKey) ?? [];
    if (!rules.contains(rule)) {
      rules.add(rule);
      await prefs.setStringList(_rulesKey, rules);
    }
  }

  static Future<void> clearMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rulesKey);
  }
}
