import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  Future<bool> init() async {
    final ttsOk = await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    final sttOk = await _stt.initialize();
    return ttsOk != null && sttOk;
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> listen(Function(String) onResult) async {
    if (_stt.isAvailable) {
      _stt.listen(onResult: (result) {
        if (result.finalResult) {
          _stt.stop();
          onResult(result.recognizedWords);
        }
      });
    }
  }

  void stopListening() => _stt.stop();
  void stopSpeaking() => _tts.stop();
}