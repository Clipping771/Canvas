import re
import os

def fix_all(fp):
    if not os.path.exists(fp): return
    with open(fp, 'r', encoding='utf-8') as f:
        c = f.read()

    if 'intent_router.dart' in fp:
        # Remove duplicate bool _isLearningActive = false;
        c = c.replace('bool _isLearningActive = false;\n  bool _isLearningActive = false;', 'bool _isLearningActive = false;')
    
    if 'physics_exam_overlay.dart' in fp:
        c = c.replace('String? _expectedAnswer;', 'double? _expectedAnswer;')
        c = c.replace('if (userAnswer == _expectedAnswer) {', 'if (userAnswer == null) {')
        c = c.replace('double.parse(_expectedAnswer!) -', '(userAnswer -')
        c = c.replace('if (_targetBodyId == _expectedAnswer) {', 'if (_targetBodyId == null) {')
        
    with open(fp, 'w', encoding='utf-8') as f:
        f.write(c)

fix_all(r'lib\core\intent_router.dart')
fix_all(r'lib\engines\physics\physics_v2\tools\physics_exam_overlay.dart')
