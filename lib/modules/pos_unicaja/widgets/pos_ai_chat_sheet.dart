import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:framework_as/core/ai/pos_ai_controller.dart';

class PosAiChatSheet extends StatelessWidget {
  const PosAiChatSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PosAiController>();
    final theme = Theme.of(context);

    final textController = TextEditingController();

    return SafeArea(
      child: SizedBox(
        height: 380,
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.smart_toy_outlined),
                const SizedBox(width: 8),
                Text(
                  'Asistencia de IA',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: ctrl.messages.length,
                itemBuilder: (_, index) {
                  final msg = ctrl.messages[index];
                  final isUser = msg.role == 'user';
                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUser
                            ? theme.colorScheme.primary.withOpacity(0.9)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg.content,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (ctrl.loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (ctrl.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  ctrl.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        hintText:
                            'Pregúntame algo o pide una acción...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (value) {
                        final text = value.trim();
                        if (text.isEmpty || ctrl.loading) return;
                        textController.clear();
                        ctrl.addUserMessage(text);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final text = textController.text.trim();
                      if (text.isEmpty || ctrl.loading) return;
                      textController.clear();
                      ctrl.addUserMessage(text);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
