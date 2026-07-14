import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/presentation/providers/math_physics_provider.dart';

class PhysicsAiLabWidget extends ConsumerWidget {
  const PhysicsAiLabWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final physicsEngine = ref.watch(physicsEngineProvider);
    return Positioned(
      bottom: 20,
      left: 20,
      child: Card(
        color: Colors.black87,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Physics AI Lab',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  physicsEngine.setScenario(
                    physicsEngine.currentScenario,
                  ); // dummy call for now
                },
                child: const Text('Interact'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
