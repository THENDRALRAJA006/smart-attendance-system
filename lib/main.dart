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
import 'core/services/offline_queue_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';

import 'controllers/admin_controller.dart';
import 'controllers/attendance_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/faculty_controller.dart';
import 'controllers/student_controller.dart';

import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/face_registration_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/faculty/faculty_dashboard.dart';
import 'screens/faculty/qr_generator_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/student/attendance_history_screen.dart';
import 'screens/student/attendance_result_screen.dart';
import 'screens/student/attendance_verification_screen.dart';
import 'screens/student/classroom_detection_screen.dart';
import 'screens/student/qr_scanner_screen.dart';
import 'screens/student/reports_screen.dart';
import 'screens/student/student_dashboard.dart';

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

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgDark,
      systemNavigationBarIconBrightness: Brightness.light,
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
      theme: AppTheme.darkTheme,

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
          name: AppConstants.routeFaceRegister,
          page: () => const FaceRegistrationScreen(),
        ),
        GetPage(
          name: AppConstants.routeStudentDashboard,
          page: () => const StudentDashboard(),
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
          name: AppConstants.routeQrScanner,
          page: () => const QrScannerScreen(),
        ),
        GetPage(
          name: AppConstants.routeProfile,
          page: () => const ProfileScreen(),
        ),
        GetPage(
          name: AppConstants.routeFacultyDashboard,
          page: () => const FacultyDashboard(),
        ),
        GetPage(
          name: AppConstants.routeQrGenerator,
          page: () => const QrGeneratorScreen(),
        ),
        GetPage(
          name: AppConstants.routeAdminDashboard,
          page: () => const AdminDashboard(),
        ),
      ],
    );
  }
}