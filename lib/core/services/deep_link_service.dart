// ============================================================
// SmartAttend — Deep Link Service (v3)
// Handles smartattend://attendance/{sessionId} links
// and https://smartattend.app/attendance/{sessionId}
// ============================================================

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import '../constants/app_constants.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';

class DeepLinkService {
  static DeepLinkService get to => Get.find();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  // ─── Initialize ──────────────────────────────────────────
  Future<void> init() async {
    // Handle the initial deep link (app opened from cold start)
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        // Delay slightly so app & GetX controllers are initialized
        await Future.delayed(const Duration(milliseconds: 500));
        _handleLink(initialLink);
      }
    } catch (e) {
      // No initial link — normal app launch
    }

    // Listen for links while the app is running (warm start)
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) => _handleLink(uri),
      onError: (err) {
        // Link stream error — non-fatal
      },
    );
  }

  // ─── Handle Incoming Link ─────────────────────────────────
  void _handleLink(Uri uri) {
    // Supported formats:
    //   smartattend://attendance/42
    //   https://smartattend.app/attendance/42

    String? sessionIdStr;

    if (uri.scheme == 'smartattend' && uri.host == 'attendance') {
      // Custom scheme: smartattend://attendance/42
      sessionIdStr = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : null;
    } else if (uri.scheme == 'https' || uri.scheme == 'http') {
      // HTTPS: https://smartattend.app/attendance/42
      final idx = uri.pathSegments.indexOf('attendance');
      if (idx >= 0 && idx + 1 < uri.pathSegments.length) {
        sessionIdStr = uri.pathSegments[idx + 1];
      }
    }

    if (sessionIdStr != null) {
      final sessionId = int.tryParse(sessionIdStr);
      if (sessionId != null) {
        _navigateToAttendance(sessionId, uri);
      }
    }
  }

  // ─── Navigate to Attendance Flow ─────────────────────────
  void _navigateToAttendance(int sessionId, Uri originalUri) {
    // Check if student is logged in
    final auth = Get.find<AuthController>();
    final isLoggedIn = auth.isAuthenticated;

    if (!isLoggedIn) {
      // Not logged in — navigate to login with intent to return
      Get.offAllNamed(
        AppConstants.routeLogin,
        arguments: {
          'redirect_after_login': AppConstants.routeClassroomDetection,
          'deep_link_session_id': sessionId,
        },
      );
      return;
    }

    // Set session context on the attendance controller
    final attendanceCtrl = Get.find<AttendanceController>();
    attendanceCtrl.setDeepLinkContext(sessionId: sessionId);

    // Fetch session details (subject/classroom name) non-blocking
    attendanceCtrl.fetchSessionInfo(sessionId);

    // Navigate to classroom detection (BLE scan step)
    Get.offAllNamed(
      AppConstants.routeClassroomDetection,
      arguments: {
        'deep_link':  true,
        'session_id': sessionId,
        'full_uri':   originalUri.toString(),
      },
    );
  }

  // ─── Generate Deep Link ──────────────────────────────────
  static String generateLink(int sessionId) {
    return 'smartattend://attendance/$sessionId';
  }

  // ─── Generate WhatsApp Share URL ─────────────────────────
  /// NOTE: Attendance code is NOT included in the WhatsApp message.
  /// BLE proximity + face recognition are the verification methods.
  static String generateWhatsAppUrl({
    required int sessionId,
    required String subjectName,
    required String classroomName,
    String baseUrl = 'https://smartattend.app',
  }) {
    final webLink = '$baseUrl/attendance/$sessionId';
    final message = Uri.encodeComponent(
      '📚 *SmartAttend — Attendance Open*\n\n'
      'Subject: *$subjectName*\n'
      'Classroom: *$classroomName*\n\n'
      'Tap the link below to mark your attendance:\n$webLink\n\n'
      '_Make sure Bluetooth is ON and you are inside the classroom._\n'
      '_BLE + Face Verification required._',
    );
    return 'https://wa.me/?text=$message';
  }

  // ─── Dispose ─────────────────────────────────────────────
  void dispose() {
    _linkSub?.cancel();
  }
}
