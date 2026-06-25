// ============================================================
// SmartAttend — Attendance Controller (v4)
// Deep-link → BLE → Liveness → Face verify → Mark attendance
// v4: liveness token forwarding, confidence tier handling
// ============================================================

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

class AttendanceController extends GetxController {
  static AttendanceController get to => Get.find();

  ApiClient get _api => ApiClient.to;

  // ─── State ──────────────────────────────────────────────
  final Rx<AttendanceStep>   step             = AttendanceStep.idle.obs;
  final Rx<AttendanceResult> result           = AttendanceResult.none.obs;
  final Rx<DetectedClassroom?> selectedClassroom = Rx<DetectedClassroom?>(null);
  final RxBool isLoading      = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString error        = ''.obs; // alias used by QR screen
  final RxString successMessage = ''.obs;
  final RxDouble confidenceScore = 0.0.obs;
  final RxInt capturedRssi = 0.obs;

  // ─── Deep Link Session Context ───────────────────────────
  /// Session ID from the WhatsApp deep link (primary attendance method).
  /// When set, BLE matching is done against the session's classroom UUID.
  final RxnInt deepLinkSessionId = RxnInt(null);
  final RxString deepLinkSessionSubject   = ''.obs;
  final RxString deepLinkSessionClassroom = ''.obs;
  final RxString deepLinkClassroomUuid    = ''.obs;

  // ─── Set Deep Link Context ───────────────────────────────
  /// Called by DeepLinkService or navigation args when the student
  /// taps the WhatsApp attendance link.
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

  // ─── Step 3: Select Classroom ────────────────────────────
  /// When a deep-link session is active, validate that the detected
  /// classroom UUID matches the session's classroom.
  /// FALLBACK: if deepLinkSessionId is null, fetches the active session
  /// by classroom BLE UUID or name.
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

    // Check device ID matching expected UUID
    if (bleUuid.contains(expUuid) || expUuid.contains(bleUuid)) return true;
    
    // Check name matching expected UUID
    if (bleName.contains(expUuid) || expUuid.contains(bleName)) return true;

    // Check name matching expected Name
    if (expName.isNotEmpty && (bleName.contains(expName) || expName.contains(bleName))) return true;

    return false;
  }

  // ─── Step 3: Select Classroom ────────────────────────────
  /// When a deep-link session is active, validate that the detected
  /// classroom UUID matches the session's classroom.
  /// FALLBACK: if deepLinkSessionId is null, fetches the active session
  /// by classroom BLE UUID or name.
  Future<void> selectClassroom(DetectedClassroom classroom) async {
    dev.log('[LOG] Classroom selected: name=${classroom.name}, deviceId=${classroom.deviceId}, rssi=${classroom.rssi} dBm', name: 'AttendanceController');
    dev.log(
      '[DETECTED_CLASSROOM] selectClassroom selected: '
      'name=${classroom.name}, deviceId=${classroom.deviceId}, '
      'rssi=${classroom.rssi} dBm, isInRange=${classroom.isInRange}',
      name: 'AttendanceController',
    );

    if (!classroom.isInRange) {
      result.value = AttendanceResult.outOfRange;
      errorMessage.value = 'You are out of classroom range. Move closer.';
      Get.toNamed(AppConstants.routeAttendanceResult);
      return;
    }

    // ─── Fallback active session lookup if launched directly ───
    if (deepLinkSessionId.value == null) {
      dev.log(
        '[ACTIVE_SESSION_LOOKUP] Querying active session for classroom name=${classroom.name}, uuid=${classroom.deviceId}',
        name: 'AttendanceController',
      );
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
          dev.log(
            '[ACTIVE_SESSION_LOOKUP] Resolved active session ID: $activeSessionId for classroom: ${data['classroom_name']}',
            name: 'AttendanceController',
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

    // Verify classroom matches expected deep-link UUID (either deviceId or room_name contains it)
    final expectedUuid = deepLinkClassroomUuid.value;
    final expectedName = deepLinkSessionClassroom.value;
    dev.log(
      '[EXPECTED_CLASSROOM] Performing classroom validation: '
      'expectedUuid=$expectedUuid, expectedName=$expectedName',
      name: 'AttendanceController',
    );
    if (expectedUuid.isNotEmpty && !_classroomMatches(classroom, expectedUuid, expectedName)) {
      dev.log(
        '[EXPECTED_CLASSROOM] VALIDATION FAILED: Classroom mismatch! '
        'Wrong classroom detected. Expected: $expectedName',
        name: 'AttendanceController',
      );
      errorMessage.value = 'Wrong classroom detected. Please go to $expectedName.';
      result.value = AttendanceResult.failed;
      Get.toNamed(AppConstants.routeAttendanceResult);
      return;
    }

    selectedClassroom.value = classroom;
    capturedRssi.value = classroom.rssi;
    step.value = AttendanceStep.faceCapture;
    Get.toNamed(AppConstants.routeAttendanceVerification);
  }

  // ─── Step 4: Verify Face ──────────────────────────────────
  /// [imageFile]: Pre-captured image file from the verification screen.
  ///   The student has already reviewed and approved this image.
  /// [livenessToken]: Optional signed JWT from liveness verification.
  Future<void> verifyFace({
    required File imageFile,
    String? livenessToken,
  }) async {
    step.value = AttendanceStep.verifying;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      dev.log('[LOG] API called: verifyFace /attendance/mark for session_id=${deepLinkSessionId.value}', name: 'AttendanceController');
      dev.log("========== FACE VERIFY DEBUG ==========");
      dev.log("[CAMERA] Using pre-captured image: ${imageFile.path}");
      dev.log("[SESSION] Session ID: ${deepLinkSessionId.value}");
      dev.log("[LIVENESS] Token present: ${livenessToken != null}");
      dev.log("[BLE] Classroom: ${selectedClassroom.value?.name}");
      dev.log("[BLE] RSSI: ${capturedRssi.value} dBm");
      dev.log("=======================================");

      dev.log("[ArcFace] Sending face for embedding verification...", name: 'AttendanceController');

      // Send to backend
      final response = await _verifyAndMark(
        imageFile,
        livenessToken: livenessToken,
      );

      dev.log(
        "[ArcFace] Response received: "
        "match=${response['match']}, "
        "tier=${response['tier']}, "
        "confidence=${response['confidence']}, "
        "attendance_id=${response['attendance_id']}",
        name: 'AttendanceController',
      );

      // v4 tier handling
      final tier = response['tier'] as String? ?? 'present';
      if (tier == 'rejected') {
        result.value = AttendanceResult.failed;
        errorMessage.value = response['message'] ?? 'Face not recognized. Please try again.';
      } else {
        // 'present' or 'manual_review' both count as success
        result.value = AttendanceResult.success;
        successMessage.value = response['message'] ?? (
          tier == 'manual_review'
              ? 'Attendance flagged for review ⚠️'
              : 'Attendance marked successfully! ✅'
        );
      }
    } on dio.DioException catch (e) {
      final err = ApiException.fromDioError(e);
      if (err.statusCode == 409) {
        result.value = AttendanceResult.alreadyMarked;
        errorMessage.value = 'Attendance already marked for this session.';
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

  // ─── API: Verify Face + Mark Attendance ──────────────────────
  /// Uses session_id from the deep link — the primary attendance method.
  /// FALLBACK: if deepLinkSessionId is null, tries to resolve via classroom UUID
  /// detected by BLE. This supports the case where the student opens the app
  /// directly without tapping a WhatsApp link.
  /// [livenessToken]: Optional signed challenge JWT for anti-spoofing.
  Future<Map<String, dynamic>> _verifyAndMark(
    File imageFile, {
    String? livenessToken,
  }) async {
    final classroom = selectedClassroom.value;
    int? sessionId = deepLinkSessionId.value;

    dev.log(
      '[MARK] _verifyAndMark called: '
      'deepLinkSessionId=$sessionId, '
      'selectedClassroom=${classroom?.deviceId}, '
      'rssi=${classroom?.rssi ?? capturedRssi.value}',
      name: 'AttendanceController',
    );

    if (sessionId == null) {
      throw Exception(
        'No session found. Please select a classroom or tap the WhatsApp link first.',
      );
    }

    dev.log(
      '[MARK] Sending to /attendance/mark: '
      'session_id=$sessionId, '
      'rssi=${classroom?.rssi ?? capturedRssi.value} dBm, '
      'liveness=${livenessToken != null}',
      name: 'AttendanceController',
    );

    final formData = dio.FormData.fromMap({
      'file':       await dio.MultipartFile.fromFile(imageFile.path, filename: 'face.jpg'),
      'session_id': sessionId.toString(),
      'rssi':       (classroom?.rssi ?? capturedRssi.value).toString(),
      if (livenessToken != null && livenessToken.isNotEmpty)
        'liveness_token': livenessToken,
    });

    final response = await _api.postMultipart('/attendance/mark', formData);
    final data = response.data as Map<String, dynamic>;
    dev.log('[LOG] API response received from /attendance/mark: $data', name: 'AttendanceController');

    dev.log(
      '[MARK] Response: '
      'match=${data['match']}, '
      'tier=${data['tier']}, '
      'confidence=${data['confidence']}, '
      'attendance_id=${data['attendance_id']}',
      name: 'AttendanceController',
    );

    return data;
  }

  Future<void> fetchSessionInfo(int sessionId) async {
    dev.log(
      '[FETCH] fetchSessionInfo called for session_id=$sessionId',
      name: 'AttendanceController',
    );
    errorMessage.value = '';
    try {
      // POST /attendance/verify with rssi=0 to skip BLE check at this stage
      final formData = dio.FormData.fromMap({
        'session_id': sessionId.toString(),
        'rssi': '0', // initial check — RSSI validated later after BLE scan
      });
      final response = await _api.postMultipart('/attendance/verify', formData);
      final data = response.data as Map<String, dynamic>;

      dev.log(
        '[FETCH] Response: eligible=${data['eligible']}, step=${data['step']}, '
        'classroom=${data['classroom_name']}, uuid=${data['classroom_uuid']}, '
        'subject=${data['subject_name']}',
        name: 'AttendanceController',
      );

      if (data['eligible'] == true || data['step'] == 'duplicate') {
        deepLinkSessionSubject.value   = data['subject_name'] ?? '';
        deepLinkSessionClassroom.value = data['classroom_name'] ?? '';
        deepLinkClassroomUuid.value    = data['classroom_uuid'] ?? '';

        dev.log(
          '[FETCH] Session context set: '
          'subject=${deepLinkSessionSubject.value}, '
          'classroom=${deepLinkSessionClassroom.value}, '
          'uuid=${deepLinkClassroomUuid.value}',
          name: 'AttendanceController',
        );

        if (data['step'] == 'duplicate') {
          errorMessage.value = data['message'] ?? 'Attendance already marked.';
        }
      } else {
        dev.log(
          '[FETCH] Session verify returned not-eligible: '
          'step=${data['step']}, message=${data['message']}',
          name: 'AttendanceController',
        );
        errorMessage.value = data['message'] ?? 'Not eligible for this session';
        // Set subject/classroom even when not eligible (so UI can display it)
        deepLinkSessionSubject.value   = data['subject_name'] ?? '';
        deepLinkSessionClassroom.value = data['classroom_name'] ?? '';
        deepLinkClassroomUuid.value    = data['classroom_uuid'] ?? '';
      }
    } on dio.DioException catch (e) {
      final err = ApiException.fromDioError(e);
      dev.log(
        '[FETCH] DioException: status=${err.statusCode}, message=${err.message}',
        name: 'AttendanceController',
        error: e,
      );
      errorMessage.value = err.message;
    } catch (e) {
      dev.log(
        '[FETCH] Unexpected error: $e',
        name: 'AttendanceController',
        error: e,
      );
      errorMessage.value = e.toString();
    }
  }

  // ─── QR Attendance: Mark via scanned token ───────────────
  /// Called by QrScannerScreen after scanning faculty-generated QR.
  Future<bool> markAttendanceViaQr(String qrToken) async {
    isLoading.value = true;
    error.value = '';
    try {
      final response = await _api.post('/attendance/mark-qr', data: {
        'qr_token': qrToken,
      });
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
  }

  /// Clear deep link context after session ends or user navigates away.
  void clearDeepLinkContext() {
    deepLinkSessionId.value       = null;
    deepLinkSessionSubject.value  = '';
    deepLinkSessionClassroom.value = '';
    deepLinkClassroomUuid.value   = '';
    reset();
  }
} 