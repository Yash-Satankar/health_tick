import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../layout/journey_layout_engine.dart';

/// Draws the connector segments (round caps; completed vs locked colour).
class JourneyPathPainter extends CustomPainter {
  JourneyPathPainter(this.layout);

  final JourneyLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = layout.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Locked segments first so completed ones are drawn on top where they meet.
    for (final completed in [false, true]) {
      paint.color = completed ? AppColors.pathCompleted : AppColors.pathLocked;
      for (final segment in layout.connectors.where((s) => s.completed == completed)) {
        canvas.drawPath(segment.path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(JourneyPathPainter oldDelegate) => !identical(oldDelegate.layout, layout);
}
