import 'package:flutter/material.dart';

import '../../../../core/copy/app_copy.dart';
import '../../../../core/models/asset_ref.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/journey.dart';
import '../layout/journey_layout_engine.dart';
import 'journey_node_view.dart';
import 'node_popover.dart';
import 'path_painter.dart';
import 'status_card.dart';

/// Converts the journey into layout-engine input: one card per level followed by its nodes.
List<JourneyLayoutItem> layoutItemsFor(Journey journey) => [
  for (final status in journey.statuses)
    for (final level in status.levels) ...[
      LayoutCardItem(level.id),
      for (final node in level.nodes)
        LayoutNodeItem(node.id, isCheckpoint: node.isCheckpoint, isCompleted: node.state == ProgressState.completed),
    ],
];

/// The scrollable path: cards, connectors, nodes and the popover of the selected node.
class JourneyPathView extends StatefulWidget {
  const JourneyPathView({
    super.key,
    required this.journey,
    required this.copy,
    required this.lockedAsset,
    required this.selectedNodeId,
    required this.pulseNodeId,
    required this.scrollController,
    required this.onNodeTap,
    required this.onLockedTap,
    required this.onClosePopover,
    required this.onOpenLesson,
  });

  final Journey journey;
  final AppCopy copy;
  final AssetRef? lockedAsset;
  final String? selectedNodeId;
  final String? pulseNodeId;
  final ScrollController scrollController;
  final ValueChanged<JourneyNode> onNodeTap;
  final VoidCallback onLockedTap;
  final VoidCallback onClosePopover;
  final ValueChanged<String> onOpenLesson;

  @override
  State<JourneyPathView> createState() => _JourneyPathViewState();
}

class _JourneyPathViewState extends State<JourneyPathView> {
  final GlobalKey _popoverKey = GlobalKey();
  JourneyLayout? _layout;
  Journey? _layoutJourney;
  double? _layoutWidth;

  JourneyLayout _layoutFor(double width) {
    if (_layout == null || !identical(_layoutJourney, widget.journey) || _layoutWidth != width) {
      _layout = JourneyLayoutEngine.compute(layoutItemsFor(widget.journey), width);
      _layoutJourney = widget.journey;
      _layoutWidth = width;
    }
    return _layout!;
  }

  @override
  void didUpdateWidget(JourneyPathView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNodeId != null && widget.selectedNodeId != oldWidget.selectedNodeId) {
      // Auto-scroll so the whole popover is visible (SPEC §9.3).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final popoverContext = _popoverKey.currentContext;
        if (popoverContext != null && popoverContext.mounted) {
          Scrollable.ensureVisible(
            popoverContext,
            duration: AppDurations.ensureVisible,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = JourneyLayoutEngine.contentWidthFor(constraints.maxWidth);
        final layout = _layoutFor(width);
        final levels = {
          for (final status in widget.journey.statuses)
            for (final level in status.levels) level.id: (status: status, level: level),
        };
        final nodes = {for (final node in widget.journey.nodes) node.id: node};
        final selected = widget.selectedNodeId == null ? null : nodes[widget.selectedNodeId];
        final selectedSlot = selected == null ? null : layout.node(selected.id);
        final geometry = selectedSlot == null
            ? null
            : PopoverGeometry.below(anchor: selectedSlot.rect, contentWidth: width);
        final height = geometry == null
            ? layout.height
            : (geometry.top + PopoverGeometry.estimateHeight(selected!) + 24).clamp(layout.height, double.infinity);

        return SingleChildScrollView(
          key: const ValueKey('journey-scroll'),
          controller: widget.scrollController,
          child: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: CustomPaint(painter: JourneyPathPainter(layout))),
                  for (final card in layout.cards)
                    if (levels[card.id] case final entry?)
                      Positioned.fromRect(
                        rect: card.rect,
                        child: StatusCard(
                          key: ValueKey('journey-card-${card.id}'),
                          status: entry.status,
                          level: entry.level,
                          statusLabel: widget.copy('journey.card.status_label'),
                        ),
                      ),
                  for (final slot in layout.nodes)
                    if (nodes[slot.id] case final node?)
                      Positioned.fromRect(
                        rect: slot.hitRect,
                        child: JourneyNodeView(
                          node: node,
                          slot: slot,
                          layout: layout,
                          lockedAsset: widget.lockedAsset,
                          pulse: widget.pulseNodeId == node.id,
                          selected: widget.selectedNodeId == node.id,
                          onTap: () => widget.onNodeTap(node),
                          onLockedTap: widget.onLockedTap,
                        ),
                      ),
                  if (selected != null && geometry != null) ...[
                    // Tapping outside the popover closes it.
                    Positioned.fill(
                      child: GestureDetector(
                        key: const ValueKey('popover-barrier'),
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onClosePopover,
                      ),
                    ),
                    Positioned(
                      left: geometry.left,
                      top: geometry.top,
                      width: geometry.width,
                      child: NodePopover(
                        key: _popoverKey,
                        node: selected,
                        copy: widget.copy,
                        pointerX: geometry.pointerX,
                        onClose: widget.onClosePopover,
                        onOpenLesson: widget.onOpenLesson,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
