import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();

  final SpeechToText _speech =
      SpeechToText();

  bool _isListening = false;

  bool _isInitialized = false;

  Function(String)? _onResult;

  Future<void> init() async {
    await _tts.setLanguage("en-US");

    await _tts.setSpeechRate(0.45);

    await _tts.setPitch(1.0);

    await _tts.awaitSpeakCompletion(
      true,
    );

    _isInitialized =
        await _speech.initialize();

    _tts.setCompletionHandler(() async {
      await Future.delayed(
        const Duration(
          milliseconds: 300,
        ),
      );

      _restartListening();
    });
  }

  Future<void> speak(
    String text,
  ) async {
    if (text.trim().isEmpty) return;

    await stopListening();

    await _tts.stop();

    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  Future<void> listen(
    Function(String) onResult,
  ) async {
    _onResult = onResult;

    await _restartListening();
  }

  Future<void> _restartListening() async {
    if (!_isInitialized) return;

    if (_isListening) return;

    _isListening = true;

    await _speech.listen(
      onResult: (result) async {
        final words =
            result.recognizedWords
                .trim();

        print("WORDS: $words");

        if (result.finalResult &&
            words.isNotEmpty) {
          _isListening = false;

          await _speech.stop();

          if (_onResult != null) {
            _onResult!(words);
          }
        }
      },

      partialResults: false,

      cancelOnError: false,

      listenMode:
          ListenMode.dictation,

      listenFor: const Duration(
        minutes: 30,
      ),

      pauseFor: const Duration(
        seconds: 5,
      ),

      onDevice: false,

      onSoundLevelChange: (level) {
        print("MIC LEVEL: $level");
      },
    );
  }

  Future<void> stopListening() async {
    _isListening = false;

    await _speech.stop();
  }
}