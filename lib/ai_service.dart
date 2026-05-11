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
    Uint8List imageBytes,
  ) async {
    try {
      final prompt = TextPart(
'''
You are a real-time navigation assistant for blind users.

Continuously guide the user.

ONLY mention:
- obstacles
- walls
- people
- vehicles
- stairs
- doors
- pathways
- moving dangers

Always mention:
- direction
- approximate distance

Examples:
"Chair 2 feet ahead."
"Wall close on left."
"Person approaching from right."
"Clear path ahead."

If danger exists start with:
DANGER:

Keep responses short.
Maximum 2 short sentences.
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