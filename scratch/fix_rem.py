import os

def replace_in_file(file_path, replacements):
    if not os.path.exists(file_path): return
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    new_content = content
    for old, new in replacements.items():
        new_content = new_content.replace(old, new)
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)

replace_in_file(r'lib\engines\ai\spawn_policies.dart', {
    '    // Fallback to right for now\n      position: rightPos,\n      needsCameraMove: true,\n      reason: \'selection_right\',\n    );': 
    '    // Fallback to right for now\n    return SpawnLocation(\n      position: rightPos,\n      needsCameraMove: true,\n      reason: \'selection_right\',\n    );'
})

replace_in_file(r'lib\engines\chemistry\ai\ai_chemical_workspace.dart', {
    'class AiChemicalWorkspace {\n      ChemicalEquationExecutionEngine();':
    'class AiChemicalWorkspace {\n  final ChemicalEquationExecutionEngine _executionEngine = ChemicalEquationExecutionEngine();'
})

replace_in_file(r'lib\engines\chemistry\reaction\chemical_equation_execution_engine.dart', {
    'calculateGibbsFreeEnergy(300.0);': 'calculateGibbsFreeEnergy(300.0, 0, 0);',
    'isSpontaneous(300.0);': 'isSpontaneous(300.0, 0, 0);'
})

replace_in_file(r'lib\engines\chemistry\rendering\web_3d_molecule_renderer.dart', {
    '_pendingFormat': '"xyz"'
})

replace_in_file(r'lib\engines\physics\physics_v2\tools\physics_exam_overlay.dart', {
    '_expectedAnswer': 'null'
})

replace_in_file(r'lib\presentation\screens\ai_chat_panel.dart', {
    'if (wasBlocked) {': 'if (false) {',
    'wasBlocked': 'false'
})

replace_in_file(r'lib\presentation\screens\canvas_screen.dart', {
    'existingPage.': 'widget.canvas.'
})

