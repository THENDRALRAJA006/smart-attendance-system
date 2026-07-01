// ============================================================
// SmartAttend — Student Controller (v2)
// Dashboard stats, attendance history, active session polling
// ============================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../core/network/api_client.dart';
import '../models/models.dart';
import 'attendance_controller.dart';

class StudentController extends GetxController {
  static StudentController get to => Get.find();

  ApiClient get _api => ApiClient.to;

  // ─── State ──────────────────────────────────────────────
  final Rx<DashboardStats?> dashboardStats = Rx<DashboardStats?>(null);
  final RxList<AttendanceModel> attendanceHistory = <AttendanceModel>[].obs;
  final RxList<Map<String, dynamic>> attendanceRecords = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString filterPeriod = 'monthly'.obs;

  // ─── Session Poll Timer ──────────────────────────────────
  Timer? _sessionPollTimer;
  static const _pollInterval = Duration(seconds: 30);

  @override
  void onInit() {
    super.onInit();
    fetchDashboard();
    _startSessionPolling();
  }

  @override
  void onClose() {
    _sessionPollTimer?.cancel();
    super.onClose();
  }

  // ─── Session Polling ─────────────────────────────────────
  void _startSessionPolling() {
    // Initial check
    _checkActiveSession();
    // Periodic polling every 30 seconds
    _sessionPollTimer = Timer.periodic(_pollInterval, (_) {
      _checkActiveSession();
    });
  }

  Future<void> _checkActiveSession() async {
    try {
      final attendance = Get.find<AttendanceController>();
      await attendance.checkActiveSession();
    } catch (_) {
      // Silently ignore — controller may not be ready yet
    }
  }

  // ─── Force refresh session check ────────────────────────
  Future<void> refreshSessionStatus() async {
    await _checkActiveSession();
  }

  // ─── Fetch Dashboard ─────────────────────────────────────
  Future<void> fetchDashboard() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final response = await _api.get('/student/dashboard');
      dashboardStats.value = DashboardStats.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Fetch Attendance History ────────────────────────────
  Future<void> fetchHistory({String period = 'monthly'}) async {
    filterPeriod.value = period;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final response = await _api.get(
        '/student/attendance-history',
        queryParameters: {'period': period},
      );
      final list = response.data as List;
      attendanceHistory.value = list
          .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
          .toList();
      attendanceRecords.value = list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Load for Reports screen ─────────────────────────────
  Future<void> loadAttendanceHistory() => fetchHistory(period: 'all');

  // ─── Refresh ─────────────────────────────────────────────
  @override
  Future<void> refresh() async {
    await Future.wait([
      fetchDashboard(),
      fetchHistory(period: filterPeriod.value),
      _checkActiveSession(),
    ]);
  }
}
