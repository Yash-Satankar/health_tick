// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomeUserDto _$HomeUserDtoFromJson(Map<String, dynamic> json) => $checkedCreate('HomeUserDto', json, ($checkedConvert) {
  final val = HomeUserDto(
    displayName: $checkedConvert('displayName', (v) => v as String),
    healthPointsTotal: $checkedConvert('healthPointsTotal', (v) => (v as num).toInt()),
    streakDays: $checkedConvert('streakDays', (v) => (v as num).toInt()),
  );
  return val;
});

TodayTaskDto _$TodayTaskDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TodayTaskDto', json, ($checkedConvert) {
      final val = TodayTaskDto(
        lessonId: $checkedConvert('lessonId', (v) => v as String),
        lessonTitle: $checkedConvert('lessonTitle', (v) => v as String),
        nodeId: $checkedConvert('nodeId', (v) => v as String),
        statusTitle: $checkedConvert('statusTitle', (v) => v as String),
      );
      return val;
    });

HomeDto _$HomeDtoFromJson(Map<String, dynamic> json) => $checkedCreate('HomeDto', json, ($checkedConvert) {
  final val = HomeDto(
    user: $checkedConvert('user', (v) => HomeUserDto.fromJson(v as Map<String, dynamic>)),
    todayTask: $checkedConvert('todayTask', (v) => v == null ? null : TodayTaskDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});
