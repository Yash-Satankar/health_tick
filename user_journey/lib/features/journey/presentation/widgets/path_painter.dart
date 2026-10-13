import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../layout/journey_layout_engine.dart';

/// Draws the connectors: every segment in the track colour, then the filled colour flowing along the
/// path (in path order) up to [fill]'s current length. The painter repaints from [fill] directly, so the
/// node Stack is not rebuilt on every animation frame.
class JourneyPathPainter extends CustomPainter {
  JourneyPathPainter(this.layout, {required this.fill}) : super(repaint: fill);

  final JourneyLayout layout;

  /// Length (along the whole path) currently drawn in the filled colour.
  final ValueListenable<double> fill;

  /// Exposed for tests.
  double get animatedLength => fill.value;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = layout.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.pathLocked;
    for (final segment in layout.connectors) {
      canvas.drawPath(segment.path, paint);
    }

    final length = fill.value;
    if (length <= 0) return;
    paint.color = AppColors.pathCompleted;
    for (final segment in layout.connectors) {
      if (segment.start >= length) break;
      if (segment.end <= length) {
        canvas.drawPath(segment.path, paint);
        continue;
      }
      // Partially filled segment: extract the leading part (round cap = rounded leading edge).
      var remaining = length - segment.start;
      for (final metric in segment.path.computeMetrics()) {
        if (remaining <= 0) break;
        canvas.drawPath(metric.extractPath(0, remaining.clamp(0, metric.length)), paint);
        remaining -= metric.length;
      }
    }
  }

  @override
  bool shouldRepaint(JourneyPathPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout) || oldDelegate.fill != fill;
}
