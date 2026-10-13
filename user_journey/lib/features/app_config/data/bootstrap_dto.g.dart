// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BootstrapUserDto _$BootstrapUserDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BootstrapUserDto', json, ($checkedConvert) {
      final val = BootstrapUserDto(
        id: $checkedConvert('id', (v) => v as String),
        displayName: $checkedConvert('displayName', (v) => v as String),
        healthPointsTotal: $checkedConvert('healthPointsTotal', (v) => (v as num).toInt()),
      );
      return val;
    });

FeedbackReasonDto _$FeedbackReasonDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FeedbackReasonDto', json, ($checkedConvert) {
      final val = FeedbackReasonDto(
        id: $checkedConvert('id', (v) => v as String),
        key: $checkedConvert('key', (v) => v as String),
        label: $checkedConvert('label', (v) => v as String),
        requiresText: $checkedConvert('requiresText', (v) => v as bool? ?? false),
      );
      return val;
    });

BootstrapDto _$BootstrapDtoFromJson(Map<String, dynamic> json) => $checkedCreate('BootstrapDto', json, (
  $checkedConvert,
) {
  final val = BootstrapDto(
    contentVersion: $checkedConvert('contentVersion', (v) => (v as num).toInt()),
    user: $checkedConvert('user', (v) => BootstrapUserDto.fromJson(v as Map<String, dynamic>)),
    copy: $checkedConvert('copy', (v) => Map<String, String>.from(v as Map)),
    assets: $checkedConvert('assets', (v) => v as Map<String, dynamic>? ?? const {}),
    feedbackReasons: $checkedConvert(
      'feedbackReasons',
      (v) =>
          (v as List<dynamic>?)?.map((e) => FeedbackReasonDto.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
    ),
  );
  return val;
});
