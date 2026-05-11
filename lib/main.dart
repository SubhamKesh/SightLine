import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import 'speech_service.dart';
import 'ai_service.dart';

const String geminiApiKey = 'AIzaSyA_i_9yFsYRSxYYilH3wN1Lugqz74RCAzA';

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
      title: 'Vision Assistant',
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

  bool _hasMotion = true;

  String _geminiResponse =
      "Initializing vision assistant...";

  String _lastScene = "";

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
      "Vision assistant started.",
    );

    await _analyzeCurrentFrame();
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

        _hasMotion = movement > 1.0;
      },
    );
  }

  void _startAutomaticAnalysis() {
    _analysisTimer?.cancel();

    _analysisTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) async {
        if (_isAutoMode) {
          await _analyzeCurrentFrame();
        }
      },
    );
  }

  void _startContinuousListening() {
    _speechService.listen(
      (words) {
        _handleVoiceCommand(words);
      },
    );
  }

  void _handleVoiceCommand(
    String command,
  ) async {
    final cmd = command.toLowerCase();

    print("VOICE COMMAND: $cmd");

    if (cmd.contains("what") ||
        cmd.contains("describe") ||
        cmd.contains("where")) {
      await _speechService.stopSpeaking();

      await _analyzeCurrentFrame();
    }

    if (cmd.contains("stop")) {
      setState(() {
        _isAutoMode = false;
      });

      await _speechService.speak(
        "Automatic mode disabled.",
      );
    }

    if (cmd.contains("start")) {
      setState(() {
        _isAutoMode = true;
      });

      await _speechService.speak(
        "Automatic mode enabled.",
      );
    }
  }

  Future<void> _analyzeCurrentFrame() async {
    final controller = _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (_isProcessing) return;

    _isProcessing = true;

    try {
      final XFile picture =
          await controller.takePicture();

      final Uint8List bytes =
          await picture.readAsBytes();

      final responseText =
          await _aiService.analyzeImage(
        bytes,
      );

      print(responseText);

      if (!mounted) return;

      setState(() {
        _geminiResponse = responseText;
      });

      final cleaned =
          responseText
              .trim()
              .toLowerCase();

      final previous =
          _lastScene
              .trim()
              .toLowerCase();

      final changed =
          cleaned != previous;

      if (changed) {
        _lastScene = responseText;

        await _speechService
            .stopSpeaking();

        if (responseText
            .toUpperCase()
            .contains("DANGER")) {
          Vibration.vibrate(
            pattern: [
              500,
              200,
              500,
              200
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
          "Vision Assistant",
        ),
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
            _isAutoMode
                ? Colors.green
                : Colors.red,
        onPressed: () {
          setState(() {
            _isAutoMode =
                !_isAutoMode;
          });
        },
        child: Icon(
          _isAutoMode
              ? Icons.visibility
              : Icons
                  .visibility_off,
        ),
      ),
    );
  }
}