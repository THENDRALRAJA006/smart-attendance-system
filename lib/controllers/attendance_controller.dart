// ============================================================
// SmartAttend — Attendance Controller (Enterprise v2)
// New workflow: BLE → QR → Liveness → Face → Done
//
// v2 changes:
//  - New guard flags: bleVerified, qrVerified, livenessVerified
//  - verifyFace() BLOCKED until all guards are true
//  - QR step added between BLE and face
//  - Liveness is now mandatory (not optional)
//  - Attendance details stored for success page display
//  - Session polling preserved and enhanced
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
import '../core/services/device_service.dart';

enum AttendanceStep {
  idle,
  bleScanning,
  bleDone,
  qrScan,       // NEW: QR verification step
  liveness,     // NEW: Mandatory liveness step
  faceCapture,
  verifying,
  done,
}

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

// ─── Attendance Details Model (for success page) ─────────────
class AttendanceDetails {
  final String studentName;
  final String registerNo;
  final String department;
  final String subjectName;
  final String classroomName;
  final String facultyName;
  final String markedAt;
  final double confidenceScore;
  final int? attendanceId;
  final String? photoUrl;

  const AttendanceDetails({
    required this.studentName,
    required this.registerNo,
    required this.department,
    required this.subjectName,
    required this.classroomName,
    required this.facultyName,
    required this.markedAt,
    required this.confidenceScore,
    this.attendanceId,
    this.photoUrl,
  });

  factory AttendanceDetails.fromJson(Map<String, dynamic> json, {double confidence = 0.0}) {
    // Backend nests receipt details under 'details' key (v2)
    // Fall back to top-level keys for older backend versions
    final d = json['details'] as Map<String, dynamic>? ?? json;

    return AttendanceDetails(
      studentName:   d['studentName']    as String? ?? d['student_name']    as String? ?? '',
      registerNo:    d['registerNo']      as String? ?? d['reg_no']           as String? ?? '',
      department:    d['department']      as String? ?? '',
      subjectName:   d['subjectName']     as String? ?? d['subject_name']    as String? ?? '',
      classroomName: d['classroomName']   as String? ?? d['classroom_name']  as String? ?? '',
      facultyName:   d['facultyName']     as String? ?? d['faculty_name']    as String? ?? '',
      markedAt:      d['markedAt']        as String? ?? d['marked_at']       as String? ?? DateTime.now().toIso8601String(),
      confidenceScore: confidence,
      attendanceId:  d['attendanceId']    as int?    ?? d['attendance_id']   as int?,
      photoUrl:      d['photoUrl']        as String? ?? d['photo_url']       as String?,
    );
  }
}

class AttendanceController extends GetxController {
  static AttendanceController get to => Get.find();

  ApiClient get _api => ApiClient.to;

  // ─── Verification Guard Flags (Enterprise v2) ─────────────
  final RxBool bleVerified      = false.obs;
  final RxBool qrVerified       = false.obs;
  final RxBool livenessVerified = false.obs;

  // ─── Scanned QR token (must be forwarded to mark-qr API) ──
  String? _lastScannedQrToken;

  // ─── State ──────────────────────────────────────────────
  final Rx<AttendanceStep>    step              = AttendanceStep.idle.obs;
  final Rx<AttendanceResult>  result            = AttendanceResult.none.obs;
  final Rx<DetectedClassroom?> selectedClassroom = Rx<DetectedClassroom?>(null);
  final RxBool  isLoading          = false.obs;
  final RxString errorMessage      = ''.obs;
  final RxString error             = ''.obs;
  final RxString successMessage    = ''.obs;
  final RxDouble confidenceScore   = 0.0.obs;
  final RxInt    capturedRssi      = 0.obs;
  final RxBool   hasDuplicateError = false.obs;

  // ─── Attendance Details (for success page) ────────────────
  final Rx<AttendanceDetails?> attendanceDetails = Rx<AttendanceDetails?>(null);

  // ─── Active Session (Dashboard) ──────────────────────────
  final Rx<ActiveSessionInfo?> activeSession = Rx<ActiveSessionInfo?>(null);
  final RxBool isCheckingSession = false.obs;

  bool get hasActiveSession => activeSession.value != null;
  bool get alreadyMarked    => activeSession.value?.alreadyMarked ?? false;

  // ─── Session Polling ─────────────────────────────────────
  Timer? _sessionPollTimer;

  void startSessionPolling({int intervalSeconds = 30}) {
    _sessionPollTimer?.cancel();
    checkActiveSession();
    _sessionPollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => checkActiveSession(),
    );
    dev.log('[POLL] Session polling started — interval=${intervalSeconds}s', name: 'AttendanceController');
  }

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
  Future<void> checkActiveSession() async {
    isCheckingSession.value = true;
    try {
      final response = await _api.get(AppConstants.endpointCheckActiveSession);
      final data = response.data as Map<String, dynamic>;

      if (data['is_active'] == true) {
        activeSession.value = ActiveSessionInfo.fromJson(data);
        dev.log('[SESSION_CHECK] Active: id=${data['session_id']}', name: 'AttendanceController');
      } else {
        activeSession.value = null;
      }
    } on dio.DioException catch (e) {
      final err = ApiException.fromDioError(e);
      dev.log('[SESSION_CHECK] Error: ${err.message}', name: 'AttendanceController');
      activeSession.value = null;
    } catch (e) {
      activeSession.value = null;
    } finally {
      isCheckingSession.value = false;
    }
  }

  // ─── Lightweight Session Status Polling ──────────────────
  Future<void> refreshSessionStatus() async {
    try {
      final response = await _api.get(AppConstants.endpointSessionStatus);
      final data = response.data as Map<String, dynamic>;
      if (data['is_active'] == true && activeSession.value != null) {
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
    } catch (_) {}
  }

  // ─── Set Deep Link Context ───────────────────────────────
  /// Updates session context WITHOUT resetting verification guards.
  /// Call reset() explicitly before starting a fresh attendance flow.
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
    // NOTE: deliberately does NOT call reset() so BLE/QR verified flags are preserved
  }

  // ─── Step 1: Pre-verify session ──────────────────────────
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
    bleVerified.value = false;

    try {
      await BleService.to.startScan();
      step.value = AttendanceStep.bleDone;
    } catch (e) {
      errorMessage.value = 'BLE scan failed: ${e.toString()}';
      step.value = AttendanceStep.idle;
    }
  }

  // ─── Classroom Matches Helper ─────────────────────────────
  // ignore: unused_element
  bool _classroomMatches(DetectedClassroom classroom, String expectedUuid, String expectedName) {
    String clean(String s) =>
        s.toUpperCase().replaceAll(':', '').replaceAll('-', '').replaceAll('_', '').replaceAll(' ', '');

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

  // ─── Step 3: Select Classroom → Auto-advance to QR ────────
  Future<void> selectClassroom(DetectedClassroom classroom) async {
    dev.log('[CLASSROOM] Selected: name=${classroom.name}, rssi=${classroom.rssi}', name: 'AttendanceController');

    if (!classroom.isInRange) {
      result.value = AttendanceResult.outOfRange;
      errorMessage.value = 'You are out of classroom range. Move closer to the beacon.';
      Get.toNamed(AppConstants.routeAttendanceResult);
      return;
    }

    // Fast-path 1: use activeSession if already populated
    if (deepLinkSessionId.value == null && activeSession.value != null) {
      final session = activeSession.value!;
      setDeepLinkContext(
        sessionId: session.sessionId,
        subjectName: session.subjectName,
        classroomName: session.classroomName,
        classroomUuid: session.classroomUuid,
      );
    }

    // Fast-path 2: force-refresh if still null
    if (deepLinkSessionId.value == null) {
      await checkActiveSession();
      if (activeSession.value != null) {
        final session = activeSession.value!;
        setDeepLinkContext(
          sessionId: session.sessionId,
          subjectName: session.subjectName,
          classroomName: session.classroomName,
          classroomUuid: session.classroomUuid,
        );
      }
    }

    // Fallback API lookup by BLE UUID
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
          errorMessage.value = 'No active attendance session found. Ask your faculty to start the session.';
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
      } finally {
        isLoading.value = false;
      }
    }

    selectedClassroom.value = classroom;
    capturedRssi.value = classroom.rssi;

    // ── BLE verified — mark flag ──────────────────────────
    bleVerified.value = true;
    step.value = AttendanceStep.bleDone;

    dev.log('[BLE] ✅ BLE verified, navigating to method selection', name: 'AttendanceController');

    // Navigate to method selection — student chooses Face OR QR
    Get.toNamed(AppConstants.routeVerificationMethod);
  }

  // ─── QR Token Validation ─────────────────────────────────
  Future<bool> validateQrToken(String qrToken) async {
    isLoading.value = true;
    error.value = '';
    errorMessage.value = '';
    hasDuplicateError.value = false;
    qrVerified.value = false;

    // Local decode for speed
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
      final response = await _api.post(
        AppConstants.endpointValidateQr,
        data: {'qr_token': qrToken},
      );
      final data = response.data as Map<String, dynamic>;

      if (data['valid'] == true) {
        final sessionId = data['session_id'] as int;

        // ── Preserve BLE state before context update ───────
        final savedBleVerified = bleVerified.value;
        final savedRssi        = capturedRssi.value;
        final savedClassroom   = selectedClassroom.value;

        setDeepLinkContext(
          sessionId: sessionId,
          subjectName: data['subject_name'] as String?,
          classroomName: data['classroom_name'] as String?,
          classroomUuid: data['classroom_uuid'] as String?,
        );

        // ── Restore BLE state (setDeepLinkContext does NOT wipe these) ─
        bleVerified.value       = savedBleVerified;
        capturedRssi.value      = savedRssi;
        selectedClassroom.value  = savedClassroom;
        qrVerified.value        = true;
        _lastScannedQrToken     = qrToken; // ← Store token for markAttendanceQr()
        // QR path: step stays at qrScan — QR screen calls markAttendanceQr() directly
        // Do NOT set liveness or face steps here
        step.value = AttendanceStep.qrScan;

        dev.log('[QR_VALIDATE] ✅ QR verified, session=$sessionId bleVerified=$savedBleVerified', name: 'AttendanceController');
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

  // ─── Mark Liveness Verified ───────────────────────────────
  void markLivenessVerified({String? token}) {
    livenessVerified.value = true;
    step.value = AttendanceStep.faceCapture;
    dev.log('[LIVENESS] ✅ Liveness verified', name: 'AttendanceController');
  }

  // ─── Step 4: Verify Face (BLOCKED until guards pass) ──────
  Future<void> verifyFace({
    required File imageFile,
    String? livenessToken,
    String attendanceMethodHint = 'ble_face',
  }) async {
    // Guard 1: BLE always required
    if (!bleVerified.value) {
      errorMessage.value = 'BLE not verified. Please restart attendance.';
      result.value = AttendanceResult.failed;
      step.value = AttendanceStep.done;
      Get.offNamed(AppConstants.routeAttendanceResult);
      return;
    }

    // Guard 2: Liveness always required for face path
    if (!livenessVerified.value) {
      errorMessage.value = 'Liveness check not complete. Please complete the liveness challenge.';
      result.value = AttendanceResult.failed;
      step.value = AttendanceStep.done;
      Get.offNamed(AppConstants.routeAttendanceResult);
      return;
    }

    step.value = AttendanceStep.verifying;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      dev.log('[VERIFY_FACE] Guards passed. session=${deepLinkSessionId.value}', name: 'AttendanceController');

      final classroom = selectedClassroom.value;
      final sessionId = deepLinkSessionId.value;

      if (sessionId == null) {
        throw Exception('No session found. Please start the attendance process again.');
      }

      // Collect Android device ID for session-scoped deduplication.
      // This prevents two students sharing the same phone in one class session.
      // Fully automatic — the student never sees or enters this.
      String? androidDeviceId;
      try {
        androidDeviceId = await DeviceService.to.getAndroidId();
      } catch (e) {
        dev.log('[VERIFY_FACE] Could not get device_id: $e', name: 'AttendanceController');
      }

      final formData = dio.FormData.fromMap({
        'file':       await dio.MultipartFile.fromFile(imageFile.path, filename: 'face.jpg'),
        'session_id': sessionId.toString(),
        'rssi':       (classroom?.rssi ?? capturedRssi.value).toString(),
        'attendance_method_hint': attendanceMethodHint,
        if (livenessToken != null && livenessToken.isNotEmpty)
          'liveness_token': livenessToken,
        if (androidDeviceId != null && androidDeviceId.isNotEmpty)
          'device_id': androidDeviceId,
      });

      final response = await _api.postMultipart('/attendance/mark', formData);
      final data = response.data as Map<String, dynamic>;

      dev.log(
        '[VERIFY_RESPONSE] tier=${data['tier']} confidence=${data['confidence']} time=${data['verification_time_s']}s',
        name: 'AttendanceController',
      );

      final tier       = data['tier'] as String? ?? 'present';
      final similarity = (data['confidence'] ?? data['similarity'] ?? 0.0) as num;
      confidenceScore.value = similarity.toDouble();

      if (tier == 'rejected') {
        result.value = AttendanceResult.failed;
        errorMessage.value = data['message'] ?? 'Face not recognized. Please try again.';
      } else {
        result.value = AttendanceResult.success;
        successMessage.value = data['message'] ?? (
          tier == 'manual_review'
              ? 'Attendance flagged for review ⚠️'
              : 'Attendance marked successfully! ✅'
        );
        attendanceDetails.value = AttendanceDetails.fromJson(data, confidence: similarity.toDouble());
        await checkActiveSession();
      }
    } on dio.DioException catch (e) {
      final err = ApiException.fromDioError(e);
      if (err.statusCode == 409) {
        result.value = AttendanceResult.alreadyMarked;
        errorMessage.value = 'Attendance already marked for this session.';
        hasDuplicateError.value = true;
      } else if (err.statusCode == 403) {
        // Session-scoped device deduplication rejection:
        // a different student already used this phone in this session.
        result.value = AttendanceResult.failed;
        errorMessage.value =
            'This device has already been used to mark attendance '
            'for this attendance session.';
        dev.log(
          '[VERIFY_FACE] Device reuse rejected by server (403)',
          name: 'AttendanceController',
        );
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


  Future<bool> markAttendanceViaQr(String qrToken) async {
    isLoading.value = true;
    error.value = '';
    try {
      final response = await _api.post('/attendance/mark-qr', data: {'qr_token': qrToken});
      final data = response.data as Map<String, dynamic>;
      return data['marked'] == true;
    } on dio.DioException catch (e) {
      error.value = ApiException.fromDioError(e).message;
      return false;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── New: markAttendanceQr (QR-only path, no face/liveness) ─
  /// Called after QR token is validated. Marks attendance directly
  /// via the /attendance/mark-qr endpoint and sets result/details
  /// for the result screen. QR path does not require face verification.
  Future<void> markAttendanceQr() async {
    isLoading.value = true;
    errorMessage.value = '';
    step.value = AttendanceStep.verifying;
    verificationMethod.value = VerificationMethod.qr;

    try {
      final sessionId = deepLinkSessionId.value;
      if (sessionId == null) {
        throw Exception('No session found. Please restart attendance.');
      }

      // qr_token is REQUIRED by the backend — must be the scanned token
      final qrToken = _lastScannedQrToken;
      if (qrToken == null || qrToken.isEmpty) {
        throw Exception('QR code not scanned. Please scan the classroom QR code first.');
      }

      dev.log('[QR_MARK] Sending session_id=$sessionId rssi=${capturedRssi.value} qr_token=${qrToken.substring(0, 20)}...', name: 'AttendanceController');

      final response = await _api.post('/attendance/mark-qr', data: {
        'session_id': sessionId,
        'qr_token':   qrToken,       // ← REQUIRED by backend
        'rssi':        capturedRssi.value,
      });
      final data = response.data as Map<String, dynamic>;

      result.value = AttendanceResult.success;
      successMessage.value = data['message'] ?? 'Attendance marked via QR! ✅';
      confidenceScore.value = 0.0; // No face confidence for QR

      // Build attendance details from response
      attendanceDetails.value = AttendanceDetails.fromJson(data, confidence: 0.0);

      await checkActiveSession();
      dev.log('[QR_MARK] ✅ Attendance marked via QR, session=$sessionId', name: 'AttendanceController');
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
      // Navigate to result screen after QR attendance attempt
      Get.offAllNamed(AppConstants.routeAttendanceResult);
    }
  }



  // ─── Fetch Session Info ──────────────────────────────────
  Future<void> fetchSessionInfo(int sessionId) async {
    errorMessage.value = '';
    try {
      final formData = dio.FormData.fromMap({'session_id': sessionId.toString(), 'rssi': '0'});
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
      errorMessage.value = ApiException.fromDioError(e).message;
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  // ─── Copy link to clipboard ──────────────────────────────
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
  /// Full reset — clears everything including BLE session.
  /// Only call this when starting a completely new attendance flow.
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
    bleVerified.value = false;
    qrVerified.value = false;
    livenessVerified.value = false;
    attendanceDetails.value = null;
    _lastScannedQrToken = null;  // ← clear stored QR token
  }

  /// Soft reset — clears verification flags but keeps BLE session alive.
  /// Call this when retrying verification without re-doing BLE scan.
  void resetVerificationOnly() {
    qrVerified.value = false;
    livenessVerified.value = false;
    error.value = '';
    errorMessage.value = '';
    hasDuplicateError.value = false;
    result.value = AttendanceResult.none;
    if (bleVerified.value) {
      // Keep step at bleDone so user can pick verification method again
      step.value = AttendanceStep.bleDone;
    }
    dev.log('[RESET] Verification-only reset, BLE session preserved', name: 'AttendanceController');
  }

  // ─── Clear deep link context ─────────────────────────────
  void clearDeepLinkContext() {
    deepLinkSessionId.value        = null;
    deepLinkSessionSubject.value   = '';
    deepLinkSessionClassroom.value = '';
    deepLinkClassroomUuid.value    = '';
    reset(); // Full reset only when clearing context
  }

  @override
  void onClose() {
    stopSessionPolling();
    super.onClose();
  }
}