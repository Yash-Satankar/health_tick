import 'package:json_annotation/json_annotation.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/models/asset_ref.dart';
import '../domain/bootstrap.dart';

part 'bootstrap_dto.g.dart';

@JsonSerializable(createToJson: false, checked: true)
class BootstrapUserDto {
  const BootstrapUserDto({required this.id, required this.displayName, required this.healthPointsTotal});

  factory BootstrapUserDto.fromJson(Map<String, dynamic> json) => _$BootstrapUserDtoFromJson(json);

  final String id;
  final String displayName;
  final int healthPointsTotal;
}

@JsonSerializable(createToJson: false, checked: true)
class FeedbackReasonDto {
  const FeedbackReasonDto({required this.id, required this.key, required this.label, this.requiresText = false});

  factory FeedbackReasonDto.fromJson(Map<String, dynamic> json) => _$FeedbackReasonDtoFromJson(json);

  final String id;
  final String key;
  final String label;
  final bool requiresText;
}

@JsonSerializable(createToJson: false, checked: true)
class BootstrapDto {
  const BootstrapDto({
    required this.contentVersion,
    required this.user,
    required this.copy,
    this.assets = const {},
    this.feedbackReasons = const [],
  });

  factory BootstrapDto.fromJson(Map<String, dynamic> json) => _$BootstrapDtoFromJson(json);

  final int contentVersion;
  final BootstrapUserDto user;
  final Map<String, String> copy;
  final Map<String, Object?> assets;
  final List<FeedbackReasonDto> feedbackReasons;

  Bootstrap toDomain() => Bootstrap(
    contentVersion: contentVersion,
    userId: user.id,
    displayName: user.displayName,
    healthPointsTotal: user.healthPointsTotal,
    copy: AppCopy(Map.unmodifiable(copy)),
    lockedNodeAsset: AssetRef.fromJsonOrNull(assets['lockedNode']),
    completionMedalAsset: AssetRef.fromJsonOrNull(assets['completionMedal']),
    feedbackReasons: feedbackReasons
        .map((r) => FeedbackReason(id: r.id, key: r.key, label: r.label, requiresText: r.requiresText))
        .toList(growable: false),
  );
}
