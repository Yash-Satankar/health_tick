import 'package:dio/dio.dart';

/// Adds `X-User-Id` to every request (SPEC §8.5).
class UserIdInterceptor extends Interceptor {
  UserIdInterceptor(this.userId);

  final String userId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-User-Id'] = userId;
    handler.next(options);
  }
}
