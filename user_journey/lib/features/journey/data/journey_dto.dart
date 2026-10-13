import '../../../core/models/asset_ref.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../domain/journey.dart';

/// Parses `GET /journey` `data` (SPEC §6.2). Required fields missing → FormatException (ParsingFailure);
/// unknown node types/states are handled defensively (SPEC §8.5).
Journey parseJourney(Object? json) {
  final map = asJsonMap(json);
  return Journey(
    contentVersion: (map['contentVersion'] as num).toInt(),
    statuses: _list(map['statuses']).map(_status).toList(growable: false),
  );
}

List<Object?> _list(Object? value) {
  if (value is List) return value;
  throw FormatException('Expected a list, got ${value.runtimeType}');
}

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw FormatException('"$key" must be a string');
}

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;

JourneyStatus _status(Object? json) {
  final map = asJsonMap(json);
  final theme = asJsonMap(map['cardTheme']);
  return JourneyStatus(
    id: _string(map, 'id'),
    key: _string(map, 'key'),
    title: _string(map, 'title'),
    cardTheme: StatusCardTheme(
      background: parseHexColor(theme['backgroundColor'] as String?, fallback: AppColors.surface),
      shadow: parseHexColor(theme['shadowColor'] as String?, fallback: AppColors.border),
      text: parseHexColor(theme['textColor'] as String?, fallback: AppColors.buttonText),
    ),
    levels: _list(map['levels']).map(_level).toList(growable: false),
  );
}

JourneyLevel _level(Object? json) {
  final map = asJsonMap(json);
  return JourneyLevel(
    id: _string(map, 'id'),
    key: _string(map, 'key'),
    label: _string(map, 'label'),
    title: _string(map, 'title'),
    illustration: AssetRef.fromJsonOrNull(map['illustration']),
    nodes: _list(map['nodes']).map(_node).toList(growable: false),
  );
}

JourneyNode _node(Object? json) {
  final map = asJsonMap(json);
  return JourneyNode(
    id: _string(map, 'id'),
    key: _string(map, 'key'),
    type: NodeType.parse(map['type']),
    title: _string(map, 'title'),
    icon: AssetRef.fromJsonOrNull(map['icon']),
    state: ProgressState.parse(map['state']),
    completedAt: _date(map['completedAt']),
    lessons: _list(map['lessons'])
        .map((l) {
          final lesson = asJsonMap(l);
          return JourneyLesson(
            id: _string(lesson, 'id'),
            title: _string(lesson, 'title'),
            state: ProgressState.parse(lesson['state']),
            completedAt: _date(lesson['completedAt']),
          );
        })
        .toList(growable: false),
  );
}
