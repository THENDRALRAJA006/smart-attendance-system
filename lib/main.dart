import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/services/ble_service.dart';
import 'core/services/camera_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/device_service.dart';
import 'core/services/device_provider.dart';
import 'core/services/offline_queue_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';

import 'controllers/admin_controller.dart';
import 'controllers/attendance_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/faculty_controller.dart';
import 'controllers/session_controller.dart';
import 'controllers/student_controller.dart';

import 'screens/admin/admin_shell.dart';
import 'screens/auth/face_registration_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/faculty/qr_generator_screen.dart';
import 'screens/faculty/start_session_screen.dart';
import 'screens/faculty/active_session_screen.dart';
import 'screens/faculty/session_history_screen.dart';
import 'screens/faculty/session_summary_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/student/attendance_history_screen.dart';
import 'screens/student/attendance_result_screen.dart';
import 'screens/student/attendance_verification_screen.dart';
import 'screens/student/classroom_detection_screen.dart';
import 'screens/student/liveness_challenge_screen.dart';
import 'screens/student/missed_classes_screen.dart';
import 'screens/student/qr_verification_screen.dart';
import 'screens/student/reports_screen.dart';
import 'screens/student/semester_analytics_screen.dart';
import 'screens/student/subject_detail_screen.dart';
import 'screens/student/verification_method_screen.dart';
import 'screens/admin/timetable/admin_timetable_screen.dart';
import 'screens/admin/academic/academic_management_screen.dart';
import 'screens/admin/academic/departments_screen.dart';
import 'screens/admin/academic/erp_subjects_screen.dart';
import 'screens/admin/academic/erp_faculty_screen.dart';
import 'screens/admin/academic/erp_classrooms_screen.dart';
import 'screens/admin/academic/period_timings_screen.dart';
import 'screens/admin/academic/timetable_editor_screen.dart';
import 'screens/student/student_timetable_screen.dart';
import 'screens/faculty/teacher_timetable_screen.dart';
import 'controllers/erp_controller.dart';
import 'screens/student/student_shell.dart';
import 'screens/faculty/teacher_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Global error handlers (prevent silent crashes) ──────
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformError: $error\n$stack');
    return true; // Prevent crash — error is handled
  };

  // Show error text in release mode instead of grey box
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1B1B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF5252)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 20),
                SizedBox(width: 8),
                Text('Widget Error',
                    style: TextStyle(
                        color: Color(0xFFFF5252),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              details.exceptionAsString(),
              style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 11),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF8FAFC),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ==========================================================
  // SERVICES — order matters (storage first, then others)
  // ==========================================================

  Get.put<StorageService>(
    StorageService(),
    permanent: true,
  );

  Get.put<ApiClient>(
    ApiClient(),
    permanent: true,
  );

  Get.put<ConnectivityService>(
    ConnectivityService(),
    permanent: true,
  );

  // Device Binding + Session-Scoped Dedup (v7 + v8)
  // Must come after StorageService and ApiClient.
  Get.put<DeviceService>(
    DeviceService(),
    permanent: true,
  );
  Get.put<DeviceProvider>(
    DeviceProvider(),
    permanent: true,
  );

  Get.put<BleService>(
    BleService(),
    permanent: true,
  );

  Get.put<CameraService>(
    CameraService(),
    permanent: true,
  );

  Get.put<DeepLinkService>(
    DeepLinkService(),
    permanent: true,
  );

  await Get.putAsync<OfflineQueueService>(
    () => OfflineQueueService().init(),
    permanent: true,
  );

  // ==========================================================
  // CONTROLLERS
  // ==========================================================

  Get.put<AuthController>(
    AuthController(),
    permanent: true,
  );

  Get.lazyPut<StudentController>(
    () => StudentController(),
    fenix: true,
  );

  Get.lazyPut<AttendanceController>(
    () => AttendanceController(),
    fenix: true,
  );

  Get.lazyPut<FacultyController>(
    () => FacultyController(),
    fenix: true,
  );

  Get.lazyPut<AdminController>(
    () => AdminController(),
    fenix: true,
  );

  Get.lazyPut<SessionController>(
    () => SessionController(),
    fenix: true,
  );

  // v13: ERP Timetable & Academic Management
  Get.lazyPut<ErpController>(
    () => ErpController(),
    fenix: true,
  );

  // Initialize deep links AFTER services are registered
  try {
    await Get.find<DeepLinkService>().init();
  } catch (e) {
    debugPrint('DeepLink init failed (non-fatal): $e');
  }

  runApp(const SmartAttendApp());
}

class SmartAttendApp extends StatelessWidget {
  const SmartAttendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SmartAttend',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,

      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),

      initialRoute: AppConstants.routeSplash,

      getPages: [
        GetPage(
          name: AppConstants.routeSplash,
          page: () => const SplashScreen(),
        ),
        GetPage(
          name: AppConstants.routeLogin,
          page: () => const LoginScreen(),
        ),
        GetPage(
          name: AppConstants.routeRegister,
          page: () => const RegisterScreen(),
        ),
        GetPage(
          name: AppConstants.routeForgotPassword,
          page: () => const ForgotPasswordScreen(),
        ),
        GetPage(
          name: AppConstants.routeResetPassword,
          page: () => const ResetPasswordScreen(),
        ),
        GetPage(
          name: AppConstants.routeChangePassword,
          page: () => const ChangePasswordScreen(),
        ),
        GetPage(
          name: AppConstants.routeFaceRegister,
          page: () => const FaceRegistrationScreen(),
        ),
        GetPage(
          name: AppConstants.routeStudentDashboard,
          page: () => const StudentShell(),
        ),
        GetPage(
          name: AppConstants.routeClassroomDetection,
          page: () => const ClassroomDetectionScreen(),
        ),
        GetPage(
          name: AppConstants.routeAttendanceVerification,
          page: () => const AttendanceVerificationScreen(),
        ),
        GetPage(
          name: AppConstants.routeAttendanceResult,
          page: () => const AttendanceResultScreen(),
        ),
        GetPage(
          name: AppConstants.routeAttendanceHistory,
          page: () => const AttendanceHistoryScreen(),
        ),
        GetPage(
          name: AppConstants.routeReports,
          page: () => const ReportsScreen(),
        ),
        GetPage(
          name: AppConstants.routeVerificationMethod,
          page: () => const VerificationMethodScreen(),
        ),
        GetPage(
          name: AppConstants.routeQrVerification,
          page: () => const QrVerificationScreen(),
        ),
        GetPage(
          name: AppConstants.routeLivenessChallenge,
          page: () => const LivenessChallengeScreen(),
        ),
        GetPage(
          name: AppConstants.routeProfile,
          page: () => const ProfileScreen(),
        ),
        GetPage(
          name: AppConstants.routeFacultyDashboard,
          page: () => const TeacherShell(),
        ),
        GetPage(
          name: AppConstants.routeQrGenerator,
          page: () => const QrGeneratorScreen(),
        ),
        GetPage(
          name: AppConstants.routeAdminDashboard,
          page: () => const AdminShell(),
        ),
        // ─── Teacher Session Module (v10) ────────────────────
        GetPage(
          name: AppConstants.routeTeacherDashboard,
          page: () => const TeacherShell(),
        ),
        GetPage(
          name: AppConstants.routeStartSession,
          page: () => const StartSessionScreen(),
        ),
        GetPage(
          name: AppConstants.routeActiveSession,
          page: () => const ActiveSessionScreen(),
        ),
        GetPage(
          name: AppConstants.routeSessionHistory,
          page: () => const SessionHistoryScreen(),
        ),
        GetPage(
          name: AppConstants.routeSessionSummary,
          page: () => const SessionSummaryScreen(),
        ),
        // ─── Student Analytics Module (v11) ─────────────────
        GetPage(
          name: AppConstants.routeSubjectDetail,
          page: () => const SubjectDetailScreen(),
        ),
        GetPage(
          name: AppConstants.routeMissedClasses,
          page: () => const MissedClassesScreen(),
        ),
        GetPage(
          name: AppConstants.routeSemesterAnalytics,
          page: () => const SemesterAnalyticsScreen(),
        ),
        // ─── ERP Academic & Timetable Module (v13) ────────────
        GetPage(
          name: AppConstants.routeAcademicManagement,
          page: () => const AcademicManagementScreen(),
        ),
        GetPage(
          name: AppConstants.routeErpDepartments,
          page: () => const DepartmentsScreen(),
        ),
        GetPage(
          name: AppConstants.routeErpSubjects,
          page: () => const ErpSubjectsScreen(),
        ),
        GetPage(
          name: AppConstants.routeErpFaculty,
          page: () => const ErpFacultyScreen(),
        ),
        GetPage(
          name: AppConstants.routeErpClassrooms,
          page: () => const ErpClassroomsScreen(),
        ),
        GetPage(
          name: AppConstants.routePeriodTimings,
          page: () => const PeriodTimingsScreen(),
        ),
        GetPage(
          name: AppConstants.routeTimetableEditor,
          page: () => const TimetableEditorScreen(),
        ),
        GetPage(
          name: AppConstants.routeAdminTimetable,
          page: () => const AdminTimetableScreen(),
        ),
        GetPage(
          name: AppConstants.routeStudentTimetable,
          page: () => const StudentTimetableScreen(),
        ),
        GetPage(
          name: AppConstants.routeTeacherTimetable,
          page: () => const TeacherTimetableScreen(),
        ),
      ],
    );
  }
}