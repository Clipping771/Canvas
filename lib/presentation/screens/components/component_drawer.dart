import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/core/models/canvas_environment.dart';
import 'package:vinci_board/presentation/providers/drawing_provider.dart';
import 'package:vinci_board/presentation/widgets/glassmorphic_panel.dart';

class ComponentDrawer extends ConsumerWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const ComponentDrawer({
    super.key,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(drawingProvider).canvasEnvironment;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutBack,
      right: isOpen ? 20 : -220, // Slide in/out
      top: 100,
      bottom: 100,
      child: GlassmorphicPanel(
        width: 200,
        color: Colors.black.withValues(alpha: 0.6),
        borderColor: Colors.blueAccent.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Components',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: onToggle,
                ),
              ],
            ),
            const Divider(color: Colors.white30),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (environment == CanvasEnvironment.electronics) ...[
                    _buildComponentItem(Icons.battery_charging_full, 'Battery'),
                    _buildComponentItem(Icons.horizontal_rule, 'Ground'),
                    _buildComponentItem(Icons.toggle_off, 'Switch'),
                    _buildComponentItem(Icons.lightbulb, 'LED'),
                    _buildComponentItem(Icons.show_chart, 'Resistor'),
                    _buildComponentItem(Icons.view_agenda, 'Capacitor'),
                    _buildComponentItem(Icons.line_style, 'Inductor'),
                    _buildComponentItem(Icons.timer, 'Clock'),
                    _buildComponentItem(Icons.memory, 'MCU'),
                    _buildComponentItem(Icons.rotate_right, 'Motor'),
                    _buildComponentItem(Icons.monitor_heart, 'Oscilloscope'),
                    _buildComponentItem(Icons.input, 'AND Gate'),
                    _buildComponentItem(Icons.arrow_forward, 'OR Gate'),
                    _buildComponentItem(Icons.warning, 'NOT Gate'),
                  ] else if (environment == CanvasEnvironment.chemistry) ...[
                    _buildComponentItem(Icons.science, 'Beaker'),
                    _buildComponentItem(Icons.biotech, 'Microscope'),
                    _buildComponentItem(Icons.coronavirus, 'Cell'),
                    _buildComponentItem(Icons.biotech, 'Genetics'),
                  ] else ...[
                    _buildComponentItem(Icons.functions, 'Equation'),
                    _buildComponentItem(Icons.accessibility_new, 'Anatomy'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentItem(IconData icon, String label) {
    return Draggable<String>(
      data: label,
      feedback: Material(
        color: Colors.transparent,
        child: GlassmorphicPanel(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(
            8,
          ), // Reduced padding to prevent overflow
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.blueAccent, size: 30),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildListItem(icon, label),
      ),
      child: _buildListItem(icon, label),
    );
  }

  Widget _buildListItem(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
