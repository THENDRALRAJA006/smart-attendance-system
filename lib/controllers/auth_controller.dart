// ============================================================
// SmartAttend — Auth Controller (v4)
// Handles login, registration, role routing
// v4: 15-pose face registration + liveness challenge
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

  // v4: multi-pose registration state
  final RxInt currentPoseIndex = 1.obs;          // 1-15
  final RxBool poseRegistrationComplete = false.obs;
  final RxList<Map<String, dynamic>> registeredPoses =
      <Map<String, dynamic>>[].obs;  // results per pose

  // v4: liveness state
  final RxString livenessChallenge = ''.obs;
  final RxString livenessInstruction = ''.obs;
  final RxString liveChallengeToken = ''.obs;
  final RxBool livenessVerified = false.obs;

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
      print("LOGIN USER DATA:");
      print(data['user']);
      print("FACE ID: ${data['user']['face_id']}");
      print("FACE URL: ${data['user']['face_image_url']}");

      currentStudent.value = StudentModel.fromJson(data['user']);

      await StorageService.to.saveUser(data['user']);

      Get.offAllNamed(redirect ?? AppConstants.routeStudentDashboard,);
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

  // ─── FACE REGISTER (Legacy — single image) ──────────────────────
  Future<bool> registerFace(String imagePath) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final formData = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(imagePath, filename: 'face.jpg'),
      });
      await _api.postMultipart('/auth/face-register', formData);
      return true;
    } on dio.DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── v4: FACE REGISTER — One Pose in 15-Step Sequence ────────────
  /// Upload and register a single pose image to the backend.
  /// Call once per pose step. Advances [currentPoseIndex] on success.
  ///
  /// Returns:
  ///   Map containing: success, pose_index, face_id, quality, next_pose
  Future<Map<String, dynamic>?> registerFacePose({
    required String imagePath,
    required int poseIndex,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final formData = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(
          imagePath,
          filename: 'face_pose_$poseIndex.jpg',
        ),
        'pose_index': poseIndex,
      });
      final res = await _api.postMultipart(
        '/auth/face-register-multi',
        formData,
      );
      final data = res.data as Map<String, dynamic>;

      if (data['success'] == true) {
        // Record successful pose
        registeredPoses.add({
          'pose_index': poseIndex,
          'pose_type':  data['pose_type'],
          'face_id':    data['face_id'],
          'confidence': data['confidence'],
          's3_url':     data['s3_url'],
        });

        if (data['is_final'] == true) {
          poseRegistrationComplete.value = true;
        } else {
          currentPoseIndex.value = poseIndex + 1;
        }
      } else {
        errorMessage.value = data['message'] ?? 'Quality check failed. Try again.';
      }

      return data;
    } on dio.DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Reset pose registration state (e.g. when re-registering)
  void resetPoseRegistration() {
    currentPoseIndex.value = 1;
    poseRegistrationComplete.value = false;
    registeredPoses.clear();
    errorMessage.value = '';
  }

  // ─── v4: LIVENESS CHALLENGE ──────────────────────────────────
  /// Fetch a random liveness challenge from the server.
  /// Sets [livenessChallenge], [livenessInstruction], [liveChallengeToken].
  Future<bool> fetchLivenessChallenge() async {
    isLoading.value = true;
    errorMessage.value = '';
    livenessVerified.value = false;
    try {
      final res = await _api.get('/auth/liveness-challenge');
      final data = res.data as Map<String, dynamic>;
      livenessChallenge.value   = data['challenge_type'] ?? '';
      livenessInstruction.value = data['instruction'] ?? '';
      liveChallengeToken.value  = data['token'] ?? '';
      return true;
    } on dio.DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Submit liveness frames to verify the challenge.
  /// [framePaths]: List of 1-3 image file paths captured during challenge.
  /// Returns the full verification result map.
  Future<Map<String, dynamic>?> verifyLiveness(
    List<String> framePaths,
  ) async {
    if (liveChallengeToken.value.isEmpty) {
      errorMessage.value = 'No active challenge. Please fetch a new one.';
      return null;
    }
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final files = await Future.wait(
        framePaths.map((p) async =>
          dio.MultipartFile.fromFile(p, filename: 'liveness_frame.jpg')),
      );
      final formData = dio.FormData.fromMap({
        'files': files,
        'challenge_token': liveChallengeToken.value,
      });
      final res = await _api.postMultipart('/auth/liveness-verify', formData);
      final data = res.data as Map<String, dynamic>;
      livenessVerified.value = data['passed'] == true;
      if (!livenessVerified.value) {
        errorMessage.value = data['message'] ?? 'Liveness check failed. Please try again.';
      }
      return data;
    } on dio.DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      return null;
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
    print("========== STORAGE DEBUG ==========");
    print("Saved Role: $savedRole");
    print("User Data:");
    print(userData);
    print("===================================");
    role.value = savedRole ?? '';

    if (savedRole == 'student' && userData != null) {
      currentStudent.value = StudentModel.fromJson(userData);
      print("===== STUDENT DEBUG =====");
      print("Face ID: ${currentStudent.value?.faceId}");
      print("Face URL: ${currentStudent.value?.faceImageUrl}");
      print("=========================");

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
