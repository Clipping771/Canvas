import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/presentation/providers/drawing_provider.dart';
import 'package:vinci_board/core/models/tool_type.dart';
import 'package:vinci_board/engines/physics/physics_engine.dart';
import 'dart:async';
import 'package:vinci_board/core/widgets/glass_container.dart';

/// Layer 4: Virtual Instrument - Heads Up Display
/// Shows real-time physics data for moving objects.
class PhysicsHUD extends ConsumerStatefulWidget {
  const PhysicsHUD({super.key});

  @override
  ConsumerState<PhysicsHUD> createState() => _PhysicsHUDState();
}

class _PhysicsHUDState extends ConsumerState<PhysicsHUD> {
  bool _isExpanded = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_isExpanded && mounted) {
        setState(() {}); // Refresh UI to fetch latest scenario
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scenario = PhysicsEngine().currentScenario;
    final drawingState = ref.watch(drawingProvider);
    final hasActivePhysics = drawingState.strokes.any((s) => s.physicsEnabled);

    if (!_isExpanded) {
      return FloatingActionButton.small(
        heroTag: 'physics_hud_toggle',
        backgroundColor: Colors
            .blueAccent, // Matches AppColors.primary visually in this context
        foregroundColor: Colors.white,
        child: const Icon(Icons.speed),
        onPressed: () => setState(() => _isExpanded = true),
      );
    }

    return GlassContainer(
      width: 225,
      blur: 20.0,
      opacity: 0.6,
      color: Colors.black.withValues(alpha: 0.5),
      border: Border.all(
        color: Colors.blueAccent.withValues(alpha: 0.3),
        width: 1,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed, color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'INSTRUMENT PANEL',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _isExpanded = false),
                child: const Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRow('Physics', scenario.name),
          _buildRow(
            'Gravity (y)',
            '${scenario.gravity.dy.toStringAsFixed(2)} m/s²',
          ),
          _buildRow('Air Density', '${scenario.atmosphereDensity} kg/m³'),
          const Divider(color: Colors.white24, height: 24),
          const Text(
            'Draw shapes and simulate gravity:',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          hasActivePhysics
              ? SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 16),
                    label: const Text(
                      'Stop Simulation',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      ref.read(drawingProvider.notifier).stopSimulation();
                    },
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text(
                      'Apply Gravity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      final strokes = ref.read(drawingProvider).strokes;
                      final shapes = strokes
                          .where(
                            (s) =>
                                s.toolType != ToolType.wire &&
                                s.toolType != ToolType.widget &&
                                s.text == null,
                          )
                          .toList();
                      if (shapes.isNotEmpty) {
                        ref
                            .read(drawingProvider.notifier)
                            .applyGravityToStrokes(
                              shapes.map((s) => s.id).toList(),
                            );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Draw some shapes on the canvas first!',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
