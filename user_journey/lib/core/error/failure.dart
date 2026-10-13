/// Typed failures (SPEC §8.5). Every failure maps to an `app_copy` key.
sealed class Failure {
  const Failure();

  /// The `app_copy` key of the message shown to the user.
  String get messageKey;

  /// Optional `app_copy` key of a title (e.g. offline).
  String? get titleKey => null;
}

/// Socket / connection errors: the server is unreachable.
final class NetworkFailure extends Failure {
  const NetworkFailure();
  @override
  String get messageKey => 'error.network.message';
  @override
  String get titleKey => 'error.network.title';
  @override
  bool operator ==(Object other) => other is NetworkFailure;
  @override
  int get hashCode => 1;
  @override
  String toString() => 'NetworkFailure';
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure();
  @override
  String get messageKey => 'error.timeout.message';
  @override
  bool operator ==(Object other) => other is TimeoutFailure;
  @override
  int get hashCode => 2;
  @override
  String toString() => 'TimeoutFailure';
}

/// An error envelope from the API: `{ error: { code, message } }`.
final class ServerFailure extends Failure {
  const ServerFailure(this.code, {this.statusCode, this.serverMessage});

  final String code;
  final int? statusCode;
  final String? serverMessage;

  bool get isLessonLocked => code == 'LESSON_LOCKED';
  bool get isNotFound => code == 'NOT_FOUND';
  bool get isContentChanged => code == 'CONTENT_CHANGED';

  @override
  String get messageKey => switch (code) {
    'LESSON_LOCKED' => 'error.locked.message',
    'NOT_FOUND' => 'error.not_found.message',
    _ => (statusCode ?? 500) >= 500 ? 'error.server.message' : 'error.unexpected.message',
  };

  @override
  bool operator ==(Object other) => other is ServerFailure && other.code == code && other.statusCode == statusCode;
  @override
  int get hashCode => Object.hash(code, statusCode);
  @override
  String toString() => 'ServerFailure($code, $statusCode)';
}

/// Non-JSON body or a DTO that does not match the contract.
final class ParsingFailure extends Failure {
  const ParsingFailure([this.detail]);
  final String? detail;
  @override
  String get messageKey => 'error.unexpected.message';
  @override
  bool operator ==(Object other) => other is ParsingFailure;
  @override
  int get hashCode => 3;
  @override
  String toString() => 'ParsingFailure($detail)';
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([this.detail]);
  final String? detail;
  @override
  String get messageKey => 'error.unexpected.message';
  @override
  bool operator ==(Object other) => other is UnexpectedFailure;
  @override
  int get hashCode => 4;
  @override
  String toString() => 'UnexpectedFailure($detail)';
}
