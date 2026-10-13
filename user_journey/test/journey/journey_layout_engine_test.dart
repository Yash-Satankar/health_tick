import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:user_journey/features/journey/presentation/layout/journey_layout_engine.dart';

/// Two levels like the seed: level A with [a] lesson nodes (+ checkpoint), level B with [b] lesson nodes.
List<JourneyLayoutItem> twoLevels(int a, int b, {bool checkpoint = true}) => [
  const LayoutCardItem('A'),
  for (var i = 0; i < a; i++) LayoutNodeItem('a$i', isFilled: i < 2),
  if (checkpoint) const LayoutNodeItem('a-cp', isCheckpoint: true),
  const LayoutCardItem('B'),
  for (var i = 0; i < b; i++) LayoutNodeItem('b$i'),
];

/// Tight bounds of the drawn curve (Path.getBounds() includes Bezier control points).
Rect curveBounds(Path path) {
  var bounds = Rect.zero;
  var first = true;
  for (final metric in path.computeMetrics()) {
    for (var i = 0; i <= 200; i++) {
      final p = metric.getTangentForOffset(metric.length * i / 200)!.position;
      bounds = first ? Rect.fromPoints(p, p) : bounds.expandToInclude(Rect.fromPoints(p, p));
      first = false;
    }
  }
  return bounds;
}

bool _overlaps(Rect r1, Rect r2) => r1.overlaps(r2) && r1.intersect(r2).width > 0.01 && r1.intersect(r2).height > 0.01;

void main() {
  const widths = [320.0, 360.0, 411.0, 480.0];

  group('JourneyLayoutEngine invariants (SPEC 9.4)', () {
    for (final w in widths) {
      test('W=$w: counts 0–60 per level: no overlap, inside [0, W], monotonic height', () {
        for (final withCheckpoint in [true, false]) {
          double? previousHeight;
          for (var n = 0; n <= 60; n++) {
            final layout = JourneyLayoutEngine.compute(twoLevels(n, n, checkpoint: withCheckpoint), w);
            final reason = 'W=$w n=$n checkpoint=$withCheckpoint';

            // Everything stays within [0, W] horizontally (including connector strokes).
            for (final rect in [...layout.cards.map((c) => c.rect), ...layout.nodes.map((n) => n.rect)]) {
              expect(rect.left, greaterThanOrEqualTo(0), reason: reason);
              expect(rect.right, lessThanOrEqualTo(w), reason: reason);
              expect(rect.bottom, lessThanOrEqualTo(layout.height), reason: reason);
            }
            for (final c in layout.connectors) {
              final bounds = curveBounds(c.path);
              expect(bounds.left - layout.strokeWidth / 2, greaterThanOrEqualTo(0), reason: reason);
              expect(bounds.right + layout.strokeWidth / 2, lessThanOrEqualTo(w), reason: reason);
            }

            // No two nodes overlap; no node overlaps a card — except the designed overlap of the
            // next card with the bottom of the checkpoint arch.
            for (var i = 0; i < layout.nodes.length; i++) {
              for (var j = i + 1; j < layout.nodes.length; j++) {
                expect(_overlaps(layout.nodes[i].rect, layout.nodes[j].rect), isFalse, reason: '$reason nodes $i/$j');
              }
              for (final card in layout.cards) {
                final node = layout.nodes[i];
                if (node.isCheckpoint) continue;
                expect(_overlaps(node.rect, card.rect), isFalse, reason: '$reason node $i vs card ${card.id}');
              }
            }
            expect(_overlaps(layout.cards[0].rect, layout.cards[1].rect), isFalse, reason: reason);

            // Height never decreases as nodes are added.
            if (previousHeight != null) {
              expect(layout.height, greaterThanOrEqualTo(previousHeight), reason: reason);
            }
            previousHeight = layout.height;
          }
        }
      });
    }

    test('height strictly grows whenever a new row is needed', () {
      double h(int n) => JourneyLayoutEngine.compute(twoLevels(0, n, checkpoint: false), 400).height;
      // Rows: 1 node → centre; 2–3 → + pair; 4 → + centre; 5–6 → + pair.
      expect(h(1), lessThan(h(2)));
      expect(h(2), h(3)); // second node of the pair shares the row
      expect(h(3), lessThan(h(4)));
      expect(h(4), lessThan(h(5)));
      expect(h(5), h(6));
    });
  });

  group('row pattern and geometry', () {
    const w = 400.0;
    final layout = JourneyLayoutEngine.compute(twoLevels(6, 3), w);
    NodeSlot node(String id) => layout.node(id)!;

    test('centre, pair, centre, pair… at 0.5W / 0.30W / 0.72W, rows 0.49W apart', () {
      expect(node('a0').center.dx, closeTo(0.5 * w, 0.01));
      expect(node('a1').center.dx, closeTo(0.30 * w, 0.01));
      expect(node('a2').center.dx, closeTo(0.72 * w, 0.01));
      expect(node('a1').center.dy, node('a2').center.dy);
      expect(node('a3').center.dx, closeTo(0.5 * w, 0.01));
      expect(node('a1').center.dy - node('a0').center.dy, closeTo(0.49 * w, 0.01));
      expect(node('a3').center.dy - node('a1').center.dy, closeTo(0.49 * w, 0.01));
    });

    test('node diameter 0.26W, card 0.9W × 0.46W, stroke 0.025W, ring 0.035W', () {
      expect(node('a0').rect.width, closeTo(0.26 * w, 0.01));
      expect(layout.cards[0].rect.width, closeTo(0.9 * w, 0.01));
      expect(layout.cards[0].rect.height, closeTo(0.46 * w, 0.01));
      expect(layout.strokeWidth, closeTo(0.025 * w, 0.001));
      expect(layout.ringWidth, closeTo(0.035 * w, 0.001));
    });

    test('a checkpoint takes its own centred row and is 0.39W × 0.42W; the next card overlaps it by 0.12W', () {
      final cp = node('a-cp');
      expect(cp.center.dx, closeTo(0.5 * w, 0.01));
      expect(cp.rect.width, closeTo(0.39 * w, 0.01));
      expect(cp.rect.height, closeTo(0.42 * w, 0.01));
      // 6 lesson nodes fill rows c, p, c, p(1 of 2 used? no: 1,2 | 3 | 4,5) → a5 is the centre-row node.
      expect(cp.center.dy, greaterThan(node('a5').center.dy));
      expect(cp.rect.bottom - layout.cards[1].rect.top, closeTo(0.12 * w, 0.01));
    });

    test('hit targets cover the node and are at least 48 dp', () {
      final small = JourneyLayoutEngine.compute(twoLevels(1, 0), 150);
      final slot = small.nodes.first;
      expect(slot.hitRect.width, greaterThanOrEqualTo(48));
      expect(slot.hitRect.contains(slot.center), isTrue);
    });
  });

  group('connectors', () {
    const w = 400.0;
    final layout = JourneyLayoutEngine.compute(twoLevels(4, 0), w);

    test('one segment per node: card→first node, then node→node; filled when the node it leads into is unlocked', () {
      expect(layout.connectors.map((c) => c.toNodeId), ['a0', 'a1', 'a2', 'a3', 'a-cp']);
      expect(layout.connectors.map((c) => c.filled), [true, true, false, false, false]);
    });

    test('card → first node is a straight vertical line', () {
      final b = curveBounds(layout.connectors.first.path);
      expect(b.width, lessThan(0.001));
      expect(b.top, closeTo(layout.cards.first.rect.bottom, 0.01));
    });

    test('centre → left bulges to ~0.08W; left → right is straight; right → centre bulges to ~0.92W', () {
      final toLeft = curveBounds(layout.connectors[1].path);
      expect(toLeft.left, closeTo(0.08 * w, 0.01 * w));
      final across = curveBounds(layout.connectors[2].path);
      expect(across.height, lessThan(0.001));
      final toCentre = curveBounds(layout.connectors[3].path);
      expect(toCentre.right, closeTo(0.92 * w, 0.01 * w));
    });
  });

  group('fill (SPEC 9.4, corrected 2026-10-13)', () {
    const w = 400.0;
    // b0 completed, b1 completed, b2 available, b3+ locked; checkpoint locked; next level locked.
    List<JourneyLayoutItem> items({int unlocked = 3}) => [
      const LayoutCardItem('A'),
      for (var i = 0; i < 6; i++) LayoutNodeItem('b$i', isFilled: i < unlocked),
      const LayoutNodeItem('cp', isCheckpoint: true),
      const LayoutCardItem('B'),
      for (var i = 0; i < 3; i++) LayoutNodeItem('i$i'),
    ];

    test('a segment into an available node is filled; one into a locked node is not', () {
      final layout = JourneyLayoutEngine.compute(items(), w);
      final byTarget = {for (final c in layout.connectors) c.toNodeId: c.filled};
      expect(byTarget['b2'], isTrue, reason: 'b2 is available');
      expect(byTarget['b3'], isFalse, reason: 'b3 is locked');
    });

    test('filledLength stops at the first locked node (contiguous prefix only)', () {
      final layout = JourneyLayoutEngine.compute(items(), w);
      final firstLocked = layout.connectors.indexWhere((c) => !c.filled);
      expect(layout.filledLength, closeTo(layout.connectors[firstLocked].start, 0.001));
      expect(layout.filledLength, closeTo(layout.connectors.take(3).fold<double>(0, (s, c) => s + c.length), 0.001));
      // A filled segment after a locked one does not extend the prefix.
      final gap = JourneyLayoutEngine.compute([
        const LayoutCardItem('A'),
        const LayoutNodeItem('x0', isFilled: true),
        const LayoutNodeItem('x1'),
        const LayoutNodeItem('x2', isFilled: true),
      ], w);
      expect(gap.filledLength, closeTo(gap.connectors.first.length, 0.001));
      expect(JourneyLayoutEngine.compute(items(unlocked: 0), w).filledLength, 0);
    });

    test('segments are one sequence in path order: contiguous starts, continuous geometry, node order', () {
      final layout = JourneyLayoutEngine.compute(items(unlocked: 6), w);
      expect(layout.connectors.map((c) => c.toNodeId), [...layout.nodes.map((n) => n.id)]);
      var expectedStart = 0.0;
      Offset? previousEnd;
      for (final c in layout.connectors) {
        expect(c.start, closeTo(expectedStart, 0.001));
        final metrics = c.path.computeMetrics().toList();
        expect(c.length, closeTo(metrics.fold<double>(0, (s, m) => s + m.length), 0.001));
        final startPoint = metrics.first.getTangentForOffset(0)!.position;
        if (previousEnd != null) expect((startPoint - previousEnd).distance, lessThan(0.5));
        previousEnd = metrics.last.getTangentForOffset(metrics.last.length)!.position;
        expectedStart += c.length;
      }
      expect(layout.totalConnectorLength, closeTo(expectedStart, 0.001));
    });

    test('the connector from the checkpoint runs through the next card into its first node', () {
      final layout = JourneyLayoutEngine.compute(items(unlocked: 7), w);
      final intoInsider = layout.connectors.firstWhere((c) => c.toNodeId == 'i0');
      final b = curveBounds(intoInsider.path);
      expect(b.width, lessThan(0.001), reason: 'checkpoint and first node are both centred');
      expect(b.top, closeTo(layout.node('cp')!.center.dy, 0.01));
      expect(b.bottom, closeTo(layout.node('i0')!.center.dy, 0.01));
      expect(b.top, lessThan(layout.cards[1].rect.top));
      expect(b.bottom, greaterThan(layout.cards[1].rect.bottom));
      expect(intoInsider.filled, isFalse);
    });
  });

  test('an empty journey has no content and a small height', () {
    final layout = JourneyLayoutEngine.compute(const [], 400);
    expect(layout.nodes, isEmpty);
    expect(layout.height, closeTo(0.12 * 400, 0.01));
  });
}
