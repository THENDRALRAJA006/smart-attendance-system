// ============================================================
// SmartAttend — Attendance API Service (v4)
// Handles: session lookup, face mark (with liveness), attendance history,
//          faculty live-attendance, session creation
// v4: Added confidence tiers (present/manual_review/rejected),
//     liveness token forwarding, tiered AttendanceMarkResult
// ============================================================

import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';

// ─── Response Models ──────────────────────────────────────────

class AttendanceVerifyResult {
  final bool eligible;
  final String step;
  final String message;
  final int? sessionId;
  final String? classroomName;
  final String? subjectName;
  final int? rssi;

  AttendanceVerifyResult.fromJson(Map<String, dynamic> json)
      : eligible     = json['eligible'] ?? false,
        step         = json['step'] ?? '',
        message      = json['message'] ?? '',
        sessionId    = json['session_id'],
        classroomName = json['classroom_name'],
        subjectName  = json['subject_name'],
        rssi         = json['rssi'];
}

class AttendanceMarkResult {
  final bool match;
  final double confidence;
  final String message;
  final int? attendanceId;
  final String? time;
  final String? date;
  // v4: confidence tier + liveness
  final String tier;           // 'present' | 'manual_review' | 'rejected'
  final bool livenessVerified;
  final String? subjectName;
  final String? classroomName;
  final String? facultyName;

  AttendanceMarkResult.fromJson(Map<String, dynamic> json)
      : match            = json['match'] ?? false,
        confidence        = (json['confidence'] as num?)?.toDouble() ?? 0.0,
        message          = json['message'] ?? '',
        attendanceId     = json['attendance_id'],
        time             = json['time'],
        date             = json['date'],
        tier             = json['tier'] ?? 'present',
        livenessVerified = json['liveness_verified'] ?? false,
        subjectName      = json['subject_name'],
        classroomName    = json['classroom_name'],
        facultyName      = json['faculty_name'];

  /// Human-readable tier label for UI display
  String get tierLabel {
    switch (tier) {
      case 'present': return 'Verified Present ✅';
      case 'manual_review': return 'Pending Review ⚠️';
      case 'rejected': return 'Not Recognized ❌';
      default: return tier;
    }
  }

  bool get isFlagged => tier == 'manual_review';
}


class AttendanceRecord {
  final int id;
  final int studentId;
  final String? studentName;
  final int classroomId;
  final String? classroomName;
  final int subjectId;
  final String? subjectName;
  final String date;
  final String time;
  final String status;
  final int? rssi;
  final double? faceConfidence;

  AttendanceRecord.fromJson(Map<String, dynamic> json)
      : id            = json['id'],
        studentId     = json['student_id'],
        studentName   = json['student_name'],
        classroomId   = json['classroom_id'],
        classroomName = json['classroom_name'],
        subjectId     = json['subject_id'],
        subjectName   = json['subject_name'],
        date          = json['date'] ?? '',
        time          = json['time'] ?? '',
        status        = json['status'] ?? 'unknown',
        rssi          = json['rssi'],
        faceConfidence = (json['face_confidence'] as num?)?.toDouble();
}

class StudentDashboard {
  final int totalClasses;
  final int attendedClasses;
  final double attendancePercentage;
  final List<SubjectStats> subjectWise;
  final List<AttendanceRecord> recentHistory;

  StudentDashboard.fromJson(Map<String, dynamic> json)
      : totalClasses         = json['total_classes'] ?? 0,
        attendedClasses      = json['attended_classes'] ?? 0,
        attendancePercentage = (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
        subjectWise          = (json['subject_wise'] as List? ?? [])
            .map((e) => SubjectStats.fromJson(e))
            .toList(),
        recentHistory        = (json['recent_history'] as List? ?? [])
            .map((e) => AttendanceRecord.fromJson(e))
            .toList();
}

class SubjectStats {
  final String subjectName;
  final String? subjectCode;
  final String? facultyName;
  final int total;
  final int attended;
  final double percentage;

  SubjectStats.fromJson(Map<String, dynamic> json)
      : subjectName = json['subject_name'] ?? '',
        subjectCode = json['subject_code'],
        facultyName = json['faculty_name'],
        total       = json['total'] ?? 0,
        attended    = json['attended'] ?? 0,
        percentage  = (json['percentage'] as num?)?.toDouble() ?? 0.0;
}

class FaceRegisterResult {
  final String message;
  final String faceId;
  final String s3Url;

  FaceRegisterResult.fromJson(Map<String, dynamic> json)
      : message = json['message'] ?? '',
        faceId  = json['face_id'] ?? '',
        s3Url   = json['s3_url'] ?? '';
}

class SessionInfo {
  final int id;
  final int classroomId;
  final String classroomName;
  final int subjectId;
  final String subjectName;
  final String startTime;
  final String? endTime;
  final bool isActive;
  final String? deepLink;
  final String? webLink;
  final String? whatsappUrl;

  SessionInfo.fromJson(Map<String, dynamic> json)
      : id           = json['id'],
        classroomId  = json['classroom_id'],
        classroomName = json['classroom_name'] ?? '',
        subjectId    = json['subject_id'],
        subjectName  = json['subject_name'] ?? '',
        startTime    = json['start_time'] ?? '',
        endTime      = json['end_time'],
        isActive     = json['is_active'] ?? false,
        deepLink     = json['deep_link'],
        webLink      = json['web_link'],
        whatsappUrl  = json['whatsapp_url'];
}

class LiveAttendanceData {
  final int? sessionId;
  final bool isActive;
  final String? startTime;
  final int attendanceCount;
  final List<LiveStudent> students;

  LiveAttendanceData.fromJson(Map<String, dynamic> json)
      : sessionId       = json['session_id'],
        isActive        = json['is_active'] ?? false,
        startTime       = json['start_time'],
        attendanceCount = json['attendance_count'] ?? 0,
        students        = (json['students'] as List? ?? [])
            .map((e) => LiveStudent.fromJson(e))
            .toList();
}

class LiveStudent {
  final int studentId;
  final String studentName;
  final String regNo;
  final String time;
  final int? rssi;
  final double? faceConfidence;
  final String status;

  LiveStudent.fromJson(Map<String, dynamic> json)
      : studentId      = json['student_id'],
        studentName    = json['student_name'] ?? '',
        regNo          = json['reg_no'] ?? '',
        time           = json['time'] ?? '',
        rssi           = json['rssi'],
        faceConfidence = (json['face_confidence'] as num?)?.toDouble(),
        status         = json['status'] ?? 'present';
}

// ─── Attendance API Service ───────────────────────────────────

class AttendanceApiService {
  final ApiClient _api;

  AttendanceApiService() : _api = ApiClient.to;

  // ════════════════════════════════════════════════════════════
  // STUDENT — Dashboard & History
  // ════════════════════════════════════════════════════════════

  /// Fetch student dashboard analytics.
  Future<StudentDashboard> getStudentDashboard() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        AppConstants.endpointStudentDashboard,
      );
      return StudentDashboard.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Fetch attendance history filtered by period (daily/weekly/monthly).
  Future<List<AttendanceRecord>> getAttendanceHistory({
    String period = 'monthly',
  }) async {
    try {
      final res = await _api.get<List<dynamic>>(
        AppConstants.endpointAttendanceHistory,
        queryParameters: {'period': period},
      );
      return (res.data ?? [])
          .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ════════════════════════════════════════════════════════════
  // STUDENT — Attendance Marking (BLE + Face Flow)
  // ════════════════════════════════════════════════════════════

  /// Step 1 (pre-check): Validate BLE range and eligibility.
  /// Does NOT mark attendance — call this before face verification.
  Future<AttendanceVerifyResult> verifyAttendance({
    required int sessionId,
    required int rssi,
  }) async {
    try {
      final formData = FormData.fromMap({
        'session_id': sessionId,
        'rssi':       rssi,
      });
      final res = await _api.postMultipart<Map<String, dynamic>>(
        AppConstants.endpointAttendanceVerify,
        formData,
      );
      return AttendanceVerifyResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Step 2 (mark): Upload selfie + session info to mark attendance.
  /// Requires face registered and BLE in range.
  Future<AttendanceMarkResult> markAttendance({
    required int sessionId,
    required int rssi,
    required File faceImage,
  }) async {
    try {
      final formData = FormData.fromMap({
        'session_id': sessionId,
        'rssi':       rssi,
        'file': await MultipartFile.fromFile(
          faceImage.path,
          filename: 'face.jpg',
        ),
      });
      final res = await _api.postMultipart<Map<String, dynamic>>(
        AppConstants.endpointAttendanceMark,
        formData,
      );
      return AttendanceMarkResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // v4: Mark attendance WITH liveness token (anti-spoofing)
  /// Submit face photo and optional liveness token to mark attendance.
  /// liveness_token: from GET /auth/liveness-challenge, after successful verify.
  Future<AttendanceMarkResult> markAttendanceWithLiveness({
    required int sessionId,
    required int rssi,
    required File faceImage,
    String? livenessToken,       // null = liveness skipped
  }) async {
    try {
      final fields = <String, dynamic>{
        'session_id': sessionId,
        'rssi':       rssi,
        'file': await MultipartFile.fromFile(
          faceImage.path,
          filename: 'face.jpg',
        ),
      };
      if (livenessToken != null && livenessToken.isNotEmpty) {
        fields['liveness_token'] = livenessToken;
      }
      final formData = FormData.fromMap(fields);
      final res = await _api.postMultipart<Map<String, dynamic>>(
        AppConstants.endpointAttendanceMark,
        formData,
      );
      return AttendanceMarkResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ════════════════════════════════════════════════════════════
  // STUDENT — Face Registration & Verification
  // ════════════════════════════════════════════════════════════

  /// Register student's face using ArcFace (InsightFace) embeddings.
  /// Sends image to POST /auth/face-register. Stores embedding in DB.
  Future<FaceRegisterResult> registerFace(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'face.jpg',
        ),
      });
      final res = await _api.postMultipart<Map<String, dynamic>>(
        AppConstants.endpointFaceRegister,
        formData,
      );
      return FaceRegisterResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Standalone face verification (test without marking attendance).
  Future<Map<String, dynamic>> verifyFaceStandalone(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'face.jpg',
        ),
      });
      final res = await _api.postMultipart<Map<String, dynamic>>(
        AppConstants.endpointFaceVerify,
        formData,
      );
      return res.data!;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ════════════════════════════════════════════════════════════
  // FACULTY — Session Management
  // ════════════════════════════════════════════════════════════

  /// Create a new attendance session (faculty only).
  Future<SessionInfo> createSession({
    required int classroomId,
    required int subjectId,
    required String attendanceCode, // 6-digit
  }) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        AppConstants.endpointCreateSession,
        data: {
          'classroom_id':    classroomId,
          'subject_id':      subjectId,
          'attendance_code': attendanceCode,
        },
      );
      return SessionInfo.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// End an active session.
  Future<void> endSession(int sessionId) async {
    try {
      await _api.put<Map<String, dynamic>>(
        '${AppConstants.endpointEndSession}/$sessionId',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get or refresh WhatsApp attendance link for a session.
  Future<Map<String, dynamic>> getWhatsappLink(int sessionId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        AppConstants.endpointWhatsappLink,
        queryParameters: {'session_id': sessionId},
      );
      return res.data!;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get live attendance for an active session.
  Future<LiveAttendanceData> getLiveAttendance({int? sessionId}) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        AppConstants.endpointLiveAttendance,
        queryParameters: sessionId != null ? {'session_id': sessionId} : null,
      );
      return LiveAttendanceData.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get attendance report for faculty (daily/weekly/monthly).
  Future<List<Map<String, dynamic>>> getAttendanceReport({
    String period = 'weekly',
    int? sessionId,
    int? subjectId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'period': period};
      if (sessionId != null) queryParams['session_id'] = sessionId;
      if (subjectId != null) queryParams['subject_id'] = subjectId;

      final res = await _api.get<List<dynamic>>(
        AppConstants.endpointAttendanceReport,
        queryParameters: queryParams,
      );
      return (res.data ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ════════════════════════════════════════════════════════════
  // COMPLETE FACE-ATTENDANCE WORKFLOW
  // ════════════════════════════════════════════════════════════

  /// v4: Full attendance workflow: liveness → verify → capture face → mark.
  ///
  /// If livenessToken provided, it is forwarded to the mark endpoint.
  /// Confidence tiers:
  ///   >= 95%  → present (auto-marked)
  ///   90-95%  → manual_review (marked, flagged for faculty)
  ///   < 90%   → rejected
  ///
  /// Usage:
  /// ```dart
  /// final result = await attendanceService.completeAttendanceFlow(
  ///   sessionId: sessionId,
  ///   rssi: bleRssi,
  ///   faceImage: capturedImage,
  ///   livenessToken: authController.liveChallengeToken.value,
  ///   onStep: (step) => setState(() => currentStep = step),
  /// );
  /// ```
  Future<AttendanceMarkResult> completeAttendanceFlow({
    required int sessionId,
    required int rssi,
    required File faceImage,
    String? livenessToken,
    void Function(String step)? onStep,
  }) async {
    // Step 1: Pre-check (BLE range + eligibility)
    onStep?.call('Verifying eligibility...');
    final preCheck = await verifyAttendance(
      sessionId: sessionId,
      rssi: rssi,
    );

    if (!preCheck.eligible) {
      throw ApiException(message: preCheck.message);
    }

    // Step 2: Mark attendance with face photo + liveness token
    onStep?.call('Verifying face...');
    final result = await markAttendanceWithLiveness(
      sessionId: sessionId,
      rssi: rssi,
      faceImage: faceImage,
      livenessToken: livenessToken,
    );

    // Handle tiers
    if (result.tier == 'rejected') {
      throw ApiException(
        message: result.message.isNotEmpty
            ? result.message
            : 'Face verification failed. Please try again.',
      );
    }

    onStep?.call(result.tier == 'manual_review'
        ? 'Attendance flagged for review.'
        : 'Attendance marked!');
    return result;
  }
}
