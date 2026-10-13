import 'package:flutter/foundation.dart';

enum LessonExitReason { completed, abandoned }

/// Result popped by the lesson player (SPEC §8.3) so the Journey can reopen that node's popover.
@immutable
class LessonExit {
  const LessonExit({required this.reason, required this.nodeId, this.unlockedNodeId});

  final LessonExitReason reason;
  final String nodeId;

  /// Set when completing the lesson unlocked another node (the Journey pulses it).
  final String? unlockedNodeId;

  @override
  bool operator ==(Object other) =>
      other is LessonExit && other.reason == reason && other.nodeId == nodeId && other.unlockedNodeId == unlockedNodeId;
  @override
  int get hashCode => Object.hash(reason, nodeId, unlockedNodeId);
}
