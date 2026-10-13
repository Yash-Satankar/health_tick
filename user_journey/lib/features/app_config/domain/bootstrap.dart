import 'package:flutter/foundation.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/models/asset_ref.dart';

@immutable
class FeedbackReason {
  const FeedbackReason({required this.id, required this.key, required this.label, required this.requiresText});

  final String id;
  final String key;
  final String label;
  final bool requiresText;

  @override
  bool operator ==(Object other) =>
      other is FeedbackReason && other.id == id && other.label == label && other.requiresText == requiresText;
  @override
  int get hashCode => Object.hash(id, label, requiresText);
}

/// `GET /bootstrap`: copy, shared assets, feedback reasons, user (SPEC §6.2).
@immutable
class Bootstrap {
  const Bootstrap({
    required this.contentVersion,
    required this.userId,
    required this.displayName,
    required this.healthPointsTotal,
    required this.copy,
    required this.lockedNodeAsset,
    required this.completionMedalAsset,
    required this.feedbackReasons,
  });

  final int contentVersion;
  final String userId;
  final String displayName;
  final int healthPointsTotal;
  final AppCopy copy;
  final AssetRef? lockedNodeAsset;
  final AssetRef? completionMedalAsset;
  final List<FeedbackReason> feedbackReasons;

  @override
  bool operator ==(Object other) =>
      other is Bootstrap &&
      other.contentVersion == contentVersion &&
      other.displayName == displayName &&
      other.healthPointsTotal == healthPointsTotal &&
      other.copy == copy &&
      listEquals(other.feedbackReasons, feedbackReasons);
  @override
  int get hashCode => Object.hash(contentVersion, displayName, healthPointsTotal, copy);
}

abstract interface class AppConfigRepository {
  Future<Bootstrap> bootstrap();
}
