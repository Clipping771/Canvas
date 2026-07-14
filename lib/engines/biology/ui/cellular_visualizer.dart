import 'package:flutter/material.dart';
import 'package:vinci_board/engines/biology/core/cellular_simulator.dart';

class CellularVisualizer extends StatefulWidget {
  final CellularSimulator simulator;

  const CellularVisualizer({super.key, required this.simulator});

  @override
  State<CellularVisualizer> createState() => _CellularVisualizerState();
}

class _CellularVisualizerState extends State<CellularVisualizer> {
  int _glucose = 1;
  int _oxygen = 6;

  @override
  Widget build(BuildContext context) {
    int atp = widget.simulator.calculateATPProduction(_glucose, _oxygen);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.coronavirus, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Cellular Respiration',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              const Text(
                'Glucose:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  if (_glucose > 0) setState(() => _glucose--);
                },
              ),
              Text(
                '$_glucose',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  setState(() => _glucose++);
                },
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'Oxygen (O2):',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  if (_oxygen > 0) setState(() => _oxygen--);
                },
              ),
              Text(
                '$_oxygen',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  setState(() => _oxygen++);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text(
                  'ATP Produced',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$atp',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  widget.simulator.advanceCellCycle();
                });
              },
              icon: const Icon(Icons.cyclone),
              label: Text(
                'Advance Phase: ${widget.simulator.currentPhase.name}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
