// ============================================================
// SmartAttend — API Client (Dio with JWT Interceptor + Token Refresh)
// ============================================================

import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import '../constants/app_constants.dart';
import '../services/storage_service.dart';

class ApiClient {
  static ApiClient get to => getx.Get.find();

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: Duration(seconds: AppConstants.connectTimeout),
        receiveTimeout: Duration(seconds: AppConstants.receiveTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // ─── JWT + Refresh Interceptor ────────────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.to.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Attempt token refresh
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry the original request with the new token
              final newToken = await StorageService.to.getToken();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                // Refresh failed — logout
              }
            }
            // Refresh failed → clear session and go to login
            await StorageService.to.clearAll();
            getx.Get.offAllNamed(AppConstants.routeLogin);
          }
          return handler.next(error);
        },
      ),
    );

    // ─── Logging Interceptor (dev only) ──────────────────
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
        logPrint: (obj) => print('[API] $obj'),
      ),
    );
  }

  // ─── Token Refresh ───────────────────────────────────────
  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await StorageService.to.getRefreshToken();
      if (refreshToken == null) return false;

      // Use a fresh Dio instance to avoid interceptor loop
      final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      await StorageService.to.saveToken(data['access_token']);
      await StorageService.to.saveRefreshToken(data['refresh_token']);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── GET ─────────────────────────────────────────────────
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  // ─── POST ────────────────────────────────────────────────
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters);
  }

  // ─── POST MULTIPART ──────────────────────────────────────
  Future<Response<T>> postMultipart<T>(
    String path,
    FormData formData,
  ) async {
    return _dio.post<T>(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // ─── PUT ─────────────────────────────────────────────────
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) async {
    return _dio.put<T>(path, data: data);
  }

  // ─── DELETE ──────────────────────────────────────────────
  Future<Response<T>> delete<T>(String path) async {
    return _dio.delete<T>(path);
  }

  // ─── DOWNLOAD FILE ────────────────────────────────────────
  /// Downloads a file from [path] and saves it to [savePath] on disk.
  /// Shows download progress via [onProgress] callback (optional).
  Future<void> download(
    String path,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    await _dio.download(
      path,
      savePath,
      onReceiveProgress: onProgress,
      options: Options(responseType: ResponseType.bytes),
    );
  }

  // ─── GET BYTES ────────────────────────────────────────────
  /// Returns the raw bytes of a binary response (e.g., Excel file).
  Future<List<int>> getBytes(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await _dio.get<List<int>>(
      path,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }
}

// ─── API Exception ──────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  factory ApiException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(message: 'Connection timed out. Please check your network.');
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        final msg = data is Map ? data['detail'] ?? 'Server error' : 'Server error';
        return ApiException(
          message: msg.toString(),
          statusCode: error.response?.statusCode,
        );
      case DioExceptionType.connectionError:
        return ApiException(message: 'Cannot reach the server. Make sure the backend is running at ${error.requestOptions.baseUrl}');
      default:
        return ApiException(message: 'An unexpected error occurred. Please try again.');
    }
  }

  @override
  String toString() => message;
}
