import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/future/adapters/ai/ai_copilot_service.dart';

final aiCopilotServiceProvider = Provider<AiCopilotService>((ref) {
  return AiCopilotService();
});
