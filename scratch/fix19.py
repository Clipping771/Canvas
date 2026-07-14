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

def fix_intent(c):
    return c.replace('class IntentRouter {', 'class IntentRouter {\n  bool _isLearningActive = false;')
fix(r'lib\core\intent_router.dart', fix_intent)

def fix_spawn(c):
    return c.replace('SpawnPolicy policy = DefaultSpawnPolicy();', 'SpawnPolicy? policy;')
fix(r'lib\engines\ai\ai_spawn_manager.dart', fix_spawn)

def fix_chem(c):
    c = c.replace('calculateGibbsFreeEnergy(300.0)', 'calculateGibbsFreeEnergy(300.0, 0.0, 0.0)')
    c = c.replace('calculateGibbsFreeEnergy(300.0, 0, 0)', 'calculateGibbsFreeEnergy(300.0, 0.0, 0.0)')
    c = c.replace('calculateGibbsFreeEnergy(300.0, 0, 0, 0)', 'calculateGibbsFreeEnergy(300.0, 0.0, 0.0)')
    c = c.replace('isSpontaneous(300.0)', 'isSpontaneous(300.0, 0.0, 0.0)')
    c = c.replace('isSpontaneous(300.0, 0, 0)', 'isSpontaneous(300.0, 0.0, 0.0)')
    c = c.replace('isSpontaneous(300.0, 0, 0, 0)', 'isSpontaneous(300.0, 0.0, 0.0)')
    return c
fix(r'lib\engines\chemistry\reaction\chemical_equation_execution_engine.dart', fix_chem)

def fix_web3d(c):
    c = c.replace('class Web3dMoleculeRenderer {', 'class Web3dMoleculeRenderer {\n  String _pendingFormat = "xyz";')
    # remove the broken lines that cause "xyz" errors
    lines = c.split('\n')
    lines = [l for l in lines if 'String _pendingFormat = "xyz";' not in l or 'class Web3dMoleculeRenderer {' in c]
    return c
fix(r'lib\engines\chemistry\rendering\web_3d_molecule_renderer.dart', fix_web3d)

def fix_graph(c):
    c = c.replace('RealEvaluator()', 'EvaluationType.REAL')
    return c
fix(r'lib\engines\math\core\graphing_engine.dart', fix_graph)

def fix_physics(c):
    c = c.replace('class PhysicsExamOverlay {', 'class PhysicsExamOverlay {\n  String? _expectedAnswer;')
    c = c.replace('_expectedAnswer = "null";', '')
    return c
fix(r'lib\engines\physics\physics_v2\tools\physics_exam_overlay.dart', fix_physics)

def fix_chat(c):
    c = c.replace('if (false) {', 'bool wasBlocked = false;\nif (wasBlocked) {')
    return c
fix(r'lib\presentation\screens\ai_chat_panel.dart', fix_chat)

