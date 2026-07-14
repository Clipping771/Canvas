enum CopilotActionType { addComponent, solveMath, drawGeometry, none }

class CopilotIntent {
  final CopilotActionType actionType;
  final String payload;
  final Map<String, dynamic> metadata;

  CopilotIntent({
    required this.actionType,
    required this.payload,
    this.metadata = const {},
  });
}

class AiCopilotService {
  /// Analyzes a prompt (voice or text) and returns a structured intent.
  Future<CopilotIntent> parseIntent(String prompt) async {
    // In production, this sends the prompt to a Gemini backend for NLP intent extraction.

    // Mock parsing logic based on keywords
    String p = prompt.toLowerCase();

    if (p.contains('draw') &&
        (p.contains('resistor') || p.contains('battery'))) {
      String component = p.contains('resistor') ? 'Resistor' : 'Battery';
      return CopilotIntent(
        actionType: CopilotActionType.addComponent,
        payload: component,
      );
    } else if (p.contains('solve') || p.contains('calculate')) {
      return CopilotIntent(
        actionType: CopilotActionType.solveMath,
        payload: 'Solve expression',
      );
    } else if (p.contains('draw') &&
        (p.contains('circle') || p.contains('square'))) {
      String shape = p.contains('circle') ? 'Circle' : 'Square';
      return CopilotIntent(
        actionType: CopilotActionType.drawGeometry,
        payload: shape,
      );
    }

    return CopilotIntent(actionType: CopilotActionType.none, payload: prompt);
  }
}
