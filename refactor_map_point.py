import re

with open('c:/My World/gravity/notesketch_pro/lib/screens/ai_chat_panel.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace mapPoint definition
old_map = """    Offset mapPoint(double x, double y) {
      // Divide by the same pixelRatio used in CanvasExporter (0.5)
      final scaledX = x / 0.5;
      final scaledY = y / 0.5;
      final point = MatrixUtils.transformPoint(
        inverse,
        Offset(scaledX, scaledY),
      );
      return point;
    }"""

new_map = """    final spawnMgr = ref.read(aiSpawnManagerProvider);
    final Size defaultSize = const Size(300, 300);
    final rootSpawnPos = targetTopLeft ?? spawnMgr.getOptimalSpawn(SpawnStrategy.auto, defaultSize, context).position;
    
    if (targetTopLeft == null) {
      spawnMgr.onSpawnComplete(SpawnLocation(position: rootSpawnPos, needsCameraMove: true, reason: ''));
    }

    Offset mapPoint(double x, double y) {
      // Scale relative to AI's expected origin (100, 100)
      final scaledX = (x - 100.0) / 0.5;
      final scaledY = (y - 100.0) / 0.5;
      final zoomScale = inverse.getMaxScaleOnAxis();
      return Offset(rootSpawnPos.dx + (scaledX * zoomScale), rootSpawnPos.dy + (scaledY * zoomScale));
    }"""

content = content.replace(old_map, new_map)

# Replace targetTopLeft ?? ...
content = content.replace('targetTopLeft ?? (pos != null && pos.length >= 2 ? mapPoint(pos[0].toDouble(), pos[1].toDouble()) : mapPoint(100.0, 100.0))', '(pos != null && pos.length >= 2 ? mapPoint(pos[0].toDouble(), pos[1].toDouble()) : mapPoint(100.0, 100.0))')
content = content.replace('targetTopLeft ?? mapPoint(rawX, rawY)', 'mapPoint(rawX, rawY)')
content = content.replace('targetTopLeft ?? mapPoint(100.0, (internalSafeY ?? 100.0) + 100.0)', 'mapPoint(100.0, (internalSafeY ?? 100.0) + 100.0)')

# Replace manual widget inserts
content = content.replace("""            if (targetTopLeft != null) {
              rawX = targetTopLeft.dx;
              rawY = targetTopLeft.dy;
            } else if (posData != null && posData.length >= 2) {""", """            if (posData != null && posData.length >= 2) {""")

content = content.replace("""            final p = targetTopLeft != null 
                ? targetTopLeft 
                : mapPoint(rawX, rawY);""", """            final p = mapPoint(rawX, rawY);""")
                
content = content.replace("""            final p = targetTopLeft != null 
                ? targetTopLeft! 
                : mapPoint(rawX, rawY);""", """            final p = mapPoint(rawX, rawY);""")


with open('c:/My World/gravity/notesketch_pro/lib/screens/ai_chat_panel.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
