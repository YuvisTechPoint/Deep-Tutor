import 'package:dio/dio.dart';

/// True when the device cannot reach the API host (backend down, wrong URL, offline).
bool isConnectionDioError(DioException e) {
  return e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout;
}

int? dioStatusCode(Object error) {
  if (error is DioException) return error.response?.statusCode;
  return null;
}

bool isAuthDioError(Object error) {
  final code = dioStatusCode(error);
  return code == 401 || code == 403;
}

bool isNotFoundDioError(Object error) {
  return dioStatusCode(error) == 404;
}
