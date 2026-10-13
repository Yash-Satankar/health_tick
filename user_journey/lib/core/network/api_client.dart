import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart' show CheckedFromJsonException;

import '../error/app_exception.dart';
import '../error/failure.dart';
import 'interceptors.dart';

/// Builds the app's Dio instance (SPEC §8.5: connect 10 s, receive 15 s, X-User-Id).
Dio createDio({required String baseUrl, required String userId}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(UserIdInterceptor(userId));
  return dio;
}

/// Maps any error thrown while calling the API (or parsing its response) to a [Failure].
Failure mapError(Object error) {
  if (error is AppException) return error.failure;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        return _fromErrorResponse(error.response);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return UnexpectedFailure(error.type.name);
      case DioExceptionType.unknown:
        final inner = error.error;
        if (inner is SocketException || inner is HttpException) return const NetworkFailure();
        if (inner is FormatException) return ParsingFailure(inner.message);
        return UnexpectedFailure(inner?.toString());
    }
  }
  if (error is SocketException) return const NetworkFailure();
  if (error is FormatException || error is TypeError || error is CheckedFromJsonException) {
    debugPrint('Parsing failure: $error');
    return ParsingFailure(error.toString());
  }
  return UnexpectedFailure(error.toString());
}

Failure _fromErrorResponse(Response<dynamic>? response) {
  final body = response?.data;
  if (body is Map && body['error'] is Map) {
    final envelope = body['error'] as Map;
    final code = envelope['code'];
    if (code is String) {
      return ServerFailure(
        code,
        statusCode: response?.statusCode,
        serverMessage: envelope['message'] is String ? envelope['message'] as String : null,
      );
    }
  }
  // Not the documented envelope (e.g. an HTML error page from a proxy).
  return ParsingFailure('HTTP ${response?.statusCode}: non-envelope error body');
}

/// Thin wrapper around Dio: unwraps `{ data: … }`, parses it, and throws [AppException] on failure.
class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  Future<T> get<T>(String path, T Function(Object? data) parse, {Map<String, dynamic>? query}) =>
      _run(() => dio.get<Object?>(path, queryParameters: query), parse);

  Future<T> post<T>(String path, T Function(Object? data) parse, {Object? body}) =>
      _run(() => dio.post<Object?>(path, data: body ?? const <String, dynamic>{}), parse);

  Future<T> put<T>(String path, T Function(Object? data) parse, {Object? body}) =>
      _run(() => dio.put<Object?>(path, data: body ?? const <String, dynamic>{}), parse);

  Future<T> delete<T>(String path, T Function(Object? data) parse) => _run(() => dio.delete<Object?>(path), parse);

  /// For endpoints without a body (e.g. 204).
  Future<void> postNoContent(String path) async {
    try {
      await dio.post<Object?>(path, data: const <String, dynamic>{});
    } catch (error) {
      throw AppException(mapError(error));
    }
  }

  /// GET with conditional request support: returns null on 304 Not Modified.
  Future<({T? value, String? etag})> getConditional<T>(
    String path,
    T Function(Object? data) parse, {
    String? etag,
  }) async {
    try {
      final response = await dio.get<Object?>(
        path,
        options: Options(
          headers: {'If-None-Match': ?etag},
          validateStatus: (status) => status != null && ((status >= 200 && status < 300) || status == 304),
        ),
      );
      final newEtag = response.headers.value('etag');
      if (response.statusCode == 304) return (value: null, etag: etag);
      return (value: parse(unwrapData(response.data)), etag: newEtag);
    } catch (error) {
      throw AppException(mapError(error));
    }
  }

  Future<T> _run<T>(Future<Response<Object?>> Function() call, T Function(Object? data) parse) async {
    try {
      final response = await call();
      return parse(unwrapData(response.data));
    } catch (error) {
      throw AppException(mapError(error));
    }
  }
}

/// Extracts `data` from the success envelope; throws [FormatException] for anything else.
Object? unwrapData(Object? body) {
  if (body is Map && body.containsKey('data')) return body['data'];
  throw const FormatException('Response is not a { data } envelope');
}

/// Casts [value] to a JSON object or throws [FormatException] (→ ParsingFailure).
Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  throw FormatException('Expected a JSON object, got ${value.runtimeType}');
}
