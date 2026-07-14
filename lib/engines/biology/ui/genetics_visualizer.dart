import 'package:flutter/material.dart';
import 'package:vinci_board/engines/biology/core/genetics_simulator.dart';

class GeneticsVisualizer extends StatefulWidget {
  final GeneticsSimulator simulator;

  const GeneticsVisualizer({super.key, required this.simulator});

  @override
  State<GeneticsVisualizer> createState() => _GeneticsVisualizerState();
}

class _GeneticsVisualizerState extends State<GeneticsVisualizer> {
  String _dna = "TACGGCATTA";
  String _mrna = "";
  String _protein = "";

  @override
  void initState() {
    super.initState();
    _processDNA();
  }

  void _processDNA() {
    setState(() {
      _mrna = widget.simulator.transcribe(_dna);
      _protein = widget.simulator.translate(_mrna);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.2),
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
              Icon(Icons.biotech, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Genetics Simulator',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Divider(),
          const Text(
            'DNA Sequence:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          TextField(
            controller: TextEditingController(text: _dna),
            onChanged: (val) {
              _dna = val;
              _processDNA();
            },
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          const Text(
            'mRNA (Transcription):',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.blue.shade50,
            child: Text(
              _mrna,
              style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Protein (Translation):',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.red.shade50,
            child: Text(
              _protein,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
