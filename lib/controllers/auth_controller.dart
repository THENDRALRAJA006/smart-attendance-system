// ============================================================
// SmartAttend — Auth Controller
// Handles login, registration, role routing
// ============================================================

import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/services/storage_service.dart';
import '../models/models.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  ApiClient get _api => ApiClient.to;

  // ─── State ──────────────────────────────────────────────
  final RxBool isLoading = false.obs;
  final Rx<StudentModel?> currentStudent = Rx<StudentModel?>(null);
  final Rx<FacultyModel?> currentFaculty = Rx<FacultyModel?>(null);
  final RxString role = ''.obs;
  final RxString errorMessage = ''.obs;

  /// True when any user role is authenticated
  bool get isAuthenticated => role.value.isNotEmpty;

  // ─── LOGIN ──────────────────────────────────────────────
  Future<void> login(String email, String password, String userRole) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _api.post(
        '/auth/login',
        data: {'email': email, 'password': password, 'role': userRole},
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String? ?? '';
      final returnedRole = data['role'] as String;

      await StorageService.to.saveToken(token);
      if (refreshToken.isNotEmpty) {
        await StorageService.to.saveRefreshToken(refreshToken);
      }
      await StorageService.to.saveRole(returnedRole);
      role.value = returnedRole;

      final redirect = Get.parameters['redirect_after_login'];

      if (returnedRole == 'student') {
        currentStudent.value = StudentModel.fromJson(data['user']);
        await StorageService.to.saveUser(data['user']);
        Get.offAllNamed(redirect ?? AppConstants.routeStudentDashboard);
      } else if (returnedRole == 'faculty') {
        final userData = data['user'] as Map<String, dynamic>;
        currentFaculty.value = FacultyModel.fromJson(userData);
        await StorageService.to.saveUser(userData);
        Get.offAllNamed(redirect ?? AppConstants.routeFacultyDashboard);
      } else if (returnedRole == 'admin') {
        await StorageService.to.saveUser(data['user']);
        Get.offAllNamed(redirect ?? AppConstants.routeAdminDashboard);
      }
    } on dio.DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── REGISTER STUDENT ───────────────────────────────────
  Future<bool> registerStudent({
    required String name,
    required String regNo,
    required String department,
    required int year,
    required String section,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _api.post(
        '/auth/register',
        data: {
          'name': name,
          'reg_no': regNo,
          'department': department,
          'year': year,
          'section': section,
          'email': email,
          'password': password,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone_number': phoneNumber,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String? ?? '';
      await StorageService.to.saveToken(token);
      if (refreshToken.isNotEmpty) {
        await StorageService.to.saveRefreshToken(refreshToken);
      }
      await StorageService.to.saveRole('student');
      currentStudent.value = StudentModel.fromJson(data['user']);
      await StorageService.to.saveUser(data['user']);
      role.value = 'student';
      return true;
    } on dio.DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── FACE REGISTER ──────────────────────────────────────
  Future<bool> registerFace(String imagePath) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final formData = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(imagePath, filename: 'face.jpg'),
      });

      await _api.postMultipart('/auth/face-register', formData);
      // Reload student to get updated face_id
      return true;
    } on dio.DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── AUTO-LOGIN (check saved token) ─────────────────────
  Future<void> checkAuthState() async {
    final isLoggedIn = await StorageService.to.isLoggedIn();
    if (!isLoggedIn) {
      Get.offAllNamed(AppConstants.routeLogin);
      return;
    }

    final savedRole = await StorageService.to.getRole();
    final userData = await StorageService.to.getUser();
    role.value = savedRole ?? '';

    if (savedRole == 'student' && userData != null) {
      currentStudent.value = StudentModel.fromJson(userData);
      Get.offAllNamed(AppConstants.routeStudentDashboard);
    } else if (savedRole == 'faculty' && userData != null) {
      currentFaculty.value = FacultyModel.fromJson(userData);
      Get.offAllNamed(AppConstants.routeFacultyDashboard);
    } else if (savedRole == 'admin') {
      Get.offAllNamed(AppConstants.routeAdminDashboard);
    } else {
      Get.offAllNamed(AppConstants.routeLogin);
    }
  }

  // ─── LOGOUT ─────────────────────────────────────────────
  Future<void> logout() async {
    await StorageService.to.clearAll();
    currentStudent.value = null;
    currentFaculty.value = null;
    role.value = '';
    Get.offAllNamed(AppConstants.routeLogin);
  }
}
