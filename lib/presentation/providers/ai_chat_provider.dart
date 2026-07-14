import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiChatState {
  final List<Map<String, dynamic>> messages;
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

  void addMessage(Map<String, dynamic> message) {
    state = AiChatState(messages: [...state.messages, message]);
  }

  void updateLastMessage(String text) {
    if (state.messages.isEmpty) return;
    final updated = List<Map<String, dynamic>>.from(state.messages);
    updated[updated.length - 1] = {
      ...updated.last,
      'text': text,
    };
    state = AiChatState(messages: updated);
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
