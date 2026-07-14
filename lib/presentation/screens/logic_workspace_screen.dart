import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/presentation/providers/logic_simulation_provider.dart';

class LogicWorkspaceScreen extends ConsumerWidget {
  const LogicWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teslaEngine = ref.watch(teslaEngineProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tesla Engine - Logic Workspace')),
      body: Center(
        child: Text('Logic workspace ready. Simulation ticks: ${teslaEngine.hashCode}'),
      ),
    );
  }
}
