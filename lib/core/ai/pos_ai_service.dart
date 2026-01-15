import 'dart:convert';
import 'package:http/http.dart' as http;

/// Servicio mínimo para llamar a la API de OpenAI
class PosAiService {
  PosAiService({
    required this.apiKey,
    this.model = 'gpt-4.1-mini', // o el modelo que quieras usar
  });

  final String apiKey;
  final String model;

  static final Uri _endpoint =
      Uri.parse('https://api.openai.com/v1/responses');

  Future<String> send({
    required String systemPrompt,
    required List<Map<String, String>> messages,
  }) async {
    final body = {
      "model": model,
      "input": [
        {
          "role": "system",
          "content": systemPrompt,
        },
        ...messages,
      ],
    };

    final res = await http.post(
      _endpoint,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode >= 400) {
      throw Exception('Error IA ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return _extractText(data);
  }

  /// Extrae el texto de la Responses API.
  /// Formato típico:
  /// {
  ///   "output": [
  ///     {
  ///       "content": [
  ///         { "type": "output_text", "text": "Hola..." }
  ///       ]
  ///     }
  ///   ]
  /// }
  String _extractText(Map<String, dynamic> data) {
    final output = data['output'];

    if (output is List && output.isNotEmpty) {
      final buffer = StringBuffer();

      for (final out in output) {
        if (out is! Map<String, dynamic>) continue;

        final content = out['content'];
        if (content is! List) continue;

        for (final block in content) {
          if (block is! Map<String, dynamic>) continue;
          final type = block['type'];
          if (type == 'output_text') {
            final text = block['text'];
            if (text is String && text.trim().isNotEmpty) {
              if (buffer.isNotEmpty) buffer.writeln();
              buffer.write(text.trim());
            }
          }
        }
      }

      final result = buffer.toString().trim();
      if (result.isNotEmpty) {
        return result; // ✅ solo el texto del asistente
      }
    }

    // Fallback adicional por si en algún momento OpenAI añade un helper 'output_text'
    final ot = data['output_text'];
    if (ot is String && ot.trim().isNotEmpty) {
      return ot.trim();
    }

    // Último recurso: por debug, pero en teoría ya no deberías ver esto en UI.
    return data.toString();
  }
}
