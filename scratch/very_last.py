import os

def fix_all(fp):
    if not os.path.exists(fp): return
    with open(fp, 'r', encoding='utf-8') as f:
        c = f.read()

    if 'intent_router.dart' in fp:
        c = c.replace('class IntentRouter {\n  bool _isLearningActive = false;', 'class IntentRouter {')
        c = c.replace('class MultiIntentRouter {', 'class MultiIntentRouter {\n  bool _isLearningActive = false;')
    
    if 'chemical_equation_execution_engine.dart' in fp:
        c = c.replace('calculateGibbsFreeEnergy(300.0, 0.0, 0.0, 0.0)', 'calculateGibbsFreeEnergy(300.0, 0.0, 0.0)')
        c = c.replace('isSpontaneous(300.0, 0.0, 0.0, 0.0)', 'isSpontaneous(300.0, 0.0, 0.0)')
        
    if 'web_3d_molecule_renderer.dart' in fp:
        c = c.replace('class Web3dMoleculeRenderer {\n  String _pendingFormat = "xyz";', 'class Web3dMoleculeRenderer {')
        c = c.replace('String? _pendingData;', 'String? _pendingData;\n  String? _pendingFormat;')
        
    if 'physics_exam_overlay.dart' in fp:
        c = c.replace('class PhysicsExamOverlay {\n  String? _expectedAnswer;', 'class PhysicsExamOverlay {')
        c = c.replace('class _PhysicsExamOverlayState extends State<PhysicsExamOverlay> {', 'class _PhysicsExamOverlayState extends State<PhysicsExamOverlay> {\n  String? _expectedAnswer;')
        # fix unchecked_use_of_nullable_value: The operator '-' can't be unconditionally invoked because the receiver can be 'null'.
        # error on line 69
        c = c.replace('double.parse(_expectedAnswer) -', 'double.parse(_expectedAnswer!) -')
        
    if 'ai_chat_panel.dart' in fp:
        c = c.replace('bool wasBlocked = false;\nif (wasBlocked) {', 'if (false) {')

    with open(fp, 'w', encoding='utf-8') as f:
        f.write(c)

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_all(os.path.join(root, file))
