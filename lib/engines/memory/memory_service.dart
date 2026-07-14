import 'package:shared_preferences/shared_preferences.dart';

class MemoryService {
  static const String _rulesKey = 'ai_learned_rules';

  static Future<List<String>> getRules() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_rulesKey) ?? [];
  }

  static Future<void> addRule(String newRule) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rules = prefs.getStringList(_rulesKey) ?? [];

    // 1. Exact duplicate check
    if (rules.contains(newRule)) return;

    // 2. Lightweight heuristic conflict detection
    final stopWords = {
      'always',
      'never',
      'use',
      'for',
      'the',
      'a',
      'an',
      'in',
      'on',
      'at',
      'to',
      'is',
      'are',
      'do',
      'not',
      'when',
      'draw',
      'drawing',
    };
    Set<String> extractKeywords(String text) {
      return text
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(' ')
          .where((w) => w.length > 2 && !stopWords.contains(w))
          .toSet();
    }

    final newKeywords = extractKeywords(newRule);

    int conflictIndex = -1;
    for (int i = 0; i < rules.length; i++) {
      final oldKeywords = extractKeywords(rules[i]);
      if (oldKeywords.isEmpty || newKeywords.isEmpty) continue;

      final intersection = oldKeywords.intersection(newKeywords);
      final overlap = intersection.length / oldKeywords.length;

      // If there is significant semantic overlap (> 60%), consider it a conflict
      if (overlap > 0.6) {
        conflictIndex = i;
        break;
      }
    }

    if (conflictIndex != -1) {
      // Overwrite the conflicting older rule with the newer rule (Conflict Resolution)
      rules[conflictIndex] = newRule;
    } else {
      // No conflict, just append
      rules.add(newRule);
    }

    await prefs.setStringList(_rulesKey, rules);
  }

  static Future<void> clearMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rulesKey);
  }
}
