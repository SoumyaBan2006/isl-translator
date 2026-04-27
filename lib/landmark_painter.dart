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
      ..color = const Color(0xFF4ade80).withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF1D9E75).withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const armIndices = {11, 12, 13, 14, 15, 16};
    final Map<int, Offset> positions = {};

    for (final lm in landmarks) {
      if (!armIndices.contains(lm.type.index)) continue;
      double x = lm.x * size.width / imageSize.width;
      double y = lm.y * size.height / imageSize.height;
      if (isFrontCamera) x = size.width - x;
      positions[lm.type.index] = Offset(x, y);
    }

    final connections = [
      [11, 13], [13, 15],
      [12, 14], [14, 16],
      [11, 12],
    ];

    for (final conn in connections) {
      final a = positions[conn[0]];
      final b = positions[conn[1]];
      if (a != null && b != null) {
        canvas.drawLine(a, b, linePaint);
      }
    }

    for (final offset in positions.values) {
      canvas.drawCircle(offset, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(LandmarkPainter old) => true;
}