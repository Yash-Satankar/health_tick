import 'failure.dart';

/// Thrown by repositories; carries a typed [Failure] for the presentation layer.
class AppException implements Exception {
  const AppException(this.failure);

  final Failure failure;

  @override
  String toString() => 'AppException($failure)';
}
