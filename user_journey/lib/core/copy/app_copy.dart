import 'package:flutter/foundation.dart';

/// Short fallback strings used only when the API copy has not loaded (SPEC §8.5).
/// This is the ONLY place in the app allowed to hold hardcoded UI text.
class FallbackMessages {
  const FallbackMessages._();

  static const Map<String, String> values = {
    'error.network.title': "You're offline",
    'error.network.message': 'Check your connection and try again.',
    'error.timeout.message': 'This is taking too long. Please try again.',
    'error.server.message': 'Something went wrong. Please try again.',
    'error.not_found.message': "We couldn't find that.",
    'error.locked.message': 'This lesson is locked.',
    'error.unexpected.message': 'Something went wrong. Please try again.',
    'error.retry': 'Retry',
  };
}

/// UI copy from `GET /bootstrap` (`app_copy`), with fallbacks for error texts only.
@immutable
class AppCopy {
  const AppCopy(this._values);

  static const AppCopy empty = AppCopy({});

  final Map<String, String> _values;

  bool get isLoaded => _values.isNotEmpty;

  /// The copy for [key]; a FallbackMessages entry if missing; otherwise an empty string (logged).
  String call(String key) {
    final value = _values[key] ?? FallbackMessages.values[key];
    if (value == null) {
      debugPrint('AppCopy: missing key "$key"');
      return '';
    }
    return value;
  }

  bool has(String key) => _values.containsKey(key);

  @override
  bool operator ==(Object other) => other is AppCopy && mapEquals(other._values, _values);

  @override
  int get hashCode => Object.hashAllUnordered(_values.entries.map((e) => Object.hash(e.key, e.value)));
}
