import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models/asset_ref.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/remote_image.dart';
import '../../domain/journey.dart';
import '../layout/journey_layout_engine.dart';

/// One node on the path. Lesson nodes are a circle with a ring drawn by Flutter and the icon clipped
/// inside; checkpoints are the arch image. Locked taps shake for 300 ms; [pulse] briefly scales it.
class JourneyNodeView extends StatefulWidget {
  const JourneyNodeView({
    super.key,
    required this.node,
    required this.slot,
    required this.layout,
    required this.lockedAsset,
    required this.onTap,
    required this.onLockedTap,
    this.pulse = false,
    this.selected = false,
  });

  final JourneyNode node;
  final NodeSlot slot;
  final JourneyLayout layout;
  final AssetRef? lockedAsset;
  final VoidCallback onTap;
  final VoidCallback onLockedTap;
  final bool pulse;
  final bool selected;

  @override
  State<JourneyNodeView> createState() => _JourneyNodeViewState();
}

class _JourneyNodeViewState extends State<JourneyNodeView> with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: AppDurations.shake);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _startPulse();
  }

  @override
  void didUpdateWidget(JourneyNodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !oldWidget.pulse) _startPulse();
  }

  void _startPulse() => _pulse.repeat(reverse: true, count: 3);

  @override
  void dispose() {
    _shake.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.node.isLocked) {
      _shake.forward(from: 0);
      widget.onLockedTap();
    } else {
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final slot = widget.slot;
    final content = node.isCheckpoint ? _checkpoint() : _circle();
    return Semantics(
      button: true,
      label: node.title,
      child: GestureDetector(
        key: ValueKey('journey-node-${node.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_shake, _pulse]),
          builder: (context, child) {
            final dx = math.sin(_shake.value * math.pi * 6) * 8 * (1 - _shake.value);
            final scale = 1 + 0.08 * Curves.easeInOut.transform(_pulse.value);
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: SizedBox(
            width: slot.hitRect.width,
            height: slot.hitRect.height,
            child: Center(
              child: SizedBox(width: slot.rect.width, height: slot.rect.height, child: content),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle() {
    final node = widget.node;
    final ring = widget.layout.ringWidth;
    final locked = node.isLocked;
    final ringColor = locked ? AppColors.pathLocked : AppColors.pathCompleted;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: widget.selected ? AppColors.textPrimary : ringColor, width: ring),
            ),
            child: Padding(
              padding: EdgeInsets.all(ring * 0.6),
              child: ClipOval(child: RemoteImage(locked ? widget.lockedAsset : node.icon, fit: BoxFit.cover)),
            ),
          ),
        ),
        if (node.state == ProgressState.completed)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              key: ValueKey('journey-node-check-${node.id}'),
              width: widget.slot.rect.width * 0.3,
              height: widget.slot.rect.width * 0.3,
              decoration: const BoxDecoration(color: AppColors.completedCheck, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: AppColors.textPrimary, size: widget.slot.rect.width * 0.22),
            ),
          ),
      ],
    );
  }

  Widget _checkpoint() {
    final node = widget.node;
    return Opacity(
      opacity: node.isLocked ? 0.55 : 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RemoteImage(node.icon, fit: BoxFit.contain),
          if (node.isLocked)
            Center(
              child: Icon(Icons.lock_rounded, color: AppColors.textPrimary, size: widget.slot.rect.width * 0.25),
            ),
        ],
      ),
    );
  }
}
