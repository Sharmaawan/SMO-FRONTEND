import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'app_config.dart';
import 'dart:developer' as dev;

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio _dio;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add Logging Interceptor
    _dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
      maxWidth: 90,
      logPrint: (object) => dev.log(object.toString(), name: 'API_LOG'),
    ));

    // Actor ID Interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final empId = _dio.options.headers['X-EMP-ID'];
        if (empId != null) {
          options.queryParameters['actorEmpId'] = empId;
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        String errorMessage = _handleError(e);
        dev.log('API_ERROR: $errorMessage', name: 'API_ERROR', error: e);
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;

  void setEmpId(String empId) {
    _dio.options.headers['X-EMP-ID'] = empId;
  }

  void clearEmpId() {
    _dio.options.headers.remove('X-EMP-ID');
  }

  String _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Connection timed out. Please check your internet.";
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        if (statusCode == 400) return "Bad Request: ${data ?? 'Invalid input'}";
        if (statusCode == 401) return "Unauthorized: Please login again.";
        if (statusCode == 403) return "Forbidden: Access denied.";
        if (statusCode == 404) return "Not Found: Server resource missing.";
        if (statusCode == 500) return "Server Error: Please try again later.";
        return "HTTP Error $statusCode: ${data ?? 'Unknown error'}";
      case DioExceptionType.cancel:
        return "Request cancelled.";
      case DioExceptionType.connectionError:
        return "No internet connection.";
      default:
        return "Something went wrong. Please try again.";
    }
  }
}
