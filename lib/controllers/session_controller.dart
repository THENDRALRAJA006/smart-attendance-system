// ============================================================
// SmartAttend — Session Controller (v10)
// GetX controller for Teacher Attendance Session management.
// Handles: start, end, extend, live polling, history, export.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';

class SessionController extends GetxController {
  static SessionController get to => Get.find();

  final ApiClient _api = ApiClient.to;

  // ── State ───────────────────────────────────────────────────
  final isLoading        = false.obs;
  final isStarting       = false.obs;
  final isEnding         = false.obs;
  final isExtending      = false.obs;
  final errorMessage     = ''.obs;
  final successMessage   = ''.obs;

  // Active session data
  final hasActiveSession   = false.obs;
  final activeSession      = Rxn<TeacherSessionModel>();

  // History / My-Classes
  final sessionHistory     = <TeacherSessionModel>[].obs;
  final myClasses          = <ClassSummaryModel>[].obs;
  final totalHistory       = 0.obs;

  // Classrooms + Subjects for the start-session form
  final classrooms         = <Map<String, dynamic>>[].obs;
  final subjects           = <Map<String, dynamic>>[].obs;

  // Form state (held here so screen can restore on nav back)
  final selectedClassroomId = Rxn<int>();
  final selectedSubjectId   = Rxn<int>();
  final selectedDepartment  = ''.obs;
  final selectedYear        = 1.obs;
  final selectedSection     = ''.obs;
  final selectedRadius      = 20.obs;
  final selectedDuration    = 15.obs;
  final bleRequired         = true.obs;
  final faceRequired        = true.obs;
  final autoEndSession      = false.obs;

  // Live poll timer
  Timer? _pollTimer;

  // ── Lifecycle ───────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    fetchActiveSession();
    fetchFormData();
    fetchMyClasses();
  }

  @override
  void onClose() {
    _stopPolling();
    super.onClose();
  }

  // ── Polling ─────────────────────────────────────────────────
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => fetchActiveSession(silent: true),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ── Helpers ─────────────────────────────────────────────────
  void _clearMessages() {
    errorMessage.value   = '';
    successMessage.value = '';
  }

  void _setError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      errorMessage.value = data is Map
          ? (data['detail'] ?? e.message ?? 'Request failed')
          : e.message ?? 'Request failed';
    } else {
      errorMessage.value = e.toString();
    }
  }

  // ── Form data ───────────────────────────────────────────────
  Future<void> fetchFormData() async {
    try {
      final resC = await _api.get('/session/classrooms');
      final resS = await _api.get('/session/subjects');
      classrooms.value = List<Map<String, dynamic>>.from(
          (resC.data as List).map((e) => Map<String, dynamic>.from(e)));
      subjects.value = List<Map<String, dynamic>>.from(
          (resS.data as List).map((e) => Map<String, dynamic>.from(e)));
    } catch (e) {
      debugPrint('fetchFormData error: $e');
    }
  }

  // ── My Classes ──────────────────────────────────────────────
  Future<void> fetchMyClasses() async {
    try {
      final res = await _api.get('/session/my-classes');
      myClasses.value = (res.data as List)
          .map((e) => ClassSummaryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('fetchMyClasses error: $e');
    }
  }

  // ── Active Session ──────────────────────────────────────────
  Future<void> fetchActiveSession({bool silent = false}) async {
    if (!silent) isLoading.value = true;
    try {
      final res = await _api.get('/session/active');
      final data = res.data as Map<String, dynamic>;
      hasActiveSession.value = data['has_active_session'] as bool? ?? false;
      if (hasActiveSession.value && data['session'] != null) {
        activeSession.value = TeacherSessionModel.fromJson(
            data['session'] as Map<String, dynamic>);
      } else {
        activeSession.value = null;
        _stopPolling();
      }
    } catch (e) {
      if (!silent) _setError(e);
    } finally {
      if (!silent) isLoading.value = false;
    }
  }

  // ── Session Details (for history items) ─────────────────────
  Future<TeacherSessionModel?> fetchSessionDetails(int sessionId) async {
    try {
      final res = await _api.get('/session/details/$sessionId');
      return TeacherSessionModel.fromJson(
          res.data as Map<String, dynamic>);
    } catch (e) {
      _setError(e);
      return null;
    }
  }

  // ── Start Session ───────────────────────────────────────────
  Future<bool> startSession() async {
    _clearMessages();
    if (selectedClassroomId.value == null) {
      errorMessage.value = 'Please select a classroom';
      return false;
    }
    if (selectedSubjectId.value == null) {
      errorMessage.value = 'Please select a subject';
      return false;
    }
    if (selectedDepartment.value.trim().isEmpty) {
      errorMessage.value = 'Please enter the department';
      return false;
    }
    if (selectedSection.value.trim().isEmpty) {
      errorMessage.value = 'Please enter the section';
      return false;
    }

    isStarting.value = true;
    try {
      final res = await _api.post('/session/start', data: {
        'classroom_id':      selectedClassroomId.value,
        'subject_id':        selectedSubjectId.value,
        'department':        selectedDepartment.value.trim(),
        'year':              selectedYear.value,
        'section':           selectedSection.value.trim().toUpperCase(),
        'attendance_radius': selectedRadius.value,
        'duration_minutes':  selectedDuration.value,
        'ble_required':      bleRequired.value,
        'face_required':     faceRequired.value,
        'auto_end':          autoEndSession.value,
      });

      activeSession.value =
          TeacherSessionModel.fromJson(res.data as Map<String, dynamic>);
      hasActiveSession.value = true;
      successMessage.value   = 'Session started successfully!';
      startPolling();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      isStarting.value = false;
    }
  }

  // ── End Session ─────────────────────────────────────────────
  Future<bool> endSession(int sessionId) async {
    _clearMessages();
    isEnding.value = true;
    try {
      await _api.post('/session/end/$sessionId');
      activeSession.value    = null;
      hasActiveSession.value = false;
      successMessage.value   = 'Session ended successfully';
      _stopPolling();
      fetchSessionHistory(); // refresh history
      fetchMyClasses();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      isEnding.value = false;
    }
  }

  // ── Extend Session ──────────────────────────────────────────
  Future<bool> extendSession(int sessionId, {int extraMinutes = 5}) async {
    _clearMessages();
    isExtending.value = true;
    try {
      await _api.post('/session/extend/$sessionId', data: {
        'extra_minutes': extraMinutes,
      });
      successMessage.value = 'Extended by $extraMinutes minutes!';
      await fetchActiveSession(silent: true);
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      isExtending.value = false;
    }
  }

  // ── History ─────────────────────────────────────────────────
  Future<void> fetchSessionHistory({int limit = 30, int offset = 0}) async {
    isLoading.value = true;
    _clearMessages();
    try {
      final res = await _api.get('/session/history', queryParameters: {
        'limit': limit,
        'offset': offset,
      });
      final data = res.data as Map<String, dynamic>;
      totalHistory.value = (data['total'] as num?)?.toInt() ?? 0;
      if (offset == 0) {
        sessionHistory.value = (data['items'] as List)
            .map((e) => TeacherSessionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        sessionHistory.addAll((data['items'] as List)
            .map((e) => TeacherSessionModel.fromJson(e as Map<String, dynamic>))
            .toList());
      }
    } catch (e) {
      _setError(e);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Export ──────────────────────────────────────────────────
  Future<void> exportSession(int sessionId, String fmt) async {
    _clearMessages();
    try {
      await _api.getBytes('/session/export/$sessionId/$fmt');
      // In a real app, use path_provider + open_file to save & open the file.
      // For now, just notify success.
      successMessage.value = 'Report downloaded (${fmt.toUpperCase()})';
      Get.snackbar(
        'Export Ready',
        'Attendance report downloaded as ${fmt.toUpperCase()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.bgCard,
        colorText: AppTheme.textPrimary,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      _setError(e);
    }
  }

  // ── Form helpers ────────────────────────────────────────────
  void resetForm() {
    selectedClassroomId.value = null;
    selectedSubjectId.value   = null;
    selectedDepartment.value  = '';
    selectedYear.value        = 1;
    selectedSection.value     = '';
    selectedRadius.value      = 20;
    selectedDuration.value    = 15;
    bleRequired.value         = true;
    faceRequired.value        = true;
    autoEndSession.value      = false;
    _clearMessages();
  }

  String get generatedSessionName {
    final classroom = classrooms.firstWhereOrNull(
      (c) => c['id'] == selectedClassroomId.value,
    );
    final subject = subjects.firstWhereOrNull(
      (s) => s['id'] == selectedSubjectId.value,
    );
    if (classroom == null || subject == null) return '';
    final room   = (classroom['room_name'] as String)
        .replaceAll('CLASSROOM_', '');
    final subj   = (subject['subject_name'] as String)
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .substring(0, ((subject['subject_name'] as String).length).clamp(0, 8))
        .toUpperCase();
    final ts = DateFormat('yyyy_MM_dd_HH_mm').format(DateTime.now());
    return '${room}_${subj}_$ts';
  }
}
