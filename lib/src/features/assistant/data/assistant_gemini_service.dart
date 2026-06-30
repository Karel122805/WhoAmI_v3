import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'assistant_context_service.dart';
import 'assistant_prompt_builder.dart';

class AssistantGeminiService {
  static const String _apiKey = 'api_aqui';

  static const String _model = 'gemini-2.5-flash';

  final AssistantPromptBuilder _promptBuilder = AssistantPromptBuilder();

  Future<String> generateReply({
    required String text,
    required File? image,
    required AssistantContext context,
  }) async {
    try {
      final prompt = _promptBuilder.buildPrompt(
        text: text,
        hasImage: image != null,
        context: context,
      );

      final parts = <Map<String, dynamic>>[
        {'text': prompt},
      ];

      if (image != null) {
        final bytes = await image.readAsBytes();

        parts.add({
          'inline_data': {
            'mime_type': _mimeType(image.path),
            'data': base64Encode(bytes),
          },
        });
      }

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': parts,
            }
          ],
          'generationConfig': {
            'temperature': 0.8,
            'topP': 0.95,
            'maxOutputTokens': 900,
          },
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'ERROR REAL:\n${response.statusCode}\n${response.body}';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final candidates = data['candidates'] as List<dynamic>?;

      if (candidates == null || candidates.isEmpty) {
        return 'Estoy aquí contigo 💜 Cuéntame un poquito más para poder ayudarte mejor.';
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final responseParts = content?['parts'] as List<dynamic>?;

      if (responseParts == null || responseParts.isEmpty) {
        return 'Estoy aquí contigo 💜 Cuéntame un poquito más para poder ayudarte mejor.';
      }

      final buffer = StringBuffer();

      for (final part in responseParts) {
        if (part is Map<String, dynamic> && part['text'] != null) {
          buffer.write(part['text']);
        }
      }

      final reply = buffer.toString().trim();

      return reply.isNotEmpty
          ? reply
          : 'Estoy aquí contigo 💜 Cuéntame un poquito más para poder ayudarte mejor.';
    } catch (e) {
      return 'ERROR REAL:\n$e';
    }
  }

  String _mimeType(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';

    return 'image/jpeg';
  }
}