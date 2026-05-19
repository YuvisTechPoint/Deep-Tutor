import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../config/app_config.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Reads the current auth token on every request (avoids recreating [Dio]).
typedef TokenReader = String? Function();

/// Creates and configures a [Dio] instance for the DeepTutor API.
///
/// Injects Bearer token via [AuthInterceptor] and handles common
/// error transformations (410 quiz expired, 503 toolchain unavailable).
Dio createDio(
  AppConfig config, {
  TokenReader? tokenReader,
  bool Function()? demoModeReader,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiV1,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(
      tokenReader ?? () => null,
      demoModeReader: demoModeReader ?? () => false,
    ),
    ErrorInterceptor(),
    if (config.isDev) _buildLogInterceptor(),
  ]);

  return dio;
}

LogInterceptor _buildLogInterceptor() => LogInterceptor(
      requestHeader: false,
      responseHeader: false,
      requestBody: true,
      responseBody: true,
      logPrint: (o) => _log.d(o),
    );

/// Injects Authorization: Bearer <token> on every request if token is present.
class AuthInterceptor extends Interceptor {
  const AuthInterceptor(
    this._readToken, {
    bool Function()? demoModeReader,
  }) : _demoModeReader = demoModeReader;

  final TokenReader _readToken;
  final bool Function()? _demoModeReader;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_demoModeReader?.call() == true) {
      handler.next(options);
      return;
    }
    final token = _readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Translates FastAPI error shapes into readable [DioException] messages.
///
/// - 401 → propagated for auth interceptor in providers
/// - 410 → quiz expired
/// - 503 → toolchain unavailable
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response == null) {
      handler.next(err);
      return;
    }

    final status = response.statusCode;
    final message = _extractDetail(response.data);

    if (status == 410) {
      handler.next(
        err.copyWith(
          message: message ?? 'Quiz expired. Please fetch new questions.',
        ),
      );
      return;
    }

    if (status == 503) {
      handler.next(
        err.copyWith(
          message:
              message ?? 'Toolchain unavailable. Check server compiler setup.',
        ),
      );
      return;
    }

    handler.next(
      message != null ? err.copyWith(message: message) : err,
    );
  }

  static String? _extractDetail(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        return detail
            .map((e) => e is Map ? e['msg'] ?? e.toString() : e.toString())
            .join(', ');
      }
    }
    return null;
  }
}

extension DioExceptionCopy on DioException {
  DioException copyWith({String? message}) => DioException(
        type: type,
        error: error,
        message: message ?? this.message,
        requestOptions: requestOptions,
        response: response,
        stackTrace: stackTrace,
      );
}
