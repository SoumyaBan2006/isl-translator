import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'landmark_painter.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isReady = false;
  bool _permissionDenied = false;
  bool _isProcessing = false;
  bool _isFrontCamera = true;
  String _detectedSign = 'Point your hand at the camera';
  List<PoseLandmark> _landmarks = [];

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
    ),
  );

  @override
  void initState() {
    super.initState();
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

    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Correctly combine all plane bytes
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
          if (poses.isNotEmpty) {
            _landmarks = poses.first.landmarks.values.toList();
          } else {
            _landmarks = [];
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetector.close();
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
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildCameraView(),
          ),
          Container(
            width: double.infinity,
            color: Colors.teal.shade900,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Detected Sign:',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  _detectedSign,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Landmarks detected: ${_landmarks.length}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (_permissionDenied) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Camera permission denied.\nPlease enable it in your phone settings.',
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
          ],
        ),
      ),
    );
  }
}