import os, shutil

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

for src, dst in moves:
    src_path = os.path.normpath(src)
    dst_path = os.path.normpath(dst)
    if os.path.exists(src_path):
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        shutil.move(src_path, dst_path)

# Deletions
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
