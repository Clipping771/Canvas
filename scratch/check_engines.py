import glob, os

lib_dir = 'lib/engines'
all_engines = glob.glob(os.path.join(lib_dir, '**/*.dart'), recursive=True)

unimported = [
    'lib/engines/ai/ai_spawn_manager.dart',
    'lib/engines/biology/biology_engine.dart',
    'lib/engines/chemistry/ai/ai_chemical_workspace.dart',
    'lib/engines/chemistry/ai/assessment_engine.dart',
    'lib/engines/chemistry/ai/spectroscopy_engine.dart',
    'lib/engines/chemistry/core/reaction_database.dart',
    'lib/engines/chemistry/crystal/crystal_engine.dart',
    'lib/engines/chemistry/lab/experiment_recorder.dart',
    'lib/engines/chemistry/lab/instruments.dart',
    'lib/engines/chemistry/lab/inventory_system.dart',
    'lib/engines/chemistry/rendering/native_2d_molecule_renderer.dart',
    'lib/engines/chemistry/rendering/web_3d_molecule_renderer.dart',
    'lib/engines/chemistry/solvers/gas_solver.dart',
    'lib/engines/chemistry/solvers/ph_solver.dart',
    'lib/engines/chemistry/solvers/stoichiometry_solver.dart',
    'lib/engines/chemistry/study_tools/calculators.dart',
    'lib/engines/chemistry/study_tools/study_tools.dart',
    'lib/engines/logic/ai/auto_router_ai.dart',
    'lib/engines/logic/components/active/diode.dart',
    'lib/engines/logic/components/active/transistor.dart',
    'lib/engines/logic/core/logic_engine.dart',
    'lib/engines/logic/core/simulation_scheduler.dart',
    'lib/engines/logic/core/transient_solver.dart',
    'lib/engines/logic/instruments/logic_analyzer.dart',
    'lib/engines/logic/instruments/multimeter.dart',
    'lib/engines/logic/study/kmap_generator.dart',
    'lib/engines/logic/virtual_lab/breadboard.dart',
    'lib/engines/logic/virtual_lab/pcb_router.dart',
    'lib/engines/logic/virtual_lab/wire_physics.dart',
    'lib/engines/math/core/geometry_engine.dart',
    'lib/engines/math/math_engine.dart',
    'lib/engines/math/ui/step_by_step_solver_view.dart',
    'lib/engines/physics/physics_v2/ai/physics_ai_lab.dart',
    'lib/engines/sound/sound_engine.dart'
]

unimported = [os.path.normpath(u) for u in unimported]

imported = []
for e in all_engines:
    if os.path.normpath(e) not in unimported:
        imported.append(e)

print('Imported Engine Files:')
for i in imported: print(i)
