// ============================================================
// SmartAttend — Attendance Controller (v6)
// Deep-link → BLE → Verification Method → Face/QR → Mark
// v6: Session polling, fast-path classroom, alreadyMarked UX,
//     qr_face attendance method, duplicate error state
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;

import 'package:dio/dio.dart' as dio;
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/services/ble_service.dart';

enum AttendanceStep { idle, bleScanning, bleDone, faceCapture, verifying, done }
enum AttendanceResult { none, success, failed, outOfRange, alreadyMarked }
enum VerificationMethod { face, qr }

// ─── Active Session Info Model ────────────────────────────────
class ActiveSessionInfo {
  final int sessionId;
  final String subjectName;
  final String classroomName;
  final String classroomUuid;
  final bool alreadyMarked;
  final bool faceRegistered;

  const ActiveSessionInfo({
    required this.sessionId,
    required this.subjectName,
    required this.classroomName,
    required this.classroomUuid,
    required this.alreadyMarked,
    this.faceRegistered = true,
  });

  factory ActiveSessionInfo.fromJson(Map<String, dynamic> json) {
    return ActiveSessionInfo(
      sessionId: json['session_id'] as int,
      subjectName: json['subject_name'] as String? ?? 'Unknown Subject',
      classroomName: json['classroom_name'] as String? ?? 'Unknown Classroom',
      classroomUuid: json['classroom_uuid'] as String? ?? '',
      alreadyMarked: json['already_marked'] as bool? ?? false,
      faceRegistered: json['face_registered'] as bool? ?? true,
    );
  }
}

class AttendanceController extends GetxController {
  static AttendanceController get to => Get.find();

  ApiClient get _api => ApiClient.to;

  // ─── State ──────────────────────────────────────────────
  final Rx<AttendanceStep>    step              = AttendanceStep.idle.obs;
  final Rx<AttendanceResult>  result            = AttendanceResult.none.obs;
  final Rx<DetectedClassroom?> selectedClassroom = Rx<DetectedClassroom?>(null);
  final RxBool  isLoading          = false.obs;
  final RxString errorMessage      = ''.obs;
  final RxString error             = ''.obs; // alias used by QR screen
  final RxString successMessage    = ''.obs;
  final RxDouble confidenceScore   = 0.0.obs;
  final RxInt    capturedRssi      = 0.obs;
  final RxBool   hasDuplicateError = false.obs;

  // ─── Active Session (Dashboard) ──────────────────────────
  final Rx<ActiveSessionInfo?> activeSession = Rx<ActiveSessionInfo?>(null);
  final RxBool isCheckingSession = false.obs;

  bool get hasActiveSession => activeSession.value != null;
  bool get alreadyMarked    => activeSession.value?.alreadyMarked ?? false;

  // ─── Session Polling ─────────────────────────────────────
  Timer? _sessionPollTimer;

  /// Start polling the backend every [intervalSeconds] seconds.
  /// Safe to call multiple times — cancels any existing timer first.
  void startSessionPolling({int intervalSeconds = 30}) {
    _sessionPollTimer?.cancel();
    // Immediate check
    checkActiveSession();
    // Periodic checks
    _sessionPollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => checkActiveSession(),
    );
    dev.log(
      '[POLL] Session polling started — interval=${intervalSeconds}s',
      name: 'AttendanceController',
    );
  }

  /// Stop periodic session polling (e.g. when student navigates away).
  void stopSessionPolling() {
    _sessionPollTimer?.cancel();
    _sessionPollTimer = null;
    dev.log('[POLL] Session polling stopped', name: 'AttendanceController');
  }

  // ─── Selected Verification Method ────────────────────────
  final Rx<VerificationMethod> verificationMethod = VerificationMethod.face.obs;

  // ─── Deep Link Session Context ───────────────────────────
  final RxnInt   deepLinkSessionId       = RxnInt(null);
  final RxString deepLinkSessionSubject   = ''.obs;
  final RxString deepLinkSessionClassroom = ''.obs;
  final RxString deepLinkClassroomUuid    = ''.obs;

  // ─── Check Active Session (Dashboard) ────────────────────
  /// Called on dashboard init and by periodic timer.
  /// No BLE UUID required — checks for active session in student's dept/year/section.
  Future<void> checkActiveSession() async {
    isCheckingSession.value = true;
    try {
      final response = await _api.get(AppConstants.endpointCheckActiveSession);
      final data = response.data as Map<String, dynamic>;

      if (data['is_active'] == true) {
        activeSession.value = ActiveSessionInfo.fromJson(data);
        dev.log(
          '[SESSION_CHECK] Active session found: '
          'id=${data['session_id']}, subject=${data['subject_name']}',
          name: 'AttendanceController',
        );
      } else {
        activeSession.value = null;
        dev.log('[SESSION_CHECK] No active session', name: 'AttendanceController');
      }
    } on dio.DioException catch (e) {
      final err = ApiException.fromDioError(e);
      dev.log('[SESSION_CHECK] Error: ${err.message}', name: 'AttendanceController');
      // Silently fail — don't show error on dashboard
      activeSession.value = null;
    } catch (e) {
      dev.log('[SESSION_CHECK] Unexpected: $e', name: 'AttendanceController');
      activeSession.value = null;
    } finally {
      isCheckingSession.value = false;
    }
  }

  // ─── Lightweight Session Status Polling ──────────────────
  /// Fetches only is_active + already_marked (lighter endpoint).
  Future<void> refreshSessionStatus() async {
    try {
      final response = await _api.get(AppConstants.endpointSessionStatus);
      final data = response.data as Map<String, dynamic>;
      if (data['is_active'] == true && activeSession.value != null) {
        // Patch the alreadyMarked flag without full reload
        final current = activeSession.value!;
        if ((data['already_marked'] as bool? ?? false) != current.alreadyMarked) {
          activeSession.value = ActiveSessionInfo(
            sessionId: current.sessionId,
            subjectName: current.subjectName,
            classroomName: current.classroomName,
            classroomUuid: current.classroomUuid,
            alreadyMarked: data['already_marked'] as bool? ?? false,
            faceRegistered: current.faceRegistered,
          );
        }
      } else if (data['is_active'] == false) {
        activeSession.value = null;
      }
    } catch (_) {
      // Silently ignore — fallback to full checkActiveSession on next poll
    }
  }

  // ─── Set Deep Link Context ───────────────────────────────
  void setDeepLinkContext({
    required int sessionId,
    String? subjectName,
    String? classroomName,
    String? classroomUuid,
  }) {
    deepLinkSessionId.value        = sessionId;
    deepLinkSessionSubject.value   = subjectName  ?? '';
    deepLinkSessionClassroom.value = classroomName ?? '';
    deepLinkClassroomUuid.value    = classroomUuid ?? '';
    reset(); // clear any previous state
  }

  // ─── Step 1: Pre-verify session (optional early check) ──
  Future<bool> verifySession() async {
    final sessionId = deepLinkSessionId.value;
    if (sessionId == null) return false;

    try {
      final classroom = selectedClassroom.value;
      final formData = dio.FormData.fromMap({
        'session_id': sessionId.toString(),
        'rssi': (classroom?.rssi ?? capturedRssi.value).toString(),
      });
      final response = await _api.postMultipart('/attendance/verify', formData);
      final data = response.data as Map<String, dynamic>;
      return data['eligible'] == true;
    } catch (_) {
      return false;
    }
  }

  // ─── Step 2: Start BLE Scan ──────────────────────────────
  Future<void> startBLEScan() async {
    step.value = AttendanceStep.bleScanning;
    errorMessage.value = '';
    result.value = AttendanceResult.none;

    try {
      await BleService.to.startScan();
      step.value = AttendanceStep.bleDone;
    } catch (e) {
      errorMessage.value = 'BLE scan failed: ${e.toString()}';
      step.value = AttendanceStep.idle;
    }
  }

  // ─── Classroom Matches Helper ────────────────────────────
  bool _classroomMatches(DetectedClassroom classroom, String expectedUuid, String expectedName) {
    String clean(String s) {
      return s.toUpperCase().replaceAll(':', '').replaceAll('-', '').replaceAll('_', '').replaceAll(' ', '');
    }

    final bleUuid = clean(classroom.deviceId);
    final bleName = clean(classroom.name);
    final expUuid = clean(expectedUuid);
    final expName = clean(expectedName);

    if (expUuid.isEmpty) return true;
    if (bleUuid.contains(expUuid) || expUuid.contains(bleUuid)) return true;
    if (bleName.contains(expUuid) || expUuid.contains(bleName)) return true;
    if (expName.isNotEmpty && (bleName.contains(expName) || expName.contains(bleName))) return true;

    return false;
  }

  // ─── Step 3: Select Classroom → Navigate to Method Screen ─
  Future<void> selectClassroom(DetectedClassroom classroom) async {
    dev.log(
      '[CLASSROOM] Selected: name=${classroom.name}, id=${classroom.deviceId}, rssi=${classroom.rssi}',
      name: 'AttendanceController',
    );

    if (!classroom.isInRange) {
      result.value = AttendanceResult.outOfRange;
      errorMessage.value = 'You are out of classroom range. Move closer.';
      Get.toNamed(AppConstants.routeAttendanceResult);
      return;
    }

    // ─── Fast-path: use activeSession if deepLink not set ─
    if (deepLinkSessionId.value == null && activeSession.value != null) {
      final session = activeSession.value!;
      dev.log(
        '[CLASSROOM] Fast-path: using dashboard activeSession id=${session.sessionId}',
        name: 'AttendanceController',
      );
      setDeepLinkContext(
        sessionId: session.sessionId,
        subjectName: session.subjectName,
        classroomName: session.classroomName,
        classroomUuid: session.classroomUuid,
      );
    }

    // ─── Fallback API lookup if still not set ────────────
    if (deepLinkSessionId.value == null) {
      isLoading.value = true;
      errorMessage.value = '';
      try {
        final response = await _api.get('/attendance/active-session', queryParameters: {
          'classroom_uuid': classroom.deviceId,
          'classroom_name': classroom.name,
        });

        final data = response.data as Map<String, dynamic>;
        final int? activeSessionId = data['session_id'];

        if (activeSessionId != null) {
          setDeepLinkContext(
            sessionId: activeSessionId,
            subjectName: data['subject_name'] as String?,
            classroomName: data['classroom_name'] as String?,
            classroomUuid: data['classroom_uuid'] as String?,
          );
        } else {
          errorMessage.value = 'No active attendance session found in this classroom.';
          result.value = AttendanceResult.failed;
          Get.toNamed(AppConstants.routeAttendanceResult);
          return;
        }
      } on dio.DioException catch (e) {
        final err = ApiException.fromDioError(e);
        errorMessage.value = err.message;
        result.value = AttendanceResult.failed;
        Get.toNamed(AppConstants.routeAttendanceResult);
        return;
      } catch (e) {
        errorMessage.value = 'Failed to fetch active session: $e';
        result.value = AttendanceResult.failed;
        Get.toNamed(AppConstants.routeAttendanceResult);
        return;
      } finally {
        isLoading.value = false;
      }
    }

    // Validate classroom matches expected deep-link UUID
    final expectedUuid = deepLinkClassroomUuid.value;
    final expectedName = deepLinkSessionClassroom.value;
    if (expectedUuid.isNotEmpty && !_classroomMatches(classroom, expectedUuid, expectedName)) {
      errorMessage.value = 'Wrong classroom detected. Please go to $expectedName.';
      result.value = AttendanceResult.failed;
      Get.toNamed(AppConstants.routeAttendanceResult);
      return;
    }

    selectedClassroom.value = classroom;
    capturedRssi.value = classroom.rssi;
    step.value = AttendanceStep.faceCapture;

    // ─── Navigate to Verification Method Selection ─────────
    Get.toNamed(AppConstants.routeVerificationMethod);
  }

  // ─── QR Token Validation (new flow) ─────────────────────
  /// Validates QR token via backend without marking attendance.
  /// On success, sets session context and returns true.
  /// Navigation to face verification is handled by the UI.
  Future<bool> validateQrToken(String qrToken) async {
    isLoading.value = true;
    error.value = '';
    errorMessage.value = '';
    hasDuplicateError.value = false;

    // First try to decode locally for speed
    int? localSessionId;
    try {
      final parts = qrToken.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decodedStr = utf8.decode(base64Url.decode(normalized));
        final payloadMap = json.decode(decodedStr) as Map<String, dynamic>;
        if (payloadMap['type'] == 'qr_attendance') {
          localSessionId = payloadMap['session_id'] as int?;
        }
      }
    } catch (e) {
      dev.log('[QR_VALIDATE] Local JWT decode failed: $e', name: 'AttendanceController');
    }

    if (localSessionId == null) {
      isLoading.value = false;
      error.value = 'Invalid QR code. Please scan a valid SmartAttend attendance QR.';
      errorMessage.value = error.value;
      return false;
    }

    try {
      // Validate with backend
      final response = await _api.post(
        AppConstants.endpointValidateQr,
        data: {'qr_token': qrToken},
      );
      final data = response.data as Map<String, dynamic>;

      if (data['valid'] == true) {
        final sessionId = data['session_id'] as int;
        setDeepLinkContext(
          sessionId: sessionId,
          subjectName: data['subject_name'] as String?,
          classroomName: data['classroom_name'] as String?,
          classroomUuid: data['classroom_uuid'] as String?,
        );
        // Bypass BLE for QR path
        capturedRssi.value = 0;
        step.value = AttendanceStep.faceCapture;
        dev.log('[QR_VALIDATE] ✅ Valid QR, session=$sessionId', name: 'AttendanceController');
        return true;
      } else {
        error.value = data['message'] ?? 'QR validation failed.';
        errorMessage.value = error.value;
        return false;
      }
    } on dio.DioException catch (e) {
      final err = ApiException.fromDioError(e);
      if (err.statusCode == 409) {
        error.value = 'You have already marked attendance for this session.';
        errorMessage.value = error.value;
        result.value = AttendanceResult.alreadyMarked;
        hasDuplicateError.value = true;
      } else {
        error.value = err.message;
        errorMessage.value = error.value;
      }
      return false;
    } catch (e) {
      error.value = e.toString();
      errorMessage.value = error.value;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Step 4: Verify Face ──────────────────────────────────
  Future<void> verifyFace({
    required File imageFile,
    String? livenessToken,
    String attendanceMethodHint = 'ble_face',
  }) async {
    step.value = AttendanceStep.verifying;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      dev.log(
        '[VERIFY_FACE] session=${deepLinkSessionId.value}, '
        'rssi=${capturedRssi.value}, method=$attendanceMethodHint',
        name: 'AttendanceController',
      );

      final response = await _verifyAndMark(
        imageFile,
        livenessToken: livenessToken,
        attendanceMethodHint: attendanceMethodHint,
      );

      final tier = response['tier'] as String? ?? 'present';
      if (tier == 'rejected') {
        result.value = AttendanceResult.failed;
        errorMessage.value = response['message'] ?? 'Face not recognized. Please try again.';
      } else {
        result.value = AttendanceResult.success;
        successMessage.value = response['message'] ?? (
          tier == 'manual_review'
              ? 'Attendance flagged for review ⚠️'
              : 'Attendance marked successfully! ✅'
        );
        // Refresh dashboard session status
        await checkActiveSession();
      }
    } on dio.DioException catch (e) {
      final err = ApiException.fromDioError(e);
      if (err.statusCode == 409) {
        result.value = AttendanceResult.alreadyMarked;
        errorMessage.value = 'Attendance already marked for this session.';
        hasDuplicateError.value = true;
      } else {
        result.value = AttendanceResult.failed;
        errorMessage.value = err.message;
      }
    } catch (e) {
      result.value = AttendanceResult.failed;
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
      step.value = AttendanceStep.done;
      Get.offNamed(AppConstants.routeAttendanceResult);
    }
  }

  // ─── API: Verify Face + Mark Attendance ──────────────────
  Future<Map<String, dynamic>> _verifyAndMark(
    File imageFile, {
    String? livenessToken,
    String attendanceMethodHint = 'ble_face',
  }) async {
    final classroom = selectedClassroom.value;
    final sessionId = deepLinkSessionId.value;

    if (sessionId == null) {
      throw Exception('No session found. Please select a classroom or tap the WhatsApp link first.');
    }

    final formData = dio.FormData.fromMap({
      'file':       await dio.MultipartFile.fromFile(imageFile.path, filename: 'face.jpg'),
      'session_id': sessionId.toString(),
      'rssi':       (classroom?.rssi ?? capturedRssi.value).toString(),
      'attendance_method_hint': attendanceMethodHint,
      if (livenessToken != null && livenessToken.isNotEmpty)
        'liveness_token': livenessToken,
    });

    final response = await _api.postMultipart('/attendance/mark', formData);
    return response.data as Map<String, dynamic>;
  }

  // ─── Legacy: mark-qr (kept for backward compat) ─────────
  Future<bool> markAttendanceViaQr(String qrToken) async {
    isLoading.value = true;
    error.value = '';
    try {
      final response = await _api.post('/attendance/mark-qr', data: {'qr_token': qrToken});
      final data = response.data as Map<String, dynamic>;
      return data['marked'] == true;
    } on dio.DioException catch (e) {
      final err = ApiException.fromDioError(e);
      error.value = err.message;
      return false;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Fetch Session Info ──────────────────────────────────
  Future<void> fetchSessionInfo(int sessionId) async {
    errorMessage.value = '';
    try {
      final formData = dio.FormData.fromMap({
        'session_id': sessionId.toString(),
        'rssi': '0',
      });
      final response = await _api.postMultipart('/attendance/verify', formData);
      final data = response.data as Map<String, dynamic>;

      if (data['eligible'] == true || data['step'] == 'duplicate') {
        deepLinkSessionSubject.value   = data['subject_name'] ?? '';
        deepLinkSessionClassroom.value = data['classroom_name'] ?? '';
        deepLinkClassroomUuid.value    = data['classroom_uuid'] ?? '';

        if (data['step'] == 'duplicate') {
          errorMessage.value = data['message'] ?? 'Attendance already marked.';
          hasDuplicateError.value = true;
        }
      } else {
        errorMessage.value = data['message'] ?? 'Not eligible for this session';
        deepLinkSessionSubject.value   = data['subject_name'] ?? '';
        deepLinkSessionClassroom.value = data['classroom_name'] ?? '';
        deepLinkClassroomUuid.value    = data['classroom_uuid'] ?? '';
      }
    } on dio.DioException catch (e) {
      final err = ApiException.fromDioError(e);
      errorMessage.value = err.message;
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  // ─── Copy attendance link to clipboard ──────────────────
  Future<void> copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    Get.snackbar(
      'Link Copied',
      'Attendance link copied to clipboard.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  // ─── Reset for next attempt ──────────────────────────────
  void reset() {
    step.value = AttendanceStep.idle;
    result.value = AttendanceResult.none;
    selectedClassroom.value = null;
    errorMessage.value = '';
    successMessage.value = '';
    confidenceScore.value = 0.0;
    capturedRssi.value = 0;
    error.value = '';
    hasDuplicateError.value = false;
  }

  // ─── Clear deep link context ─────────────────────────────
  void clearDeepLinkContext() {
    deepLinkSessionId.value        = null;
    deepLinkSessionSubject.value   = '';
    deepLinkSessionClassroom.value = '';
    deepLinkClassroomUuid.value    = '';
    reset();
  }

  @override
  void onClose() {
    stopSessionPolling();
    super.onClose();
  }
}