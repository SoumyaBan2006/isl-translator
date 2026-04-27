import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
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
import 'sign_classifier.dart';

class CameraScreen extends StatefulWidget {
  final VoidCallback? onGoToHistory;
  const CameraScreen({super.key, this.onGoToHistory});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isReady = false;
  bool _permissionDenied = false;
  bool _isProcessing = false;
  bool _isFrontCamera = true;

  List<PoseLandmark> _landmarks = [];
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  final SignClassifier _classifier = SignClassifier();

  String _currentSign = '';
  final List<String> _predBuffer = [];
  List<String> _collectedSigns = [];

  final GeminiService _gemini = GeminiService();
  final TTSService _tts = TTSService();
  final TranslationService _translator = TranslationService();
  final SessionService _sessions = SessionService();
  late SignBuffer _signBuffer;

  bool _isTranslating = false;
  String _sentence = '';
  bool _isLoadingGemini = false;
  String _selectedLanguage = 'en';
  String _selectedLanguageCode = 'en-IN';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final Map<String, Map<String, String>> _languages = {
    'en': {'name': 'English', 'ttsCode': 'en-IN'},
    'hi': {'name': 'हिंदी', 'ttsCode': 'hi-IN'},
    'bn': {'name': 'বাংলা', 'ttsCode': 'bn-IN'},
    'ta': {'name': 'தமிழ்', 'ttsCode': 'ta-IN'},
    'te': {'name': 'తెలుగు', 'ttsCode': 'te-IN'},
  };

  final List<List<String>> _signGuide = [
    ['Hello', 'Raise right hand high above your shoulder'],
    ['I', 'Point right hand to your chest'],
    ['You', 'Extend right arm forward and outward'],
    ['We', 'Cross both wrists close together at chest'],
    ['Thank You', 'Both hands at lower chest, spread apart'],
    ['Good Morning', 'Raise both arms wide above shoulders'],
    ['How Are You', 'Extend both arms outward at shoulder height'],
    ['Mother', 'Right hand near your chin'],
    ['Father', 'Right hand near your forehead'],
    ['Help', 'Right hand above left hand, both in front'],
    ['Bird', 'Both hands at chest, one higher than other'],
    ['Monday', 'Right hand at mid chest, to the right'],
    ['Dog', 'Right hand patting at hip level'],
  ];

  @override
  void initState() {
    super.initState();
    _signBuffer = SignBuffer(onSentenceReady: _onSentenceReady);
    _initCamera();
    _classifier.load();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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
      final imageSize =
          Size(image.width.toDouble(), image.height.toDouble());
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
      if (_landmarks.isNotEmpty &&
          _classifier.isLoaded &&
          _isTranslating) {
        _updatePredictionFromPose(_landmarks);
      }
    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _updatePredictionFromPose(List<PoseLandmark> landmarks) {
    final sign = _classifier.predictFromPose(landmarks);
    if (sign.isNotEmpty) _updatePrediction(sign);
  }

  void _updatePrediction(String sign) {
    _predBuffer.add(sign);
    if (_predBuffer.length > 12) _predBuffer.removeAt(0);
    final counts = <String, int>{};
    for (final s in _predBuffer) {
      if (s.isNotEmpty) counts[s] = (counts[s] ?? 0) + 1;
    }
    if (counts.isEmpty) return;
    final best =
        counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (best.value >= 8 && best.key != _currentSign) {
      setState(() => _currentSign = best.key);
      _signBuffer.addSign(best.key);
      setState(() => _collectedSigns = _signBuffer.currentSigns);
      HapticFeedback.lightImpact();
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
    final formattedSigns =
        signs.map(SignClassifier.formatSign).toList();
    String englishSentence =
        await _gemini.signsToSentence(formattedSigns);
    String finalSentence = englishSentence;
    if (_selectedLanguage != 'en') {
      finalSentence = await _translator.translate(
          englishSentence, _selectedLanguage);
    }
    setState(() {
      _sentence = finalSentence;
      _isLoadingGemini = false;
    });
    await _tts.speak(finalSentence,
        languageCode: _selectedLanguageCode);
    FirebaseAnalytics.instance.logEvent(
      name: 'audio_played',
      parameters: {'language': _selectedLanguage},
    );
    await _sessions.saveSession(
      signs: formattedSigns,
      sentence: englishSentence,
      translatedSentence: finalSentence,
      language: _selectedLanguage,
    );
  }

  void _clearAll() {
    setState(() {
      _collectedSigns = [];
      _currentSign = '';
      _sentence = '';
      _predBuffer.clear();
    });
    _signBuffer.clear();
  }

  void _toggleTranslating() {
    setState(() {
      _isTranslating = !_isTranslating;
      if (!_isTranslating) {
        _predBuffer.clear();
        _currentSign = '';
      }
    });
    HapticFeedback.mediumImpact();
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Output language',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._languages.entries.map((e) => ListTile(
                  onTap: () {
                    setState(() {
                      _selectedLanguage = e.key;
                      _selectedLanguageCode =
                          e.value['ttsCode']!;
                    });
                    FirebaseAnalytics.instance.logEvent(
                      name: 'language_changed',
                      parameters: {'language': e.key},
                    );
                    Navigator.pop(context);
                  },
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _selectedLanguage == e.key
                          ? const Color(0xFF085041)
                          : const Color(0xFF1a1a1a),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.language,
                        color: _selectedLanguage == e.key
                            ? const Color(0xFF4ade80)
                            : Colors.white38,
                        size: 18),
                  ),
                  title: Text(e.value['name']!,
                      style: TextStyle(
                          color: _selectedLanguage == e.key
                              ? const Color(0xFF4ade80)
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: _selectedLanguage == e.key
                              ? FontWeight.w600
                              : FontWeight.w400)),
                  trailing: _selectedLanguage == e.key
                      ? const Icon(Icons.check,
                          color: Color(0xFF4ade80), size: 18)
                      : null,
                )),
          ],
        ),
      ),
    );
  }

  void _showSignGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Sign guide',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Hold each pose for 2–3 seconds',
                style: TextStyle(
                    color: Color(0xFF4a4a4a), fontSize: 12)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: _signGuide.length,
                itemBuilder: (context, i) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0d0d0d),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF1a1a1a)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF085041),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                            Icons.sign_language_rounded,
                            color: Color(0xFF4ade80),
                            size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(_signGuide[i][0],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(_signGuide[i][1],
                                style: const TextStyle(
                                    color: Color(0xFF5DCAA5),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetector.close();
    _tts.dispose();
    _signBuffer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildCameraView()),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black,
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) => Opacity(
              opacity:
                  _isTranslating ? _pulseAnim.value : 0.25,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isTranslating
                      ? const Color(0xFF4ade80)
                      : Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('ISL Bridge',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              )),
          const Spacer(),
          // Help button
          GestureDetector(
            onTap: _showSignGuide,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a1a),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFF2a2a2a)),
              ),
              child: const Icon(Icons.help_outline_rounded,
                  color: Color(0xFF9FE1CB), size: 16),
            ),
          ),
          // Language selector
          GestureDetector(
            onTap: _showLanguagePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a1a),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFF2a2a2a)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language,
                      color: Color(0xFF9FE1CB), size: 14),
                  const SizedBox(width: 5),
                  Text(
                    _languages[_selectedLanguage]!['name']!,
                    style: const TextStyle(
                      color: Color(0xFF9FE1CB),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFF9FE1CB), size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white30, size: 48),
            const SizedBox(height: 16),
            const Text('Camera permission required',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            const Text('Please enable camera in Settings',
                style: TextStyle(
                    color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Open Settings',
                  style: TextStyle(
                      color: Color(0xFF4ade80))),
            ),
          ],
        ),
      );
    }

    if (!_isReady) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF1D9E75), strokeWidth: 2),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera feed
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.previewSize!.height,
              height: _controller!.value.previewSize!.width,
              child: CameraPreview(_controller!),
            ),
          ),
        ),

        // Landmark overlay
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

        // Signal indicator top-right
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _landmarks.length > 20
                        ? const Color(0xFF4ade80)
                        : _landmarks.length > 10
                            ? const Color(0xFFf59e0b)
                            : const Color(0xFF6b7280),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _landmarks.length > 20
                      ? 'Good signal'
                      : _landmarks.length > 10
                          ? 'Weak signal'
                          : 'No signal',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),

        // Collected sign chips at top-left
        if (_collectedSigns.isNotEmpty)
          Positioned(
            top: 12,
            left: 12,
            right: 80,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _collectedSigns
                  .map((sign) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF1D9E75),
                              width: 0.5),
                        ),
                        child: Text(
                          SignClassifier.formatSign(sign),
                          style: const TextStyle(
                            color: Color(0xFF4ade80),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

        // Current sign indicator bottom-left of camera
        if (_currentSign.isNotEmpty)
          Positioned(
            bottom: 72,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF085041).withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ade80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    SignClassifier.formatSign(_currentSign),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Start / Stop toggle button
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _toggleTranslating,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _isTranslating
                      ? const Color(0xFF085041)
                      : Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isTranslating
                        ? const Color(0xFF1D9E75)
                        : const Color(0xFF2a2a2a),
                    width: _isTranslating ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isTranslating
                          ? Icons.pause_circle_rounded
                          : Icons.play_circle_rounded,
                      color: _isTranslating
                          ? const Color(0xFF4ade80)
                          : Colors.white54,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isTranslating
                          ? 'Tap to pause'
                          : 'Tap to start signing',
                      style: TextStyle(
                        color: _isTranslating
                            ? const Color(0xFF4ade80)
                            : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0a0a0a),
        border:
            Border(top: BorderSide(color: Color(0xFF1a1a1a))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: _isLoadingGemini
                ? const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Color(0xFF1D9E75),
                          strokeWidth: 1.5,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Forming sentence with Gemini...',
                          style: TextStyle(
                              color: Color(0xFF5DCAA5),
                              fontSize: 13)),
                    ],
                  )
                : _sentence.isNotEmpty
                    ? Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _sentence,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _circleButton(
                                icon: Icons.volume_up_rounded,
                                onTap: () {
                                  _tts.replayLast();
                                  FirebaseAnalytics.instance
                                      .logEvent(
                                          name: 'audio_replayed');
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _clearAll,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded,
                                    size: 13,
                                    color: Color(0xFF5DCAA5)),
                                SizedBox(width: 4),
                                Text('Sign again',
                                    style: TextStyle(
                                        color: Color(0xFF5DCAA5),
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _isTranslating
                            ? 'Make a sign and hold for a moment'
                            : 'Tap the button above to start',
                        style: const TextStyle(
                            color: Color(0xFF4a4a4a),
                            fontSize: 14),
                      ),
          ),

          const Divider(
              height: 0.5, color: Color(0xFF1a1a1a)),

          Row(
            children: [
              _navItem(
                icon: Icons.sign_language_rounded,
                label: 'Translate',
                isActive: true,
                onTap: () {},
              ),
              _navItem(
                icon: Icons.history_rounded,
                label: 'History',
                isActive: false,
                onTap: () => widget.onGoToHistory?.call(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF0F6E56),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: isActive
                      ? const Color(0xFF4ade80)
                      : const Color(0xFF3a3a3a),
                  size: 22),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFF4ade80)
                        : const Color(0xFF3a3a3a),
                    fontSize: 10,
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}