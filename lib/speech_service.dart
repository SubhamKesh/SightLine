import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();

  final SpeechToText _speech =
      SpeechToText();

  Future<void> init() async {
    await _tts.setLanguage("en-US");

    await _tts.setSpeechRate(0.5);

    await _tts.setPitch(1.0);

    await _speech.initialize();
  }

  Future<void> speak(
    String text,
  ) async {
    await _tts.stop();

    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  Future<void> listen(
    Function(String) onResult,
  ) async {
    bool available =
        await _speech.initialize();

    if (!available) return;

    _speech.listen(
      onResult: (result) {
        onResult(
          result.recognizedWords,
        );
      },

      partialResults: true,

      cancelOnError: false,

      listenMode: ListenMode.confirmation,

      onSoundLevelChange: (
        level,
      ) {},

      listenFor: const Duration(
        minutes: 30,
      ),

      pauseFor: const Duration(
        seconds: 5,
      ),

      onDevice: false,
    );

    _speech.statusListener =
        (status) {
      if (status == "done" ||
          status ==
              "notListening") {
        listen(onResult);
      }
    };
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }
}