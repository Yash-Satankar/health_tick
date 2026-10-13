import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Input of the layout engine: a level card or a node, in journey order.
@immutable
sealed class JourneyLayoutItem {
  const JourneyLayoutItem(this.id);
  final String id;
}

final class LayoutCardItem extends JourneyLayoutItem {
  const LayoutCardItem(super.id);
}

final class LayoutNodeItem extends JourneyLayoutItem {
  const LayoutNodeItem(super.id, {this.isCheckpoint = false, this.isCompleted = false});
  final bool isCheckpoint;
  final bool isCompleted;
}

@immutable
class CardSlot {
  const CardSlot(this.id, this.rect);
  final String id;
  final Rect rect;
}

@immutable
class NodeSlot {
  const NodeSlot({required this.id, required this.rect, required this.hitRect, required this.isCheckpoint});
  final String id;

  /// Visual bounds: the circle for a lesson node, the arch image for a checkpoint.
  final Rect rect;

  /// Tappable bounds (never smaller than 48 dp).
  final Rect hitRect;
  final bool isCheckpoint;

  Offset get center => rect.center;
}

@immutable
class ConnectorSegment {
  const ConnectorSegment({required this.path, required this.completed, required this.toNodeId});
  final Path path;

  /// Drawn in the completed colour if the node it ENDS at is completed (SPEC §9.4).
  final bool completed;
  final String toNodeId;
}

@immutable
class JourneyLayout {
  const JourneyLayout({
    required this.width,
    required this.height,
    required this.cards,
    required this.nodes,
    required this.connectors,
    required this.strokeWidth,
    required this.nodeDiameter,
    required this.ringWidth,
  });

  final double width;
  final double height;
  final List<CardSlot> cards;
  final List<NodeSlot> nodes;
  final List<ConnectorSegment> connectors;
  final double strokeWidth;
  final double nodeDiameter;
  final double ringWidth;

  NodeSlot? node(String id) => nodes.where((n) => n.id == id).firstOrNull;
}

/// Pure path layout (SPEC §9.4). All measurements are ratios of the content width W.
class JourneyLayoutEngine {
  const JourneyLayoutEngine._();

  static const double nodeDiameterRatio = 0.26;
  static const double ringRatio = 0.035;
  static const double cardWidthRatio = 0.9;
  static const double cardHeightRatio = 0.46;
  static const double rowGapRatio = 0.49;
  static const double centerXRatio = 0.5;
  static const double leftXRatio = 0.30;
  static const double rightXRatio = 0.72;
  static const double leftBulgeRatio = 0.08;
  static const double rightBulgeRatio = 0.92;
  static const double strokeRatio = 0.025;
  static const double archWidthRatio = 0.39;
  static const double archHeightRatio = 0.42;
  static const double archOverlapRatio = 0.12;
  // Spacing choices not fixed by the SPEC (documented in the worklog).
  static const double topPaddingRatio = 0.04;
  static const double cardToFirstRowRatio = 0.30;
  static const double nodeToCardGapRatio = 0.20;
  static const double cardToCardGapRatio = 0.10;
  static const double bottomPaddingRatio = 0.12;

  /// Content width for a screen: `min(screenWidth, 480)`.
  static double contentWidthFor(double screenWidth) => math.min(screenWidth, 480);

  static JourneyLayout compute(List<JourneyLayoutItem> items, double contentWidth) {
    final w = contentWidth;
    final d = nodeDiameterRatio * w;
    final rowGap = rowGapRatio * w;
    final cards = <CardSlot>[];
    final nodes = <NodeSlot>[];
    final connectors = <ConnectorSegment>[];

    // Bottom edge of the last element and what it was, to place the next card.
    var cursorBottom = topPaddingRatio * w;
    _Last last = _Last.none;
    CardSlot? currentCard;
    NodeSlot? previousNode;
    var rowIndex = -1; // rows placed under the current card
    var rowCenterY = 0.0;
    var pairHasRightSlotFree = false;

    for (final item in items) {
      switch (item) {
        case LayoutCardItem():
          final top = switch (last) {
            _Last.none => topPaddingRatio * w,
            _Last.checkpoint => cursorBottom - archOverlapRatio * w,
            _Last.node => cursorBottom + nodeToCardGapRatio * w,
            _Last.card => cursorBottom + cardToCardGapRatio * w,
          };
          final rect = Rect.fromLTWH((1 - cardWidthRatio) / 2 * w, top, cardWidthRatio * w, cardHeightRatio * w);
          currentCard = CardSlot(item.id, rect);
          cards.add(currentCard);
          cursorBottom = rect.bottom;
          last = _Last.card;
          previousNode = null;
          rowIndex = -1;
          pairHasRightSlotFree = false;

        case LayoutNodeItem():
          double x;
          if (!item.isCheckpoint && pairHasRightSlotFree) {
            x = rightXRatio * w; // second node of a pair row
            pairHasRightSlotFree = false;
          } else {
            rowIndex += 1;
            rowCenterY = rowIndex == 0
                ? (currentCard?.rect.bottom ?? topPaddingRatio * w) + cardToFirstRowRatio * w
                : rowCenterY + rowGap;
            // Rows alternate centre / pair; a checkpoint always takes its own centred row.
            final isPairRow = !item.isCheckpoint && rowIndex.isOdd;
            x = (isPairRow ? leftXRatio : centerXRatio) * w;
            pairHasRightSlotFree = isPairRow;
          }
          final center = Offset(x, rowCenterY);
          final rect = item.isCheckpoint
              ? Rect.fromCenter(center: center, width: archWidthRatio * w, height: archHeightRatio * w)
              : Rect.fromCircle(center: center, radius: d / 2);
          final hitRect = Rect.fromCenter(
            center: center,
            width: math.max(rect.width, 48),
            height: math.max(rect.height, 48),
          );
          final slot = NodeSlot(id: item.id, rect: rect, hitRect: hitRect, isCheckpoint: item.isCheckpoint);

          final from = previousNode?.center ?? (currentCard == null ? null : Offset(w / 2, currentCard.rect.bottom));
          if (from != null) {
            connectors.add(
              ConnectorSegment(path: _connect(from, center, w), completed: item.isCompleted, toNodeId: item.id),
            );
          }
          nodes.add(slot);
          previousNode = slot;
          if (item.isCheckpoint) pairHasRightSlotFree = false;
          cursorBottom = math.max(cursorBottom, rect.bottom);
          last = item.isCheckpoint ? _Last.checkpoint : _Last.node;
      }
    }

    final height = (items.isEmpty ? 0.0 : cursorBottom) + bottomPaddingRatio * w;
    return JourneyLayout(
      width: w,
      height: height,
      cards: List.unmodifiable(cards),
      nodes: List.unmodifiable(nodes),
      connectors: List.unmodifiable(connectors),
      strokeWidth: strokeRatio * w,
      nodeDiameter: d,
      ringWidth: ringRatio * w,
    );
  }

  /// Straight line when aligned; otherwise an S-curve bulging out to 0.08W (left side) or 0.92W (right side).
  static Path _connect(Offset a, Offset b, double w) {
    final path = Path()..moveTo(a.dx, a.dy);
    if ((a.dx - b.dx).abs() < 0.5 || (a.dy - b.dy).abs() < 0.5) {
      path.lineTo(b.dx, b.dy);
      return path;
    }
    final bulgeX = (math.min(a.dx, b.dx) < centerXRatio * w - 0.5 ? leftBulgeRatio : rightBulgeRatio) * w;
    // Cubic with both control points at x = c: x(0.5) = (a.x + b.x + 6c) / 8 = bulgeX.
    final c = (8 * bulgeX - a.dx - b.dx) / 6;
    path.cubicTo(c, a.dy, c, b.dy, b.dx, b.dy);
    return path;
  }
}

enum _Last { none, card, node, checkpoint }
