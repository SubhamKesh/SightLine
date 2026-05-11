import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  final GenerativeModel _model;
  
  static const String _systemInstruction = 
      "You are a vision assistant for the blind. Analyze this frame. "
      "1. If there is immediate DANGER (stairs, traffic, obstacles), start with 'DANGER: '. "
      "2. Read any visible text (OCR). "
      "3. Describe the scene briefly. "
      "Keep it under 30 words.";

  AiService(String apiKey) 
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
        );

  Future<String> analyzeImage(Uint8List bytes) async {
    try {
      final prompt = TextPart(_systemInstruction);
      final imagePart = DataPart('image/jpeg', bytes);
      
      final content = [Content.multi([prompt, imagePart])];
      final response = await _model.generateContent(content);
      
      final text = response.text;
      if (text == null || text.isEmpty) return "I couldn't identify anything.";
      return text;
    } catch (e) {
      return "Analysis error: $e";
    }
  }
}