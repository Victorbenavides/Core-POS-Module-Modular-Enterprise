import 'package:flutter/material.dart';
import 'pos_ai_service.dart';

class AiChatMessage {
  AiChatMessage(this.role, this.content);

  final String role; // 'user' | 'assistant'
  final String content;
}

class PosAiController extends ChangeNotifier {
  PosAiController({
    required this.service,
    required this.screenContextBuilder,
  });

  final PosAiService service;

  /// Función que devuelve el "prompt de sistema"
  /// según la pantalla actual (ventas, inventario, etc.)
  final String Function() screenContextBuilder;

  final List<AiChatMessage> _messages = [];
  bool _loading = false;
  String? _error;

  List<AiChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  String? get error => _error;

  void addUserMessage(String text) {
    _messages.add(AiChatMessage('user', text));
    notifyListeners();
    _sendToApi();
  }

  Future<void> _sendToApi() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final systemPrompt = screenContextBuilder();

      final payloadMessages = _messages
          .map((m) => {
                "role": m.role,
                "content": m.content,
              })
          .toList();

      final answer = await service.send(
        systemPrompt: systemPrompt,
        messages: payloadMessages,
      );

      _messages.add(AiChatMessage('assistant', answer));
    } catch (e) {
      _error = 'Error hablando con la IA: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void reset() {
    _messages.clear();
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
