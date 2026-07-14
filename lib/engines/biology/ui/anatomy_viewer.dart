import 'package:flutter/material.dart';
import 'package:vinci_board/engines/biology/core/anatomy_simulator.dart';

class AnatomyViewer extends StatefulWidget {
  final AnatomySimulator simulator;

  const AnatomyViewer({super.key, required this.simulator});

  @override
  State<AnatomyViewer> createState() => _AnatomyViewerState();
}

class _AnatomyViewerState extends State<AnatomyViewer> {
  String _selectedSystem = 'Skeletal System';

  @override
  Widget build(BuildContext context) {
    final organList = widget.simulator.getOrgansForSystem(_selectedSystem);

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.2),
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
              Icon(Icons.accessibility_new, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Virtual Anatomy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Divider(),
          DropdownButton<String>(
            isExpanded: true,
            value: _selectedSystem,
            items: const [
              DropdownMenuItem(
                value: 'Skeletal System',
                child: Text('Skeletal System'),
              ),
              DropdownMenuItem(
                value: 'Muscular System',
                child: Text('Muscular System'),
              ),
              DropdownMenuItem(
                value: 'Nervous System',
                child: Text('Nervous System'),
              ),
              DropdownMenuItem(
                value: 'Cardiovascular System',
                child: Text('Cardiovascular System'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedSystem = val);
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Organs/Parts:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: organList
                .map(
                  (organ) => Chip(
                    label: Text(organ, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.red.shade50,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.simulator.getSystemDescription(_selectedSystem),
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
