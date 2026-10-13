import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_journey/core/config/env.dart';
import 'package:user_journey/core/error/app_exception.dart';
import 'package:user_journey/core/error/failure.dart';
import 'package:user_journey/core/network/api_client.dart';
import 'package:user_journey/core/network/interceptors.dart';

class MockDio extends Mock implements Dio {}

RequestOptions _req() => RequestOptions(path: '/x');

DioException _dio(DioExceptionType type, {Object? error, Response<dynamic>? response}) =>
    DioException(requestOptions: _req(), type: type, error: error, response: response);

Response<Object?> _ok(Object? body, {int status = 200}) =>
    Response<Object?>(requestOptions: _req(), data: body, statusCode: status);

void main() {
  group('mapError (SPEC 8.5)', () {
    test('timeouts → TimeoutFailure', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(mapError(_dio(type)), const TimeoutFailure());
      }
    });

    test('connection and socket errors → NetworkFailure', () {
      expect(mapError(_dio(DioExceptionType.connectionError)), const NetworkFailure());
      expect(mapError(_dio(DioExceptionType.unknown, error: const SocketException('refused'))), const NetworkFailure());
      expect(mapError(const SocketException('x')), const NetworkFailure());
    });

    test('error envelopes → ServerFailure(code) with special codes', () {
      Failure envelope(int status, String code) => mapError(
        _dio(
          DioExceptionType.badResponse,
          response: Response(
            requestOptions: _req(),
            statusCode: status,
            data: {
              'error': {'code': code, 'message': 'm', 'requestId': 'r'},
            },
          ),
        ),
      );
      final locked = envelope(403, 'LESSON_LOCKED') as ServerFailure;
      expect(locked.isLessonLocked, isTrue);
      expect(locked.messageKey, 'error.locked.message');
      expect((envelope(404, 'NOT_FOUND') as ServerFailure).messageKey, 'error.not_found.message');
      expect((envelope(409, 'CONTENT_CHANGED') as ServerFailure).isContentChanged, isTrue);
      expect(envelope(500, 'INTERNAL_ERROR').messageKey, 'error.server.message');
      expect(envelope(422, 'ANSWER_INVALID').messageKey, 'error.unexpected.message');
    });

    test('non-JSON error bodies and DTO mismatches → ParsingFailure', () {
      final html = _dio(
        DioExceptionType.badResponse,
        response: Response(requestOptions: _req(), statusCode: 502, data: '<html>Bad gateway</html>'),
      );
      expect(mapError(html), isA<ParsingFailure>());
      expect(mapError(const FormatException('bad')), isA<ParsingFailure>());
    });

    test('anything else → UnexpectedFailure', () {
      expect(mapError(StateError('x')), isA<UnexpectedFailure>());
      expect(mapError(_dio(DioExceptionType.cancel)), isA<UnexpectedFailure>());
    });
  });

  group('ApiClient', () {
    late MockDio dio;
    late ApiClient client;

    setUp(() {
      dio = MockDio();
      client = ApiClient(dio);
    });

    test('unwraps { data } and parses it', () async {
      when(() => dio.get<Object?>('/a', queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => _ok({
          'data': {'n': 1},
        }),
      );
      expect(await client.get('/a', (d) => asJsonMap(d)['n']), 1);
    });

    test('a body without the data envelope → ParsingFailure', () async {
      when(
        () => dio.get<Object?>('/a', queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => _ok('<html>'));
      await expectLater(
        client.get('/a', (d) => d),
        throwsA(isA<AppException>().having((e) => e.failure, 'failure', isA<ParsingFailure>())),
      );
    });

    test('a DTO parse error (wrong field type) → ParsingFailure', () async {
      when(() => dio.get<Object?>('/a', queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => _ok({
          'data': {'n': 'not a number'},
        }),
      );
      await expectLater(
        client.get('/a', (d) => asJsonMap(d)['n'] as int),
        throwsA(isA<AppException>().having((e) => e.failure, 'failure', isA<ParsingFailure>())),
      );
    });

    test('transport errors are mapped', () async {
      when(
        () => dio.get<Object?>('/a', queryParameters: any(named: 'queryParameters')),
      ).thenThrow(_dio(DioExceptionType.connectionError));
      await expectLater(
        client.get('/a', (d) => d),
        throwsA(isA<AppException>().having((e) => e.failure, 'failure', const NetworkFailure())),
      );
    });
  });

  group('configuration', () {
    test('createDio sets the timeouts and the X-User-Id interceptor', () {
      final dio = createDio(baseUrl: 'http://h:1', userId: 'u-1');
      expect(dio.options.connectTimeout, const Duration(seconds: 10));
      expect(dio.options.receiveTimeout, const Duration(seconds: 15));
      expect(dio.interceptors.whereType<UserIdInterceptor>().single.userId, 'u-1');
    });

    test('asset URLs resolve against API_BASE_URL', () {
      expect(
        Env.resolveAssetUrl('/static/assets/a.png', base: 'http://10.0.2.2:3000'),
        'http://10.0.2.2:3000/static/assets/a.png',
      );
      expect(Env.resolveAssetUrl('https://cdn.test/a.png', base: 'http://x'), 'https://cdn.test/a.png');
    });
  });
}
