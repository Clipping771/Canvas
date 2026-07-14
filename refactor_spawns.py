import re

with open('c:/My World/gravity/notesketch_pro/lib/screens/ai_chat_panel.dart', 'r', encoding='utf-8') as f:
    content = f.read()

import_pattern = "import '../engine/logic/models/circuit_component.dart';"
if import_pattern in content and "ai_spawn_manager.dart" not in content:
    content = content.replace(import_pattern, import_pattern + "\nimport '../engine/ai/ai_spawn_manager.dart';\nimport '../engine/ai/spawn_strategy.dart';")

start_idx = content.find("Offset mapPoint(double x, double y) {")
if start_idx != -1 and "getSpawnPoint" not in content:
    insertion = """
    Offset getSpawnPoint(Size itemSize, {Offset? requestedPos}) {
      if (targetTopLeft != null) return targetTopLeft!;
      
      final spawnMgr = ref.read(aiSpawnManagerProvider);
      final currentNewBounds = newStrokes.map((s) => s.bounds).toList();
      
      final loc = spawnMgr.getOptimalSpawn(
        SpawnStrategy.auto, 
        itemSize, 
        context,
        additionalBounds: currentNewBounds,
      );
      
      spawnMgr.onSpawnComplete(loc); // triggers camera animation if needed
      return loc.position;
    }
    """
    end_map_idx = content.find("return point;\n    }", start_idx) + 19
    content = content[:end_map_idx] + insertion + content[end_map_idx:]

# Replacements for explicit targetTopLeft ?? mapPoint()
content = re.sub(r'targetTopLeft \?\? \(pos != null && pos\.length >= 2 \? mapPoint\(pos\[0\]\.toDouble\(\), pos\[1\]\.toDouble\(\)\) : mapPoint\(100\.0, 100\.0\)\)', r'getSpawnPoint(const Size(300, 300))', content)
content = re.sub(r'targetTopLeft \?\? mapPoint\(rawX, rawY\)', r'getSpawnPoint(const Size(300, 300))', content)
content = re.sub(r'targetTopLeft \?\? mapPoint\(100\.0, \(internalSafeY \?\? 100\.0\) \+ 100\.0\)', r'getSpawnPoint(const Size(300, 300))', content)
content = re.sub(r'targetTopLeft != null \s*\?\s*targetTopLeft \s*:\s*mapPoint\(rawX, rawY\)', r'getSpawnPoint(const Size(300, 300))', content)

with open('c:/My World/gravity/notesketch_pro/lib/screens/ai_chat_panel.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
