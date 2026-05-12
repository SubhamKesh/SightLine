import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import 'speech_service.dart';
import 'ai_service.dart';

const String geminiApiKey = 'AIzaSyCyZHv-TvIf7MNn28xlRJ5_Wsr9SaogxHw';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({
    super.key,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SightLine',
      theme: ThemeData.dark(),
      home: CameraScreen(cameras: cameras),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({
    super.key,
    required this.cameras,
  });

  @override
  State<CameraScreen> createState() =>
      _CameraScreenState();
}

class _CameraScreenState
    extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;

  final SpeechService _speechService =
      SpeechService();

  late final AiService _aiService;

  StreamSubscription? _accelSubscription;

  Timer? _analysisTimer;

  bool _isProcessing = false;

  bool _isAutoMode = true;

  bool _privacyMode = false;

  bool _hasMotion = true;

  String _geminiResponse =
      "Initializing SightLine...";

  String _lastScene = "";

  DateTime _lastQuestionTime =
      DateTime.now();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _aiService = AiService(geminiApiKey);

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();

    await _speechService.init();

    await _initializeCamera();

    _setupMotionDetection();

    _startContinuousListening();

    _startAutomaticAnalysis();

    await _speechService.speak(
      "SightLine started.",
    );
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() {
        _geminiResponse =
            "No camera available.";
      });
      return;
    }

    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _geminiResponse =
            "Camera Error: $e";
      });
    }
  }

  void _setupMotionDetection() {
    _accelSubscription =
        userAccelerometerEventStream().listen(
      (event) {
        final movement =
            event.x.abs() +
            event.y.abs() +
            event.z.abs();

        _hasMotion = movement > 1.2;
      },
    );
  }

  void _startAutomaticAnalysis() {
    _analysisTimer?.cancel();

    _analysisTimer = Timer.periodic(
      const Duration(seconds: 4),
      (timer) async {
        if (!_isAutoMode) return;

        if (_privacyMode) return;

        if (_isProcessing) return;

        final recentlyAsked =
            DateTime.now()
                    .difference(
                      _lastQuestionTime,
                    )
                    .inSeconds <
                6;

        if (!recentlyAsked) {
          await _analyzeCurrentFrame();
        }
      },
    );
  }

  void _startContinuousListening() {
    _speechService.listen(
      (words) async {
        await _handleVoiceCommand(
          words,
        );
      },
    );
  }

  Future<void> _handleVoiceCommand(
    String command,
  ) async {
    final cmd =
        command.toLowerCase().trim();

    if (cmd.isEmpty) return;

    print("VOICE COMMAND: $cmd");

    if (cmd.contains(
      "privacy mode on",
    )) {
      _privacyMode = true;

      await _speechService.speak(
        "Privacy mode enabled.",
      );

      return;
    }

    if (cmd.contains(
      "privacy mode off",
    )) {
      _privacyMode = false;

      await _speechService.speak(
        "Privacy mode disabled.",
      );

      return;
    }

    if (cmd.contains(
      "stop navigation",
    )) {
      _isAutoMode = false;

      await _speechService.speak(
        "Navigation stopped.",
      );

      return;
    }

    if (cmd.contains(
      "start navigation",
    )) {
      _isAutoMode = true;

      await _speechService.speak(
        "Navigation started.",
      );

      return;
    }

    _lastQuestionTime =
        DateTime.now();

    

    await _analyzeCurrentFrame(
      customQuestion: cmd,
    );
  }

  Future<void> _analyzeCurrentFrame({
    String? customQuestion,
  }) async {
    final controller =
        _cameraController;

    if (controller == null ||
        !controller
            .value.isInitialized) {
      return;
    }

    if (_isProcessing) return;

    _isProcessing = true;

    try {
      final XFile picture =
          await controller
              .takePicture();

      final Uint8List bytes =
          await picture
              .readAsBytes();

      String prompt = '''
You are SightLine.

You help blind users understand surroundings and answer questions about what the camera sees.

RULES:
- Answer the user's question directly.
- Only warn about REAL immediate danger.
- Do NOT assume danger unless clearly visible.
- Keep replies under 2 short sentences.
- Be precise and natural.
- Mention direction and distance when useful.

Examples:
"Your bottle is on the table slightly right."
"Chair is 2 feet ahead."
"Move a little left to avoid the wall."

If there is NO danger, do NOT say danger.
''';

      if (customQuestion != null &&
          customQuestion
              .isNotEmpty) {
        prompt += '''

USER QUESTION:
$customQuestion

Answer directly.
''';
      }

      final responseText =
          await _aiService
              .analyzeImage(
        bytes,
        customPrompt: prompt,
      );

      if (!mounted) return;

      setState(() {
        _geminiResponse =
            responseText;
      });

      final cleaned =
          responseText
              .trim()
              .toLowerCase();

      final previous =
          _lastScene
              .trim()
              .toLowerCase();

      bool changed =
          cleaned != previous;

      bool danger =
          cleaned.contains(
                "danger",
              ) ||
              cleaned.contains(
                "warning",
              ) ||
              cleaned.contains(
                "stop",
              );

      if (customQuestion != null &&
          customQuestion
              .isNotEmpty) {
        changed = true;
      }

      if (_hasMotion) {
        changed = true;
      }

      if (danger || changed) {
        _lastScene = responseText;

        await _speechService
            .stopSpeaking();

        if (danger) {
          Vibration.vibrate(
            pattern: [
              500,
              200,
              500,
            ],
          );
        }

        await _speechService.speak(
          responseText,
        );
      }
    } catch (e) {
      print(e);

      if (!mounted) return;

      setState(() {
        _geminiResponse =
            "Gemini Error: $e";
      });
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    _analysisTimer?.cancel();

    _accelSubscription?.cancel();

    _cameraController?.dispose();

    _speechService.stopSpeaking();

    _speechService.stopListening();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "SightLine",
        ),
        actions: [
          Icon(
            _privacyMode
                ? Icons.lock
                : Icons.lock_open,
          ),
          const SizedBox(
            width: 12,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child:
                _cameraController !=
                            null &&
                        _cameraController!
                            .value
                            .isInitialized
                    ? CameraPreview(
                        _cameraController!,
                      )
                    : const Center(
                        child:
                            CircularProgressIndicator(),
                      ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              padding:
                  const EdgeInsets.all(
                16,
              ),
              child:
                  SingleChildScrollView(
                child: Text(
                  _geminiResponse,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton(
        backgroundColor:
            _privacyMode
                ? Colors.orange
                : _isAutoMode
                    ? Colors.green
                    : Colors.red,
        onPressed: () {
          setState(() {
            _isAutoMode =
                !_isAutoMode;
          });
        },
        child: Icon(
          _privacyMode
              ? Icons.lock
              : _isAutoMode
                  ? Icons.visibility
                  : Icons
                      .visibility_off,
        ),
      ),
    );
  }
}