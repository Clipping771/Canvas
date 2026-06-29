import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiChatState {
  final List<Map<String, String>> messages;
  AiChatState({required this.messages});
}

class AiChatNotifier extends Notifier<AiChatState> {
  @override
  AiChatState build() {
    return AiChatState(
      messages: [
        {
          'sender': 'ai',
          'text':
              'Hi! I am your Agentic AI. I can see your canvas. What would you like me to do?',
        },
      ],
    );
  }

  void addMessage(Map<String, String> message) {
    state = AiChatState(messages: [...state.messages, message]);
  }

  void clear() {
    state = AiChatState(
      messages: [
        {
          'sender': 'ai',
          'text':
              'Hi! I am your Agentic AI. I can see your canvas. What would you like me to do?',
        },
      ],
    );
  }
}

final aiChatProvider = NotifierProvider<AiChatNotifier, AiChatState>(
  AiChatNotifier.new,
);
