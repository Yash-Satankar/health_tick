import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models/asset_ref.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/remote_image.dart';
import '../../domain/lesson.dart';

/// Completion screen (SPEC §9.6): the medal scales in over 400 ms with a light sparkle, the headline,
/// a bordered message card, the points earned (from the server) and Continue.
class CompletionView extends StatefulWidget {
  const CompletionView({
    super.key,
    required this.completion,
    required this.fallbackAsset,
    required this.continueLabel,
    required this.onContinue,
  });

  final LessonCompletion completion;
  final AssetRef? fallbackAsset;
  final String continueLabel;
  final VoidCallback onContinue;

  @override
  State<CompletionView> createState() => _CompletionViewState();
}

class _CompletionViewState extends State<CompletionView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppDurations.medal)
    ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completion = widget.completion;
    final size = math.min(MediaQuery.sizeOf(context).width * 0.5, 220.0);
    return SafeArea(
      child: Padding(
        key: const ValueKey('completion-view'),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            SizedBox(
              width: size * 1.4,
              height: size * 1.25,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => CustomPaint(
                  painter: _SparklePainter(_controller.value),
                  child: Center(
                    child: Transform.scale(scale: Curves.easeOutBack.transform(_controller.value), child: child),
                  ),
                ),
                child: RemoteImage(completion.asset ?? widget.fallbackAsset, width: size, height: size),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              completion.headline,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(completion.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Row(
              key: const ValueKey('completion-points'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monitor_heart_rounded, color: AppColors.healthAccent),
                const SizedBox(width: 6),
                Text(
                  '+${completion.healthPointsEarned}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.healthAccent),
                ),
              ],
            ),
            const Spacer(),
            PrimaryButton(
              key: const ValueKey('completion-continue'),
              label: widget.continueLabel,
              onPressed: widget.onContinue,
            ),
          ],
        ),
      ),
    );
  }
}

/// A few small stars that fade out as the medal settles.
class _SparklePainter extends CustomPainter {
  _SparklePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final paint = Paint()..color = AppColors.highlight.withValues(alpha: (1 - t) * 0.9 + 0.1);
    final center = size.center(Offset.zero);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + 0.3;
      final radius = size.shortestSide * (0.35 + 0.15 * t);
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(p, 3 + 2 * math.sin(t * math.pi), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.t != t;
}
