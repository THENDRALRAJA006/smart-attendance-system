// ============================================================
// SmartAttend — Faculty Controller (v3)
// Session management, live attendance, WhatsApp share, reports, exports
// Deep-link based attendance — no attendance code shown to students
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/network/api_client.dart';
import '../models/models.dart';

class FacultyController extends GetxController {
  static FacultyController get to => Get.find();

  ApiClient get _api => ApiClient.to;

  // ─── State ──────────────────────────────────────────
  final RxList<SessionModel> sessions = <SessionModel>[].obs;
  final RxList<ClassroomModel> classrooms = <ClassroomModel>[].obs;
  final RxList<SubjectModel> subjects = <SubjectModel>[].obs;
  final RxList<AttendanceModel> attendanceReport = <AttendanceModel>[].obs;
  final RxBool isLoading = false.obs; // General/dashboard loading
  final RxBool isReportLoading = false.obs; // Reports tab loading
  final RxBool isCreatingSession = false.obs; // Session creation loading
  final RxBool isExporting = false.obs;
  final RxString errorMessage = ''.obs; // General/dashboard errors
  final RxString reportErrorMessage = ''.obs; // Report-specific errors
  final Rx<SessionModel?> activeSession = Rx<SessionModel?>(null);

  // Attendance link state (populated on session create / share)
  final RxString activeDeepLink    = ''.obs;
  final RxString activeWebLink     = ''.obs;
  final RxString activeWhatsAppUrl = ''.obs;

  // ─── Live Attendance State ────────────────────────────────
  final RxList<Map<String, dynamic>> liveStudents = <Map<String, dynamic>>[].obs;
  final RxInt liveAttendanceCount = 0.obs;
  Timer? _livePollingTimer;

  @override
  void onReady() {
    super.onReady();
    fetchDashboardData();
  }

  @override
  void onClose() {
    _stopLivePolling();
    super.onClose();
  }

  // ─── Fetch Dashboard ─────────────────────────────────────
  Future<void> fetchDashboardData() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final response = await _api.get('/faculty/dashboard');
      final data = response.data as Map<String, dynamic>;
      sessions.value = (data['sessions'] as List)
          .map((e) => SessionModel.fromJson(e))
          .toList();
      classrooms.value = (data['classrooms'] as List)
          .map((e) => ClassroomModel.fromJson(e))
          .toList();
      subjects.value = (data['subjects'] as List)
          .map((e) => SubjectModel.fromJson(e))
          .toList();
      activeSession.value = sessions.firstWhereOrNull((s) => s.isActive);

      // Start live polling if there's an active session
      if (activeSession.value != null) {
        _startLivePolling();
      }
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Create Session ────────────────────────────────────
  Future<SessionModel?> createSession({
    required int classroomId,
    required int subjectId,
  }) async {
    isCreatingSession.value = true;
    errorMessage.value = '';
    try {
      // Generate a 6-digit code internally — NOT shown to students
      final internalCode = _generateCode();
      final response = await _api.post('/faculty/create-session', data: {
        'classroom_id':    classroomId,
        'subject_id':      subjectId,
        'attendance_code': internalCode, // internal only
      });

      final data = response.data as Map<String, dynamic>;
      final session = SessionModel.fromJson(data);
      sessions.insert(0, session);
      activeSession.value = session;

      // Store the attendance links returned by the server
      activeDeepLink.value    = data['deep_link']    as String? ?? '';
      activeWebLink.value     = data['web_link']     as String? ?? '';
      activeWhatsAppUrl.value = data['whatsapp_url'] as String? ?? '';

      // Start live polling for the new session
      _startLivePolling();

      return session;
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      Get.snackbar(
        'Session Error',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      isCreatingSession.value = false;
    }
  }

  // ─── End Session ─────────────────────────────────────────
  Future<void> endSession(int sessionId) async {
    try {
      await _api.put('/faculty/end-session/$sessionId');
      activeSession.value = null;
      _stopLivePolling();
      liveStudents.clear();
      liveAttendanceCount.value = 0;
      await fetchDashboardData();
      Get.snackbar('Session Ended', 'Attendance session has been closed.',
          snackPosition: SnackPosition.BOTTOM);
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    }
  }

  // ─── Live Attendance Polling ──────────────────────────────
  void _startLivePolling() {
    _stopLivePolling();
    _livePollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => fetchLiveAttendance(),
    );
    // Immediate first fetch
    fetchLiveAttendance();
  }

  void _stopLivePolling() {
    _livePollingTimer?.cancel();
    _livePollingTimer = null;
  }

  Future<void> fetchLiveAttendance() async {
    final session = activeSession.value;
    if (session == null) return;

    try {
      final response = await _api.get(
        '/faculty/live-attendance',
        queryParameters: {'session_id': session.id},
      );
      final data = response.data as Map<String, dynamic>;
      final students = (data['students'] as List)
          .cast<Map<String, dynamic>>();
      liveStudents.value = students;
      liveAttendanceCount.value = data['attendance_count'] as int? ?? 0;
    } catch (_) {
      // Silently fail — live polling should not disrupt the UI
    }
  }

  // ─── WhatsApp Share ──────────────────────────────────
  Future<void> shareViaWhatsApp(SessionModel session) async {
    try {
      final response = await _api.get(
        '/faculty/whatsapp-link',
        queryParameters: {'session_id': session.id},
      );
      final data = response.data as Map<String, dynamic>;
      final whatsappUrl = data['whatsapp_url'] as String;

      // Cache link data
      activeDeepLink.value    = data['deep_link']  as String? ?? '';
      activeWebLink.value     = data['web_link']   as String? ?? '';
      activeWhatsAppUrl.value = whatsappUrl;

      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: copy deep link to snackbar
        final deepLink = data['deep_link'] as String;
        Get.snackbar(
          'Share Link',
          deepLink,
          duration: const Duration(seconds: 8),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      Get.snackbar('Error', errorMessage.value,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ─── Get WhatsApp Link Data ───────────────────────────────
  Future<Map<String, dynamic>?> getWhatsAppLinkData(int sessionId) async {
    try {
      final response = await _api.get(
        '/faculty/whatsapp-link',
        queryParameters: {'session_id': sessionId},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      return null;
    }
  }

  // ─── Fetch Attendance Report ─────────────────────────────
  Future<void> fetchReport({
    required String period,
    int? sessionId,
    int? subjectId,
  }) async {
    isReportLoading.value = true;
    reportErrorMessage.value = '';
    try {
      final response = await _api.get(
        '/faculty/attendance-report',
        queryParameters: {
          'period': period,
          if (sessionId != null) 'session_id': sessionId,
          if (subjectId != null) 'subject_id': subjectId,
        },
      );
      
      if (response.data == null) {
        attendanceReport.clear();
        return;
      }

      if (response.data is List) {
        final list = response.data as List;
        attendanceReport.value = list
            .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        attendanceReport.clear();
        reportErrorMessage.value = 'Unexpected report response format.';
      }
    } on DioException catch (e) {
      attendanceReport.clear(); // Clear stale data on failure
      reportErrorMessage.value = ApiException.fromDioError(e).message;
    } catch (e) {
      attendanceReport.clear();
      reportErrorMessage.value = 'An unexpected error occurred: $e';
    } finally {
      isReportLoading.value = false;
    }
  }

  // ─── Export & Open Report ────────────────────────────────
  Future<void> exportAndOpenReport(
    String format, {
    String period = 'monthly',
  }) async {
    isExporting.value = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'attendance_report_$timestamp.$format';
      final savePath = '${dir.path}/$filename';

      await _api.download(
        '/faculty/export/$format?period=$period',
        savePath,
        onProgress: (received, total) {
          if (total > 0) {
            // Progress tracking can be wired up to a progress bar
          }
        },
      );

      Get.snackbar(
        'Export Ready',
        'Report saved: $filename',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );

      // Open the file with the device's default app
      await OpenFile.open(savePath);
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Export Failed', errorMessage.value,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isExporting.value = false;
    }
  }

  // ─── Create Subject ──────────────────────────────────────
  Future<void> createSubject({
    required String name,
    String? code,
    String? department,
  }) async {
    try {
      await _api.post('/faculty/subjects', data: {
        'subject_name': name,
        'subject_code': code,
        'department': department,
      });
      await fetchDashboardData();
      Get.snackbar('Subject Created', 'Subject "$name" has been added.',
          snackPosition: SnackPosition.BOTTOM);
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    }
  }

  // ─── Generate 6-digit code ───────────────────────────────
  String _generateCode() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }

  // ─── Copy Attendance Link to Clipboard ───────────────────
  /// Copies the web attendance link for the active session.
  /// Shows a confirmation snackbar.
  Future<void> copyAttendanceLink(SessionModel session) async {
    String link = activeWebLink.value;

    if (link.isEmpty) {
      // Fetch the link if not cached
      try {
        final response = await _api.get(
          '/faculty/whatsapp-link',
          queryParameters: {'session_id': session.id},
        );
        final data = response.data as Map<String, dynamic>;
        link = data['web_link'] as String? ?? '';
        activeWebLink.value     = link;
        activeDeepLink.value    = data['deep_link']    as String? ?? '';
        activeWhatsAppUrl.value = data['whatsapp_url'] as String? ?? '';
      } catch (_) {
        link = 'https://smartattend.app/attendance/${session.id}';
      }
    }

    await Clipboard.setData(ClipboardData(text: link));
    Get.snackbar(
      'Link Copied ✅',
      'Attendance link copied to clipboard.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  // ─── Active Sessions (for QR generator dropdown) ─────────
  List<Map<String, dynamic>> get activeSessions => sessions
      .where((s) => s.isActive)
      .map((s) => {
            'id': s.id,
            'subject_name': s.subjectName,
            'classroom_name': s.classroomName,
          })
      .toList();

  // ─── Generate QR Token for a session ─────────────────────
  Future<Map<String, dynamic>?> generateQrToken(int sessionId) async {
    try {
      final response = await _api.post('/faculty/generate-qr', data: {
        'session_id': sessionId,
      });
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      return null;
    }
  }
}

