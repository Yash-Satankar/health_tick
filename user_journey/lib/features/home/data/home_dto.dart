import 'package:json_annotation/json_annotation.dart';

import '../domain/home.dart';

part 'home_dto.g.dart';

@JsonSerializable(createToJson: false, checked: true)
class HomeUserDto {
  const HomeUserDto({required this.displayName, required this.healthPointsTotal, required this.streakDays});

  factory HomeUserDto.fromJson(Map<String, dynamic> json) => _$HomeUserDtoFromJson(json);

  final String displayName;
  final int healthPointsTotal;
  final int streakDays;
}

@JsonSerializable(createToJson: false, checked: true)
class TodayTaskDto {
  const TodayTaskDto({
    required this.lessonId,
    required this.lessonTitle,
    required this.nodeId,
    required this.statusTitle,
  });

  factory TodayTaskDto.fromJson(Map<String, dynamic> json) => _$TodayTaskDtoFromJson(json);

  final String lessonId;
  final String lessonTitle;
  final String nodeId;
  final String statusTitle;
}

@JsonSerializable(createToJson: false, checked: true)
class HomeDto {
  const HomeDto({required this.user, this.todayTask});

  factory HomeDto.fromJson(Map<String, dynamic> json) => _$HomeDtoFromJson(json);

  final HomeUserDto user;
  final TodayTaskDto? todayTask;

  HomeData toDomain() => HomeData(
    displayName: user.displayName,
    healthPointsTotal: user.healthPointsTotal,
    streakDays: user.streakDays,
    todayTask: todayTask == null
        ? null
        : TodayTask(
            lessonId: todayTask!.lessonId,
            lessonTitle: todayTask!.lessonTitle,
            nodeId: todayTask!.nodeId,
            statusTitle: todayTask!.statusTitle,
          ),
  );
}
