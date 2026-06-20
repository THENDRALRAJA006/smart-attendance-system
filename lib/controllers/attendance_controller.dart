// ============================================================
// SmartAttend — Attendance Controller (v3)
// Deep-link → BLE → Face verify → Mark attendance
// Now uses session_id from WhatsApp deep link (no code entry)
// ============================================================

import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/services/ble_service.dart';
import '../core/services/camera_service.dart';

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
  void selectClassroom(DetectedClassroom classroom) {
    if (!classroom.isInRange) {
      result.value = AttendanceResult.outOfRange;
      errorMessage.value = 'You are out of classroom range. Move closer.';
      Get.toNamed(AppConstants.routeAttendanceSuccess);
      return;
    }

    // If we have a deep-link classroom UUID, verify it matches
    final expectedUuid = deepLinkClassroomUuid.value;
    if (expectedUuid.isNotEmpty) {
      final bleUuid = classroom.deviceId.toUpperCase();
      final expected = expectedUuid.toUpperCase();
      if (!bleUuid.contains(expected) && !expected.contains(bleUuid)) {
        errorMessage.value =
            'Wrong classroom detected. Please go to '
            '${deepLinkSessionClassroom.value}.';
        result.value = AttendanceResult.failed;
        Get.toNamed(AppConstants.routeAttendanceSuccess);
        return;
      }
    }

    selectedClassroom.value = classroom;
    capturedRssi.value = classroom.rssi;
    step.value = AttendanceStep.faceCapture;
    Get.toNamed(AppConstants.routeAttendanceVerification);
  }

  // ─── Step 4: Capture & Verify Face ──────────────────────
  Future<void> captureAndVerify() async {
    step.value = AttendanceStep.verifying;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Capture face image
      final imageFile = await CameraService.to.captureImage();

      // Send to backend for face verification + attendance marking
      final response = await _verifyAndMark(imageFile);
      confidenceScore.value = (response['confidence'] as num? ?? 0.0).toDouble();

      if (response['match'] == true) {
        result.value = AttendanceResult.success;
        successMessage.value = response['message'] ?? 'Attendance marked successfully!';
      } else {
        result.value = AttendanceResult.failed;
        errorMessage.value = response['message'] ?? 'Face not recognized. Please try again.';
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
      Get.offNamed(AppConstants.routeAttendanceSuccess);
    }
  }

  // ─── API: Verify Face + Mark Attendance ──────────────────
  /// Uses session_id from the deep link — the primary attendance method.
  Future<Map<String, dynamic>> _verifyAndMark(File imageFile) async {
    final classroom = selectedClassroom.value;
    final sessionId = deepLinkSessionId.value;

    if (sessionId == null) {
      throw Exception(
        'No session found. Please tap the WhatsApp attendance link first.',
      );
    }

    final formData = dio.FormData.fromMap({
      'file':       await dio.MultipartFile.fromFile(imageFile.path, filename: 'face.jpg'),
      'session_id': sessionId.toString(),
      'rssi':       (classroom?.rssi ?? capturedRssi.value).toString(),
    });

    final response = await _api.postMultipart('/attendance/mark', formData);
    return response.data as Map<String, dynamic>;
  }

  // ─── Fetch session info when deep link arrives ────────────
  Future<void> fetchSessionInfo(int sessionId) async {
    try {
      // We don't have a public session info endpoint, but verify is enough
      final formData = dio.FormData.fromMap({
        'session_id': sessionId.toString(),
        'rssi': '0', // initial check — RSSI validated later after BLE scan
      });
      final response = await _api.postMultipart('/attendance/verify', formData);
      final data = response.data as Map<String, dynamic>;
      if (data['eligible'] == true || data['step'] == 'duplicate') {
        deepLinkSessionSubject.value   = data['subject_name'] ?? '';
        deepLinkSessionClassroom.value = data['classroom_name'] ?? '';
        deepLinkClassroomUuid.value    = data['classroom_uuid'] ?? '';
      }
    } catch (_) {
      // Non-critical — BLE + face still enforced
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
