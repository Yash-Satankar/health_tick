import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../../../core/models/asset_ref.dart';

/// Per-user progress state. Unknown values from the API are treated as locked (SPEC §8.5).
enum ProgressState {
  completed,
  available,
  locked;

  static ProgressState parse(Object? value) => switch (value) {
    'completed' => ProgressState.completed,
    'available' => ProgressState.available,
    _ => ProgressState.locked,
  };
}

/// Node type. Unknown values are rendered as a lesson node (SPEC §8.5).
enum NodeType {
  lesson,
  checkpoint;

  static NodeType parse(Object? value) => value == 'checkpoint' ? NodeType.checkpoint : NodeType.lesson;
}

@immutable
class JourneyLesson {
  const JourneyLesson({required this.id, required this.title, required this.state, this.completedAt});

  final String id;
  final String title;
  final ProgressState state;
  final DateTime? completedAt;
}

@immutable
class JourneyNode {
  const JourneyNode({
    required this.id,
    required this.key,
    required this.type,
    required this.title,
    required this.icon,
    required this.state,
    required this.lessons,
    this.completedAt,
  });

  final String id;
  final String key;
  final NodeType type;
  final String title;
  final AssetRef? icon;
  final ProgressState state;
  final DateTime? completedAt;
  final List<JourneyLesson> lessons;

  bool get isCheckpoint => type == NodeType.checkpoint;
  bool get isLocked => state == ProgressState.locked;
}

@immutable
class StatusCardTheme {
  const StatusCardTheme({required this.background, required this.shadow, required this.text});

  final Color background;
  final Color shadow;
  final Color text;
}

@immutable
class JourneyLevel {
  const JourneyLevel({
    required this.id,
    required this.key,
    required this.label,
    required this.title,
    required this.illustration,
    required this.nodes,
  });

  final String id;
  final String key;
  final String label;
  final String title;
  final AssetRef? illustration;
  final List<JourneyNode> nodes;
}

@immutable
class JourneyStatus {
  const JourneyStatus({
    required this.id,
    required this.key,
    required this.title,
    required this.cardTheme,
    required this.levels,
  });

  final String id;
  final String key;
  final String title;
  final StatusCardTheme cardTheme;
  final List<JourneyLevel> levels;
}

@immutable
class Journey {
  const Journey({required this.contentVersion, required this.statuses});

  final int contentVersion;
  final List<JourneyStatus> statuses;

  Iterable<JourneyNode> get nodes => statuses.expand((s) => s.levels).expand((l) => l.nodes);

  JourneyNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }
}

/// Which copy key the popover's primary button uses (SPEC §4.6).
enum PopoverAction { doItAgain, start, continueLesson }

extension PopoverActionCopy on PopoverAction {
  String get copyKey => switch (this) {
    PopoverAction.doItAgain => 'journey.popover.do_it_again',
    PopoverAction.start => 'journey.popover.start',
    PopoverAction.continueLesson => 'journey.popover.continue',
  };
}

/// The popover primary button: label and the lesson it opens; null for a locked node.
({PopoverAction action, String lessonId})? popoverActionFor(JourneyNode node) {
  if (node.isLocked || node.lessons.isEmpty) return null;
  final first = node.lessons.first.id;
  if (node.state == ProgressState.completed) return (action: PopoverAction.doItAgain, lessonId: first);
  final anyDone = node.lessons.any((l) => l.state == ProgressState.completed);
  if (!anyDone) return (action: PopoverAction.start, lessonId: first);
  final next = node.lessons.where((l) => l.state == ProgressState.available).firstOrNull;
  return (action: PopoverAction.continueLesson, lessonId: next?.id ?? first);
}

abstract interface class JourneyRepository {
  /// Fetches the journey. With [force] = false an ETag is sent and a 304 returns the cached copy.
  Future<Journey> getJourney({bool force = false});
}
