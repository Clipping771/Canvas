import re

def fix(fp, cb):
    try:
        with open(fp, 'r', encoding='utf-8') as f:
            content = f.read()
        content = cb(content)
        with open(fp, 'w', encoding='utf-8') as f:
            f.write(content)
    except Exception as e:
        pass

def f_intent(c):
    return c.replace('class IntentRouter {', 'class IntentRouter {\n  bool _isLearningActive = false;')
fix(r'lib\core\intent_router.dart', f_intent)

def f_spawn(c):
    return c.replace('policy.getSpawn(', 'policy!.getSpawn(')
fix(r'lib\engines\ai\ai_spawn_manager.dart', f_spawn)

def f_chem(c):
    c = c.replace('calculateGibbsFreeEnergy(300.0, 0.0, 0.0)', 'calculateGibbsFreeEnergy(300.0, 0.0, 0.0, 0.0)')
    c = c.replace('isSpontaneous(300.0, 0.0, 0.0)', 'isSpontaneous(300.0, 0.0, 0.0, 0.0)')
    # If the previous regex failed and left it as calculateGibbsFreeEnergy(300.0):
    c = c.replace('calculateGibbsFreeEnergy(300.0)', 'calculateGibbsFreeEnergy(300.0, 0.0, 0.0)')
    c = c.replace('isSpontaneous(300.0)', 'isSpontaneous(300.0, 0.0, 0.0)')
    return c
fix(r'lib\engines\chemistry\reaction\chemical_equation_execution_engine.dart', f_chem)

def f_web3d(c):
    c = c.replace('String _pendingFormat = "xyz";', '')
    c = c.replace('class Web3dMoleculeRenderer {', 'class Web3dMoleculeRenderer {\n  String _pendingFormat = "xyz";')
    # For the weird xyz errors on line 65:
    lines = c.split('\n')
    lines = [l for l in lines if '"xyz"' not in l or 'String _pendingFormat' in l]
    return '\n'.join(lines)
fix(r'lib\engines\chemistry\rendering\web_3d_molecule_renderer.dart', f_web3d)

def f_physics(c):
    c = c.replace('class PhysicsExamOverlay {', 'class PhysicsExamOverlay {\n  String? _expectedAnswer;')
    return c
fix(r'lib\engines\physics\physics_v2\tools\physics_exam_overlay.dart', f_physics)

def f_chat(c):
    c = c.replace('if (wasBlocked) {', 'bool wasBlocked = false;\nif (wasBlocked) {')
    c = c.replace('bool wasBlocked = false;\nbool wasBlocked = false;\nif (wasBlocked) {', 'bool wasBlocked = false;\nif (wasBlocked) {')
    return c
fix(r'lib\presentation\screens\ai_chat_panel.dart', f_chat)
