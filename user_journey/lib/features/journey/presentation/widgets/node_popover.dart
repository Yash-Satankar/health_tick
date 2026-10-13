import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/copy/app_copy.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/journey.dart';

/// Geometry of the popover anchored below a node (SPEC §9.3).
class PopoverGeometry {
  const PopoverGeometry({required this.left, required this.top, required this.width, required this.pointerX});

  static const double pointerHeight = 12;
  static const double margin = 8;

  final double left;
  final double top;
  final double width;

  /// Pointer x relative to the popover's left edge.
  final double pointerX;

  /// Width `min(0.84 × W, 340)`, horizontally clamped to the content area.
  static PopoverGeometry below({required Rect anchor, required double contentWidth}) {
    final width = math.min(0.84 * contentWidth, 340.0);
    final left = (anchor.center.dx - width / 2)
        .clamp(margin, math.max(margin, contentWidth - width - margin))
        .toDouble();
    return PopoverGeometry(
      left: left,
      top: anchor.bottom,
      width: width,
      pointerX: (anchor.center.dx - left).clamp(20.0, width - 20.0),
    );
  }

  /// Upper bound of the popover height, used to extend the scroll area so it can be fully shown.
  static double estimateHeight(JourneyNode node) =>
      pointerHeight + 32 + 40 + node.lessons.length * 52 + 16 + 52 + (node.state == ProgressState.completed ? 32 : 0);
}

class NodePopover extends StatelessWidget {
  const NodePopover({
    super.key,
    required this.node,
    required this.copy,
    required this.pointerX,
    required this.onClose,
    required this.onOpenLesson,
  });

  final JourneyNode node;
  final AppCopy copy;
  final double pointerX;
  final VoidCallback onClose;
  final ValueChanged<String> onOpenLesson;

  @override
  Widget build(BuildContext context) {
    final action = popoverActionFor(node);
    return TweenAnimationBuilder<double>(
      key: ValueKey('popover-anim-${node.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.popover,
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.92 + 0.08 * t, alignment: Alignment.topCenter, child: child),
      ),
      child: Column(
        key: const ValueKey('node-popover'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: PopoverGeometry.pointerHeight,
            child: CustomPaint(painter: _PointerPainter(pointerX)),
          ),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(node.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        key: const ValueKey('popover-close'),
                        onPressed: onClose,
                        icon: const Icon(Icons.highlight_off_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  for (final lesson in node.lessons) _LessonRow(lesson: lesson, onTap: () => onOpenLesson(lesson.id)),
                  if (action != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: PrimaryButton(
                        key: const ValueKey('popover-primary'),
                        label: copy(action.action.copyKey),
                        onPressed: () => onOpenLesson(action.lessonId),
                      ),
                    ),
                  ],
                  if (node.state == ProgressState.completed && node.completedAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${copy('journey.popover.completed_on')} ${DateFormat('d MMM yyyy').format(node.completedAt!.toLocal())}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.onTap});

  final JourneyLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (lesson.state) {
      ProgressState.completed => (Icons.check_circle_rounded, AppColors.completedCheck),
      ProgressState.available => (Icons.radio_button_unchecked_rounded, AppColors.textPrimary),
      ProgressState.locked => (Icons.lock_outline_rounded, AppColors.textSecondary),
    };
    final locked = lesson.state == ProgressState.locked;
    return InkWell(
      key: ValueKey('popover-lesson-${lesson.id}'),
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lesson.title,
                style: TextStyle(fontSize: 15, color: locked ? AppColors.textSecondary : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  _PointerPainter(this.x);

  final double x;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(x - 12, size.height)
      ..lineTo(x, 0)
      ..lineTo(x + 12, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => oldDelegate.x != x;
}
