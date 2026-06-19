// ============================================================
// SmartAttend — App Constants
// ============================================================

class AppConstants {
  // ─── API ────────────────────────────────────────────────
  static const String baseUrl = 'https://enviably-mutable-uptake.ngrok-free.dev';

  static const int connectTimeout = 30; // seconds
  static const int receiveTimeout = 30;

  // ─── JWT ────────────────────────────────────────────────
  static const String tokenKey = 'smart_attend_jwt';
  static const String userRoleKey = 'smart_attend_role';
  static const String userIdKey = 'smart_attend_user_id';

  // ─── BLE ────────────────────────────────────────────────
  static const int rssiThreshold = -70; // dBm — must be > -70 to mark attendance
  static const int bleScanDuration = 10; // seconds
  static const String bleServicePrefix = 'SMART_ATTEND'; // beacons start with this

  // ─── Face Recognition ───────────────────────────────────
  static const double faceConfidenceThreshold = 90.0; // AWS Rekognition min %
  static const int maxFaceCaptureAttempts = 3;

  // ─── Session ────────────────────────────────────────────
  static const int attendanceCodeLength = 6;

  // ─── Routes ─────────────────────────────────────────────
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeFaceRegister = '/face-register';
  static const String routeStudentDashboard = '/student/dashboard';
  static const String routeClassroomDetection = '/student/classroom';
  static const String routeAttendanceVerification = '/student/verify';
  static const String routeAttendanceSuccess = '/student/success';
  static const String routeAttendanceHistory = '/student/history';
  static const String routeFacultyDashboard = '/faculty/dashboard';
  static const String routeAdminDashboard = '/admin/dashboard';

  // ─── Storage Keys ───────────────────────────────────────
  static const String storedUserKey = 'stored_user_data';

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
