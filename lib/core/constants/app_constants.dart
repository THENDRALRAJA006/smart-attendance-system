// ============================================================
// SmartAttend — App Constants (Enterprise v2)
// BLE threshold: -80 dBm, RSSI averaging, new routes
// ============================================================

import '../../config/api_config.dart';

class AppConstants {
  // ─── API ────────────────────────────────────────────────
  static const String baseUrl = ApiConfig.baseUrl;

  static const int connectTimeout = 60;  // seconds
  static const int receiveTimeout = 120; // seconds

  // ─── JWT ────────────────────────────────────────────────
  static const String tokenKey       = 'smart_attend_jwt';
  static const String refreshTokenKey = 'smart_attend_refresh_jwt';
  static const String userRoleKey    = 'smart_attend_role';
  static const String userIdKey      = 'smart_attend_user_id';

  // ─── BLE (Enterprise v2) ────────────────────────────────
  /// -80 dBm provides ~10m classroom detection range
  static const int    rssiThreshold   = -80;
  /// Number of readings to average for stable RSSI
  static const int    rssiWindowSize  = 5;
  /// Seconds a device must be continuously detected before appearing in list
  static const int    rssiStableMs    = 800;
  /// Seconds to ignore same device after first detection (anti-duplicate)
  static const int    bleCooldownSec  = 5;
  static const int    bleScanDuration = 12; // seconds
  static const String bleServicePrefix = 'SMART_ATTEND';

  // ─── Face Recognition (ArcFace) ─────────────────────────
  static const double arcFaceSimilarityThreshold = 0.75;
  static const double arcFaceReviewThreshold      = 0.65;
  static const int    maxFaceCaptureAttempts       = 3;

  // ─── Liveness ────────────────────────────────────────────
  static const int maxLivenessAttempts = 3;
  static const int livenessTimeoutSec  = 12;

  // ─── Session ────────────────────────────────────────────
  static const int attendanceCodeLength = 6;

  // ─── Routes ─────────────────────────────────────────────
  static const String routeSplash               = '/';
  static const String routeLogin                = '/login';
  static const String routeRegister             = '/register';
  static const String routeForgotPassword       = '/forgot-password';
  static const String routeResetPassword        = '/reset-password';
  static const String routeFaceRegister         = '/face-register';
  static const String routeStudentDashboard     = '/student/dashboard';
  static const String routeClassroomDetection   = '/student/classroom';
  static const String routeVerificationMethod   = '/student/verify-method';
  static const String routeAttendanceVerification = '/student/verify';
  static const String routeQrVerification       = '/student/qr-verify';
  static const String routeLivenessChallenge    = '/student/liveness';
  static const String routeAttendanceResult     = '/student/result';
  static const String routeAttendanceHistory    = '/student/history';
  static const String routeReports              = '/student/reports';
  static const String routeQrScanner            = '/student/qr-verify';
  static const String routeProfile              = '/profile';
  static const String routeFacultyDashboard     = '/faculty/dashboard';
  static const String routeQrGenerator         = '/faculty/qr-generate';
  static const String routeAdminDashboard       = '/admin/dashboard';

  // ─── Teacher Session Module (v10) ───────────────────────
  static const String routeTeacherDashboard   = '/teacher/dashboard';
  static const String routeStartSession       = '/teacher/start-session';
  static const String routeActiveSession      = '/teacher/active-session';
  static const String routeSessionHistory     = '/teacher/session-history';
  static const String routeSessionSummary     = '/teacher/session-summary';

  // ─── Student Analytics Module (v11) ─────────────────────
  static const String routeSubjectDetail      = '/student/subject-detail';
  static const String routeMissedClasses      = '/student/missed';
  static const String routeSemesterAnalytics  = '/student/analytics';

  // ─── ERP Academic Management Module (v13) ───────────────
  static const String routeAcademicManagement = '/admin/academic';
  static const String routeErpDepartments     = '/admin/academic/departments';
  static const String routeErpSubjects        = '/admin/academic/subjects';
  static const String routeErpFaculty         = '/admin/academic/faculty';
  static const String routeErpClassrooms      = '/admin/academic/classrooms';
  static const String routePeriodTimings      = '/admin/academic/period-timings';
  static const String routeTimetableEditor    = '/admin/academic/timetable-editor';
  static const String routeAdminTimetable     = '/admin/timetable';
  static const String routeStudentTimetable   = '/student/timetable';
  static const String routeTeacherTimetable   = '/teacher/timetable';
  static const String routeChangePassword     = '/change-password';

  // ─── Storage Keys ───────────────────────────────────────
  static const String storedUserKey = 'stored_user_data';

  // ─── Year options (used by start session auto-fill) ─────
  static const List<int> yearOptions = [1, 2, 3, 4];

  // ─── API Endpoints ──────────────────────────────────────
  // Auth
  static const String endpointRegister         = '/auth/register';
  static const String endpointLogin            = '/auth/login';
  static const String endpointRefreshToken     = '/auth/refresh';
  static const String endpointMe               = '/auth/me';
  static const String endpointFaceRegister     = '/auth/face-register';
  static const String endpointFaceRegisterAuto = '/auth/face-register-auto';
  static const String endpointFaceVerify       = '/auth/face-verify';
  static const String endpointForgotPassword   = '/auth/forgot-password';
  static const String endpointResetPassword    = '/auth/reset-password';
  static const String endpointChangePassword   = '/auth/change-password';

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

  // ERP Timetable (v13)
  static const String apiErpDepartments        = '/api/erp/departments';
  static const String apiErpSubjects           = '/api/erp/subjects';
  static const String apiErpFaculty            = '/api/erp/faculty';
  static const String apiErpClassrooms         = '/api/erp/classrooms';
  static const String apiErpPeriodTimings      = '/api/erp/period-timings';
  static const String apiErpTimetable          = '/api/erp/timetable';
  static const String apiErpTimetableStudent   = '/api/erp/timetable/student';
  static const String apiErpTimetableTeacher   = '/api/erp/timetable/teacher';
  static const String apiErpCurrentPeriod      = '/api/erp/timetable/current-period';

  // ─── Signal Strength Labels (updated for -80 range) ─────
  static String rssiLabel(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -65) return 'Good';
    if (rssi >= -75) return 'Acceptable';
    if (rssi >= -80) return 'Weak';
    return 'Out of Range';
  }

  static int rssiStrength(int rssi) {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -72) return 2;
    if (rssi >= -80) return 1;
    return 0;
  }

  // ─── Departments & Sections Lists (Up to G + Custom) ───────
  static const List<String> defaultDepartments = [
    'Computer Science and Engineering',
    'Artificial Intelligence and Machine Learning',
    'Artificial Intelligence and Data Science',
    'Information Technology',
    'Electronics and Communication Engineering',
    'Electrical and Electronics Engineering',
    'Mechanical Engineering',
    'Civil Engineering',
    'Biomedical Engineering',
    'Chemical Engineering',
    'Aerospace Engineering',
    'Custom Department',
  ];

  static const List<String> defaultSections = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'Custom Section',
  ];
}
