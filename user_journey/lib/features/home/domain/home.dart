import 'package:flutter/foundation.dart';

@immutable
class TodayTask {
  const TodayTask({required this.lessonId, required this.lessonTitle, required this.nodeId, required this.statusTitle});

  final String lessonId;
  final String lessonTitle;
  final String nodeId;
  final String statusTitle;

  @override
  bool operator ==(Object other) =>
      other is TodayTask && other.lessonId == lessonId && other.lessonTitle == lessonTitle && other.nodeId == nodeId;
  @override
  int get hashCode => Object.hash(lessonId, lessonTitle, nodeId);
}

/// `GET /home` (SPEC §6.2).
@immutable
class HomeData {
  const HomeData({
    required this.displayName,
    required this.healthPointsTotal,
    required this.streakDays,
    required this.todayTask,
  });

  final String displayName;
  final int healthPointsTotal;
  final int streakDays;

  /// Null when every lesson is completed.
  final TodayTask? todayTask;

  @override
  bool operator ==(Object other) =>
      other is HomeData &&
      other.displayName == displayName &&
      other.healthPointsTotal == healthPointsTotal &&
      other.streakDays == streakDays &&
      other.todayTask == todayTask;
  @override
  int get hashCode => Object.hash(displayName, healthPointsTotal, streakDays, todayTask);
}

abstract interface class HomeRepository {
  Future<HomeData> getHome();
}
