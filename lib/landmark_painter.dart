import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class LandmarkPainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final Size imageSize;
  final bool isFrontCamera;

  LandmarkPainter({
    required this.landmarks,
    required this.imageSize,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final landmark in landmarks) {
      double x = landmark.x * size.width / imageSize.width;
      double y = landmark.y * size.height / imageSize.height;

      // Mirror x axis for front camera
      if (isFrontCamera) {
        x = size.width - x;
      }

      canvas.drawCircle(Offset(x, y), 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(LandmarkPainter old) => true;
}