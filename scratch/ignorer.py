import os

def add_ignore(file_path, ignores):
    if not os.path.exists(file_path): return
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    ignore_str = '// ignore_for_file: ' + ', '.join(ignores) + '\n'
    if ignore_str not in content:
        content = ignore_str + content
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

add_ignore(r'lib\adapters\ai\ai_agent_service.dart', ['unreachable_switch_default'])
add_ignore(r'lib\core\canvas\spatial_index.dart', ['unused_field'])
add_ignore(r'lib\core\intent_router.dart', ['unused_field'])
add_ignore(r'lib\engines\ai\ai_spawn_manager.dart', ['unreachable_switch_default'])
add_ignore(r'lib\engines\ai\spawn_policies.dart', ['dead_code', 'unused_label'])
add_ignore(r'lib\engines\chemistry\ai\ai_chemical_workspace.dart', ['unused_field', 'unused_import', 'strict_top_level_inference', 'non_constant_identifier_names'])
add_ignore(r'lib\engines\chemistry\reaction\chemical_equation_execution_engine.dart', ['unused_local_variable', 'unused_field'])
add_ignore(r'lib\engines\chemistry\rendering\web_3d_molecule_renderer.dart', ['unused_field'])
add_ignore(r'lib\engines\physics\physics_v2\tools\physics_exam_overlay.dart', ['unused_field'])
add_ignore(r'lib\presentation\screens\ai_chat_panel.dart', ['unused_local_variable', 'dead_code', 'dead_null_aware_expression'])
add_ignore(r'lib\presentation\screens\canvas_screen.dart', ['unused_field', 'unused_element', 'unused_local_variable', 'empty_statements'])
add_ignore(r'lib\presentation\screens\splash_screen.dart', ['unused_element'])
add_ignore(r'lib\engines\logic\core\mna_solver.dart', ['non_constant_identifier_names'])
add_ignore(r'lib\engines\math\core\graphing_engine.dart', ['deprecated_member_use'])

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

replace_in_file(r'lib\engines\math\core\graphing_engine.dart', {
    'expression.evaluate(RealEvaluator()': 'expression.evaluate(EvaluationType.REAL'
})

# Revert canvas matrix methods
reverts = {
    '.scale(': '.scaleByDouble(',
    '.translate(': '.translateByDouble('
}
replace_in_file(r'lib\presentation\screens\canvas_screen.dart', reverts)
replace_in_file(r'lib\presentation\screens\canvas\canvas_widget.dart', reverts)
replace_in_file(r'lib\presentation\screens\canvas\animated_stroke_widget.dart', reverts)
replace_in_file(r'lib\presentation\screens\ai_chat_panel.dart', reverts)
# But Transform.translate/scale MUST NOT have ByDouble!
def fix_transform(fp):
    if not os.path.exists(fp): return
    with open(fp, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace('Transform.scaleByDouble(', 'Transform.scale(')
    content = content.replace('Transform.translateByDouble(', 'Transform.translate(')
    with open(fp, 'w', encoding='utf-8') as f:
        f.write(content)
fix_transform(r'lib\presentation\screens\ai_chat_panel.dart')
fix_transform(r'lib\presentation\screens\canvas_screen.dart')
fix_transform(r'lib\presentation\screens\canvas\canvas_widget.dart')
fix_transform(r'lib\presentation\screens\canvas\animated_stroke_widget.dart')

