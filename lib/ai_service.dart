import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  final GenerativeModel _model;

  AiService(String apiKey)
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
        );

  Future<String> analyzeImage(
    Uint8List imageBytes, {
    String? customPrompt,
  }) async {
    try {
      final prompt = TextPart(
        customPrompt ??
            '''
You are SightLine.

You help blind users understand surroundings and answer questions about what the camera sees.

RULES:
- Answer the user's question directly.
- Only warn about REAL immediate danger.
- Do NOT assume danger unless clearly visible.
- Keep replies under 2 short sentences.
- Be precise and natural.
- Mention direction and distance when useful.

If there is NO danger, do NOT say danger.
''',
      );

      final imagePart = DataPart(
        'image/jpeg',
        imageBytes,
      );

      final response =
          await _model.generateContent([
        Content.multi([
          prompt,
          imagePart,
        ])
      ]);

      return response.text ??
          "No response.";
    } catch (e) {
      return "AI Error: $e";
    }
  }
}