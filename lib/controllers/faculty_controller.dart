// ============================================================
// SmartAttend — Faculty Controller (v3)
// Session management, live attendance, WhatsApp share, reports, exports
// Deep-link based attendance — no attendance code shown to students
// ============================================================

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
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
  final RxInt liveStudentTotal    = 0.obs;   // Total enrolled students for session
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
    String? department,
    int? year,
    String? section,
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
        if (department != null) 'department': department,
        if (year != null)       'year': year,
        if (section != null)    'section': section,
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
      const Duration(seconds: 30), // 30s is sufficient for live classroom context
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
      liveStudentTotal.value    = data['total_enrolled']   as int? ?? 0;
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
  /// Android 11-15 Scoped Storage safe export.
  ///
  /// Strategy:
  ///  1. Download file to app temp directory (no storage permission needed)
  ///  2. Open with device default app (open_file) OR
  ///     Share via native share sheet (share_plus) → user can save to Downloads
  ///
  /// Why NOT /storage/emulated/0/Downloads directly:
  ///  - Android 11+ (API 30+) Scoped Storage blocks direct writes
  ///  - WRITE_EXTERNAL_STORAGE is deprecated/ignored on API 30+
  ///  - MediaStore API requires complex async cursors — overkill here
  ///  - share_plus wraps FileProvider intent, works on all Android 5+
  final RxDouble exportProgress = 0.0.obs;

  Future<void> exportAndOpenReport(
    String format, {
    String period = 'monthly',
  }) async {
    isExporting.value = true;
    exportProgress.value = 0.0;
    errorMessage.value = '';

    // Normalize format: UI 'excel' → backend 'xlsx'
    final backendFmt = format == 'excel' ? 'xlsx' : format.toLowerCase().trim();
    final ext = backendFmt; // csv | xlsx | pdf
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'SmartAttend_Report_$timestamp.$ext';

    dev.log('[EXPORT] Starting export: format=$backendFmt period=$period', name: 'Export');

    try {
      // ── Step 1: Save to temp dir — always accessible, no permissions ──
      // getTemporaryDirectory() → /data/user/0/<pkg>/cache on Android
      // This is app-private, no storage permission needed on any Android version.
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$filename';
      dev.log('[EXPORT] Temp save path: $savePath', name: 'Export');

      // ── Step 2: Download bytes from backend ──────────────────────────
      await _api.download(
        '/faculty/export/$backendFmt',
        savePath,
        queryParameters: {'period': period},
        onProgress: (received, total) {
          if (total > 0) {
            exportProgress.value = received / total;
          }
        },
      );

      exportProgress.value = 1.0;
      final file = File(savePath);

      if (!file.existsSync() || file.lengthSync() == 0) {
        throw Exception('Downloaded file is empty or missing. The server may have returned no data.');
      }

      dev.log('[EXPORT] ✅ Download complete: ${file.lengthSync()} bytes → $savePath', name: 'Export');

      // ── Step 3: Determine MIME type ──────────────────────────────────
      final mimeType = switch (ext) {
        'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'csv'  => 'text/csv',
        'pdf'  => 'application/pdf',
        _      => 'application/octet-stream',
      };

      // ── Step 4: Show success dialog with Open & Share options ────────
      _showExportSuccessDialog(
        filename: filename,
        savePath: savePath,
        mimeType: mimeType,
        ext: ext,
      );

    } on DioException catch (e) {
      dev.log('[EXPORT] ❌ Dio error: ${e.response?.statusCode} ${e.message}', name: 'Export');
      final sc = e.response?.statusCode;
      final errMsg = switch (sc) {
        401 => 'Session expired. Please log in again.',
        403 => 'Access denied. You do not have permission to export reports.',
        404 => 'No report data found for this period. Try a different date range.',
        500 => 'Server error generating the report. Please try again later.',
        _   => ApiException.fromDioError(e).message,
      };
      errorMessage.value = errMsg;
      _showExportErrorDialog(errMsg);
    } catch (e) {
      dev.log('[EXPORT] ❌ Unexpected error: $e', name: 'Export');
      final errMsg = e.toString().contains('empty')
          ? e.toString()
          : 'Export failed: Unable to save file.\n\nDetails: $e';
      errorMessage.value = errMsg;
      _showExportErrorDialog(errMsg);
    } finally {
      isExporting.value = false;
      exportProgress.value = 0.0;
    }
  }

  // ─── Export Success Dialog ───────────────────────────────
  void _showExportSuccessDialog({
    required String filename,
    required String savePath,
    required String mimeType,
    required String ext,
  }) {
    final fmtLabel = switch (ext) {
      'xlsx' => 'Excel',
      'csv'  => 'CSV',
      'pdf'  => 'PDF',
      _      => ext.toUpperCase(),
    };

    Get.dialog(
      Dialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ──────────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.success, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                '$fmtLabel Exported Successfully',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.bgCardLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(_extIcon(ext), color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        filename,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap "Open" to view the file, or "Share" to save it to Downloads, Drive, or WhatsApp.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // ── Action Buttons ────────────────────────
              Row(
                children: [
                  // Share button → native OS share sheet
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Get.back();
                        dev.log('[EXPORT] Sharing via share_plus...', name: 'Export');
                        try {
                          await SharePlus.instance.share(
                            ShareParams(
                              files: [XFile(savePath, mimeType: mimeType, name: filename)],
                              subject: 'SmartAttend Attendance Report',
                            ),
                          );
                        } catch (e) {
                          dev.log('[EXPORT] share_plus error: $e', name: 'Export');
                          _showExportErrorDialog('Could not open share sheet: $e');
                        }
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share / Save'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Open button → open with default app
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        dev.log('[EXPORT] Opening file: $savePath', name: 'Export');
                        final result = await OpenFile.open(savePath);
                        if (result.type != ResultType.done) {
                          dev.log('[EXPORT] OpenFile error: ${result.message}', name: 'Export');
                          // Fallback to share if open fails (e.g., no app installed)
                          try {
                            await SharePlus.instance.share(
                              ShareParams(
                                files: [XFile(savePath, mimeType: mimeType, name: filename)],
                                subject: 'SmartAttend Attendance Report',
                              ),
                            );
                          } catch (_) {
                            _showExportErrorDialog(
                              'No app found to open .$ext files.\n'
                              'Please install a compatible viewer\n'
                              '(e.g., Google Sheets for Excel, Adobe for PDF).',
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Export Error Dialog ─────────────────────────────────
  void _showExportErrorDialog(String message) {
    Get.dialog(
      Dialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: AppTheme.error, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Export Failed',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Icon helper for file format ────────────────────────
  IconData _extIcon(String ext) => switch (ext) {
    'xlsx' => Icons.table_chart_rounded,
    'csv'  => Icons.grid_on_rounded,
    'pdf'  => Icons.picture_as_pdf_rounded,
    _      => Icons.insert_drive_file_rounded,
  };

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

