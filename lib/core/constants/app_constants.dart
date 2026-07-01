// ============================================================
// SmartAttend — App Constants
// ============================================================

import '../../config/api_config.dart';

class AppConstants {
  // ─── API ────────────────────────────────────────────────
  // Centralized URL from ApiConfig
  static const String baseUrl = ApiConfig.baseUrl;

  static const int connectTimeout = 60;  // seconds
  static const int receiveTimeout = 120; // seconds — extended for InsightFace inference & Render cold starts

  // ─── JWT ────────────────────────────────────────────────
  static const String tokenKey       = 'smart_attend_jwt';
  static const String refreshTokenKey = 'smart_attend_refresh_jwt';
  static const String userRoleKey    = 'smart_attend_role';
  static const String userIdKey      = 'smart_attend_user_id';

  // ─── BLE ────────────────────────────────────────────────
  static const int    rssiThreshold  = -70; // dBm — must be > -70 to mark attendance
  static const int    bleScanDuration = 10; // seconds
  static const String bleServicePrefix = 'SMART_ATTEND'; // beacons start with this

  // ─── Face Recognition (ArcFace) ─────────────────────────
  /// Cosine similarity thresholds (0.0–1.0 scale)
  static const double arcFaceSimilarityThreshold = 0.75; // >= 0.75 → present
  static const double arcFaceReviewThreshold      = 0.65; // 0.65–0.74 → manual_review; < 0.65 → rejected
  static const int    maxFaceCaptureAttempts       = 3;

  // ─── Session ────────────────────────────────────────────
  static const int attendanceCodeLength = 6;

  // ─── Routes ─────────────────────────────────────────────
  static const String routeSplash               = '/';
  static const String routeLogin                = '/login';
  static const String routeRegister             = '/register';
  static const String routeFaceRegister         = '/face-register';
  static const String routeStudentDashboard     = '/student/dashboard';
  static const String routeClassroomDetection   = '/student/classroom';
  static const String routeVerificationMethod   = '/student/verify-method';
  static const String routeAttendanceVerification = '/student/verify';
  static const String routeQrVerification       = '/student/qr-verify';
  static const String routeAttendanceResult     = '/student/result';
  static const String routeAttendanceHistory    = '/student/history';
  static const String routeReports              = '/student/reports';
  static const String routeQrScanner            = '/student/qr-verify'; // alias
  static const String routeProfile              = '/profile';
  static const String routeFacultyDashboard     = '/faculty/dashboard';
  static const String routeQrGenerator         = '/faculty/qr-generate';
  static const String routeAdminDashboard       = '/admin/dashboard';

  // ─── Storage Keys ───────────────────────────────────────
  static const String storedUserKey = 'stored_user_data';

  // ─── API Endpoints ──────────────────────────────────────
  // Auth
  static const String endpointRegister     = '/auth/register';
  static const String endpointLogin        = '/auth/login';
  static const String endpointRefreshToken = '/auth/refresh';
  static const String endpointMe           = '/auth/me';
  static const String endpointFaceRegister     = '/auth/face-register';
  static const String endpointFaceRegisterAuto = '/auth/face-register-auto'; // v5: batch auto-capture
  static const String endpointFaceVerify       = '/auth/face-verify';

  // Student
  static const String endpointStudentDashboard  = '/student/dashboard';
  static const String endpointAttendanceHistory = '/student/attendance-history';
  static const String endpointAttendanceVerify       = '/attendance/verify';
  static const String endpointAttendanceMark         = '/attendance/mark';
  static const String endpointAttendanceMarkQr       = '/attendance/mark-qr';
  static const String endpointCheckActiveSession     = '/attendance/check-active-session';
  static const String endpointSessionStatus          = '/attendance/session-status';
  static const String endpointValidateQr             = '/attendance/validate-qr';

  // Faculty
  static const String endpointFacultyDashboard  = '/faculty/dashboard';
  static const String endpointCreateSession     = '/faculty/create-session';
  static const String endpointEndSession        = '/faculty/end-session';
  static const String endpointWhatsappLink      = '/faculty/whatsapp-link';
  static const String endpointLiveAttendance    = '/faculty/live-attendance';
  static const String endpointAttendanceReport  = '/faculty/attendance-report';
  static const String endpointGenerateQr       = '/faculty/generate-qr';
  static const String endpointDownloadQr        = '/faculty/download-qr';

  // Admin
  static const String endpointAdminDashboard    = '/admin/dashboard';
  static const String endpointAdminStudents     = '/admin/students';
  static const String endpointAdminFaculty      = '/admin/faculty';
  static const String endpointAdminClassrooms   = '/admin/classrooms';
  static const String endpointAdminSubjects     = '/admin/subjects';
  static const String endpointAdminAnalytics    = '/admin/analytics';
  static const String endpointAdminBleBeacons   = '/admin/ble-beacons';

  // ─── Signal Strength Labels ─────────────────────────────
  static String rssiLabel(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -65) return 'Good';
    if (rssi >= -70) return 'Acceptable';
    return 'Out of Range';
  }

  static int rssiStrength(int rssi) {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -70) return 2;
    if (rssi >= -80) return 1;
    return 0;
  }
}
