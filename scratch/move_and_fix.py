import os, shutil, re

moves = [
    ('lib/adapters/ai/ai_copilot_service.dart', 'lib/future/adapters/ai/ai_copilot_service.dart'),
    ('lib/adapters/ai/api_model_fetcher.dart', 'lib/future/adapters/ai/api_model_fetcher.dart'),
    ('lib/adapters/auth/google_workspace_sso_adapter.dart', 'lib/future/adapters/auth/google_workspace_sso_adapter.dart'),
    ('lib/adapters/device/voice_recognition_service.dart', 'lib/future/adapters/device/voice_recognition_service.dart'),
    ('lib/adapters/lms/canvas_lms_adapter.dart', 'lib/future/adapters/lms/canvas_lms_adapter.dart'),
    ('lib/adapters/lms/google_classroom_adapter.dart', 'lib/future/adapters/lms/google_classroom_adapter.dart'),
    ('lib/core/intent_router.dart', 'lib/future/core/intent_router.dart'),
    ('lib/core/models/ai/ai_metadata.dart', 'lib/future/core/models/ai/ai_metadata.dart'),
    ('lib/core/ports/i_ai_provider_port.dart', 'lib/future/core/ports/i_ai_provider_port.dart'),
    ('lib/core/ports/i_storage_port.dart', 'lib/future/core/ports/i_storage_port.dart'),
    ('lib/engines/ai/ai_spawn_manager.dart', 'lib/future/engines/ai/ai_spawn_manager.dart'),
    ('lib/engines/biology/biology_engine.dart', 'lib/future/engines/biology/biology_engine.dart'),
    ('lib/engines/chemistry/ai/ai_chemical_workspace.dart', 'lib/future/engines/chemistry/ai/ai_chemical_workspace.dart'),
    ('lib/engines/chemistry/ai/assessment_engine.dart', 'lib/future/engines/chemistry/ai/assessment_engine.dart'),
    ('lib/engines/chemistry/ai/spectroscopy_engine.dart', 'lib/future/engines/chemistry/ai/spectroscopy_engine.dart'),
    ('lib/engines/chemistry/core/reaction_database.dart', 'lib/future/engines/chemistry/core/reaction_database.dart'),
    ('lib/engines/chemistry/crystal/crystal_engine.dart', 'lib/future/engines/chemistry/crystal/crystal_engine.dart'),
    ('lib/engines/chemistry/lab/experiment_recorder.dart', 'lib/future/engines/chemistry/lab/experiment_recorder.dart'),
    ('lib/engines/chemistry/lab/instruments.dart', 'lib/future/engines/chemistry/lab/instruments.dart'),
    ('lib/engines/chemistry/lab/inventory_system.dart', 'lib/future/engines/chemistry/lab/inventory_system.dart'),
    ('lib/engines/chemistry/rendering/native_2d_molecule_renderer.dart', 'lib/future/engines/chemistry/rendering/native_2d_molecule_renderer.dart'),
    ('lib/engines/chemistry/rendering/web_3d_molecule_renderer.dart', 'lib/future/engines/chemistry/rendering/web_3d_molecule_renderer.dart'),
    ('lib/engines/chemistry/solvers/gas_solver.dart', 'lib/future/engines/chemistry/solvers/gas_solver.dart'),
    ('lib/engines/chemistry/solvers/ph_solver.dart', 'lib/future/engines/chemistry/solvers/ph_solver.dart'),
    ('lib/engines/chemistry/solvers/stoichiometry_solver.dart', 'lib/future/engines/chemistry/solvers/stoichiometry_solver.dart'),
    ('lib/engines/chemistry/study_tools/calculators.dart', 'lib/future/engines/chemistry/study_tools/calculators.dart'),
    ('lib/engines/chemistry/study_tools/study_tools.dart', 'lib/future/engines/chemistry/study_tools/study_tools.dart'),
    ('lib/engines/logic/ai/auto_router_ai.dart', 'lib/future/engines/logic/ai/auto_router_ai.dart'),
    ('lib/engines/logic/components/active/diode.dart', 'lib/future/engines/logic/components/active/diode.dart'),
    ('lib/engines/logic/components/active/transistor.dart', 'lib/future/engines/logic/components/active/transistor.dart'),
    ('lib/engines/logic/core/logic_engine.dart', 'lib/future/engines/logic/core/logic_engine.dart'),
    ('lib/engines/logic/core/simulation_scheduler.dart', 'lib/future/engines/logic/core/simulation_scheduler.dart'),
    ('lib/engines/logic/core/transient_solver.dart', 'lib/future/engines/logic/core/transient_solver.dart'),
    ('lib/engines/logic/instruments/logic_analyzer.dart', 'lib/future/engines/logic/instruments/logic_analyzer.dart'),
    ('lib/engines/logic/instruments/multimeter.dart', 'lib/future/engines/logic/instruments/multimeter.dart'),
    ('lib/engines/logic/study/kmap_generator.dart', 'lib/future/engines/logic/study/kmap_generator.dart'),
    ('lib/engines/logic/virtual_lab/breadboard.dart', 'lib/future/engines/logic/virtual_lab/breadboard.dart'),
    ('lib/engines/logic/virtual_lab/pcb_router.dart', 'lib/future/engines/logic/virtual_lab/pcb_router.dart'),
    ('lib/engines/logic/virtual_lab/wire_physics.dart', 'lib/future/engines/logic/virtual_lab/wire_physics.dart'),
    ('lib/engines/math/core/geometry_engine.dart', 'lib/future/engines/math/core/geometry_engine.dart'),
    ('lib/engines/math/math_engine.dart', 'lib/future/engines/math/math_engine.dart'),
    ('lib/engines/math/ui/step_by_step_solver_view.dart', 'lib/future/engines/math/ui/step_by_step_solver_view.dart'),
    ('lib/engines/physics/physics_v2/ai/physics_ai_lab.dart', 'lib/future/engines/physics/physics_v2/ai/physics_ai_lab.dart'),
    ('lib/engines/sound/sound_engine.dart', 'lib/future/engines/sound/sound_engine.dart')
]

import_pattern = re.compile(r"(import|export)\s+['\"](.*?)['\"]")

def resolve_import(file_path, relative_import):
    if not relative_import.startswith('.'):
        return relative_import
    file_dir = os.path.dirname(file_path)
    target_path = os.path.normpath(os.path.join(file_dir, relative_import))
    target_path = target_path.replace('\\', '/')
    if target_path.startswith('lib/'):
        return target_path.replace('lib/', 'package:vinci_board/', 1)
    return relative_import

for src, dst in moves:
    src_path = os.path.normpath(src)
    dst_path = os.path.normpath(dst)
    
    if not os.path.exists(src_path):
        continue
        
    with open(src_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    new_content = content
    for match in import_pattern.finditer(content):
        prefix = match.group(1)
        rel_import = match.group(2)
        if rel_import.startswith('.'):
            resolved = resolve_import(src_path, rel_import)
            if resolved != rel_import:
                old_line = f"{prefix} '{rel_import}'"
                new_line = f"{prefix} '{resolved}'"
                old_line_2 = f"{prefix} \"{rel_import}\""
                new_line_2 = f"{prefix} \"{resolved}\""
                new_content = new_content.replace(old_line, new_line).replace(old_line_2, new_line_2)
                
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    with open(dst_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
        
    os.remove(src_path)

# Delete category A
deletes = [
    'lib/presentation/widgets/ai_avatar_widget.dart',
    'lib/presentation/widgets/gold_glow_container.dart',
    'test/scratch_test.dart',
    'test/chat_crash_test.dart'
]
for d in deletes:
    d_path = os.path.normpath(d)
    if os.path.exists(d_path):
        os.remove(d_path)
