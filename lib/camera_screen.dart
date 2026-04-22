import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'landmark_painter.dart';
import 'gemini_service.dart';
import 'tts_service.dart';
import 'translation_service.dart';
import 'session_service.dart';
import 'sign_buffer.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Camera
  CameraController? _controller;
  bool _isReady = false;
  bool _permissionDenied = false;
  bool _isProcessing = false;
  bool _isFrontCamera = true;

  // ML Kit
  List<PoseLandmark> _landmarks = [];
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  // Sign detection
  String _currentSign = '';
  final List<String> _predBuffer = [];
  List<String> _collectedSigns = [];

  // Services
  final GeminiService _gemini = GeminiService();
  final TTSService _tts = TTSService();
  final TranslationService _translator = TranslationService();
  final SessionService _sessions = SessionService();
  late SignBuffer _signBuffer;

  // UI state
  String _sentence = '';
  bool _isLoadingGemini = false;
  String _selectedLanguage = 'en';
  String _selectedLanguageCode = 'en-IN';

  final Map<String, Map<String, String>> _languages = {
    'en': {'name': 'English', 'ttsCode': 'en-IN'},
    'hi': {'name': 'Hindi', 'ttsCode': 'hi-IN'},
    'bn': {'name': 'Bengali', 'ttsCode': 'bn-IN'},
    'ta': {'name': 'Tamil', 'ttsCode': 'ta-IN'},
    'te': {'name': 'Telugu', 'ttsCode': 'te-IN'},
  };

  @override
  void initState() {
    super.initState();
    _signBuffer = SignBuffer(onSentenceReady: _onSentenceReady);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      setState(() => _permissionDenied = true);
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    CameraDescription selectedCamera = cameras[0];
    for (final cam in cameras) {
      if (cam.lensDirection == CameraLensDirection.front) {
        selectedCamera = cam;
        _isFrontCamera = true;
        break;
      }
    }

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _controller!.initialize();
    await _controller!.startImageStream(_processFrame);

    if (mounted) setState(() => _isReady = true);
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final bytes = image.planes[0].bytes;
      final imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final imageRotation = _isFrontCamera
          ? InputImageRotation.rotation270deg
          : InputImageRotation.rotation90deg;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final poses = await _poseDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _landmarks = poses.isNotEmpty
              ? poses.first.landmarks.values.toList()
              : [];
        });
      }

      // For now sign detection shows landmark count as placeholder
      // This will be replaced with actual model inference in next step
      if (_landmarks.isNotEmpty) {
        final mockSign = _getMockSign(_landmarks.length);
        _updatePrediction(mockSign);
      }
    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // Temporary mock sign detection based on landmark count
  // Replace this with actual model when model file is ready
  String _getMockSign(int landmarkCount) {
    return '';
  }

  void _updatePrediction(String sign) {
    _predBuffer.add(sign);
    if (_predBuffer.length > 8) _predBuffer.removeAt(0);

    final counts = <String, int>{};
    for (final s in _predBuffer) {
      if (s.isNotEmpty) counts[s] = (counts[s] ?? 0) + 1;
    }

    if (counts.isEmpty) return;

    final best = counts.entries.reduce((a, b) => a.value > b.value ? a : b);

    if (best.value >= 6 && best.key != _currentSign) {
      setState(() => _currentSign = best.key);
      _signBuffer.addSign(best.key);

      setState(() {
        _collectedSigns = _signBuffer.currentSigns;
      });

      FirebaseAnalytics.instance.logEvent(
        name: 'sign_detected',
        parameters: {'sign': best.key},
      );
    }
  }

  Future<void> _onSentenceReady(List<String> signs) async {
    setState(() {
      _isLoadingGemini = true;
      _collectedSigns = [];
      _currentSign = '';
    });

    FirebaseAnalytics.instance.logEvent(
      name: 'sentence_formed',
      parameters: {'sign_count': signs.length},
    );

    // Get sentence from Gemini
    String englishSentence = await _gemini.signsToSentence(signs);

    // Translate if needed
    String finalSentence = englishSentence;
    if (_selectedLanguage != 'en') {
      finalSentence = await _translator.translate(
        englishSentence,
        _selectedLanguage,
      );
    }

    setState(() {
      _sentence = finalSentence;
      _isLoadingGemini = false;
    });

    // Speak it
    await _tts.speak(finalSentence, languageCode: _selectedLanguageCode);

    FirebaseAnalytics.instance.logEvent(
      name: 'audio_played',
      parameters: {'language': _selectedLanguage},
    );

    // Save to Firestore
    await _sessions.saveSession(
      signs: signs,
      sentence: englishSentence,
      translatedSentence: finalSentence,
      language: _selectedLanguage,
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetector.close();
    _tts.dispose();
    _signBuffer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade900,
        title: const Text(
          'ISL Translator',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: _selectedLanguage,
              dropdownColor: Colors.teal.shade900,
              underline: const SizedBox(),
              icon: const Icon(Icons.language, color: Colors.white),
              items: _languages.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value['name']!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedLanguage = val;
                    _selectedLanguageCode = _languages[val]!['ttsCode']!;
                  });
                  FirebaseAnalytics.instance.logEvent(
                    name: 'language_changed',
                    parameters: {'language': val},
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildCameraView()),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (_permissionDenied) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Camera permission denied.\nPlease enable it in Settings.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_isReady) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.teal),
      );
    }

    return ClipRect(
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
            if (_landmarks.isNotEmpty)
              CustomPaint(
                painter: LandmarkPainter(
                  landmarks: _landmarks,
                  imageSize: Size(
                    _controller!.value.previewSize!.height,
                    _controller!.value.previewSize!.width,
                  ),
                  isFrontCamera: _isFrontCamera,
                ),
              ),
            // Signs collected so far
            if (_collectedSigns.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Wrap(
                  spacing: 6,
                  children: _collectedSigns.map((sign) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        sign,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      width: double.infinity,
      color: Colors.teal.shade900,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current sign
          Row(
            children: [
              const Text(
                'Detecting: ',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              Text(
                _currentSign.isEmpty ? '—' : _currentSign,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Sentence
          if (_isLoadingGemini)
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Forming sentence...',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            )
          else if (_sentence.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _sentence,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    _tts.replayLast();
                    FirebaseAnalytics.instance
                        .logEvent(name: 'audio_replayed');
                  },
                  icon: const Icon(Icons.volume_up, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            )
          else
            const Text(
              'Sign and pause to form a sentence',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
        ],
      ),
    );
  }
}