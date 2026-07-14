import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vinci_board/presentation/widgets/glassmorphic_panel.dart';

class PropertiesInspector extends StatelessWidget {
  final Map<String, dynamic>? selectedComponentData;
  final Function(String, dynamic) onUpdateProperty;
  final VoidCallback onClose;

  const PropertiesInspector({
    super.key,
    required this.selectedComponentData,
    required this.onUpdateProperty,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedComponentData == null) return const SizedBox.shrink();

    return Positioned(
      left: 20,
      top: 100,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: selectedComponentData != null ? 1.0 : 0.0,
        child: GlassmorphicPanel(
          width: 250,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Inspector',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(color: Colors.white30),
              const SizedBox(height: 8),
              ...selectedComponentData!.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        height: 30,
                        child: TextField(
                          controller: TextEditingController(
                            text: entry.value.toString(),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          onSubmitted: (val) {
                            HapticFeedback.lightImpact();
                            onUpdateProperty(entry.key, val);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
