// ============================================================
// SmartAttend — Student Controller (v13 Live Schedule)
// Dashboard stats, attendance history, active session polling,
// subject details, missed classes, semester analytics, monthly.
// v13: Added fetchTodaySchedule + 30s schedule live poll.
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

  // v11 — enhanced analytics state
  final Rx<SubjectDetailModel?> subjectDetail   = Rx<SubjectDetailModel?>(null);
  final RxList<MissedClassModel> missedClasses  = <MissedClassModel>[].obs;
  final Rx<SemesterAnalyticsModel?> analytics   = Rx<SemesterAnalyticsModel?>(null);
  final RxList<MonthlyStatsModel> monthlyStats  = <MonthlyStatsModel>[].obs;
  final RxBool isLoadingDetail                  = false.obs;
  final RxBool isLoadingMissed                  = false.obs;
  final RxBool isLoadingAnalytics               = false.obs;

  // v13 — live today schedule state (separate from full dashboard)
  final RxList<TodayScheduleEntry> todayScheduleLive = <TodayScheduleEntry>[].obs;
  final RxBool isScheduleLoading = false.obs;

  // ─── Timers ──────────────────────────────────────────────
  Timer? _sessionPollTimer;
  Timer? _schedulePollTimer;
  static const _sessionPollInterval = Duration(seconds: 30);
  static const _schedulePolInterval = Duration(seconds: 30);

  @override
  void onInit() {
    super.onInit();
    fetchDashboard();
    _startSessionPolling();
    _startSchedulePolling();
  }

  @override
  void onClose() {
    _sessionPollTimer?.cancel();
    _schedulePollTimer?.cancel();
    super.onClose();
  }

  // ─── Session Polling ─────────────────────────────────────
  void _startSessionPolling() {
    _checkActiveSession();
    _sessionPollTimer = Timer.periodic(_sessionPollInterval, (_) {
      _checkActiveSession();
    });
  }

  Future<void> _checkActiveSession() async {
    try {
      final attendance = Get.find<AttendanceController>();
      await attendance.checkActiveSession();
    } catch (_) {}
  }

  Future<void> refreshSessionStatus() async => _checkActiveSession();

  // ─── Schedule Live Polling (30s) ─────────────────────────
  void _startSchedulePolling() {
    fetchTodaySchedule();
    _schedulePollTimer = Timer.periodic(_schedulePolInterval, (_) {
      fetchTodaySchedule();
    });
  }

  /// Fetch just today's schedule (lightweight — 30s poll)
  Future<void> fetchTodaySchedule() async {
    isScheduleLoading.value = true;
    try {
      final response = await _api.get('/student/today-schedule');
      final data = response.data as Map<String, dynamic>;
      final list = data['today_schedule'] as List? ?? [];
      todayScheduleLive.value = list
          .map((e) => TodayScheduleEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      // Sync into dashboardStats.todaySchedule so _TodayScheduleSection updates
      final current = dashboardStats.value;
      if (current != null) {
        dashboardStats.value = DashboardStats(
          totalClasses:         current.totalClasses,
          attendedClasses:      current.attendedClasses,
          attendancePercentage: current.attendancePercentage,
          subjectWise:          current.subjectWise,
          recentHistory:        current.recentHistory,
          todaySchedule:        todayScheduleLive.toList(),
          quickStats:           current.quickStats,
        );
      }
    } on DioException catch (_) {
      // Silent fail on poll — don't show error toast
    } catch (_) {}
    isScheduleLoading.value = false;
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
      // Sync live schedule list from dashboard response
      todayScheduleLive.value = dashboardStats.value?.todaySchedule ?? [];
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
      dashboardStats.value ??= DashboardStats.empty();
    } catch (e) {
      errorMessage.value = 'Failed to load dashboard: $e';
      dashboardStats.value ??= DashboardStats.empty();
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Fetch Subject Detail ────────────────────────────────
  Future<void> fetchSubjectDetail(int subjectId) async {
    isLoadingDetail.value = true;
    subjectDetail.value = null;
    errorMessage.value = '';
    try {
      final response = await _api.get('/student/subject/$subjectId');
      subjectDetail.value = SubjectDetailModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } catch (e) {
      errorMessage.value = 'Failed to load subject: $e';
    } finally {
      isLoadingDetail.value = false;
    }
  }

  // ─── Fetch Missed Classes ────────────────────────────────
  Future<void> fetchMissedClasses() async {
    isLoadingMissed.value = true;
    errorMessage.value = '';
    try {
      final response = await _api.get('/student/missed');
      final list = response.data as List;
      missedClasses.value = list
          .map((e) => MissedClassModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } catch (e) {
      errorMessage.value = 'Failed to load missed classes: $e';
    } finally {
      isLoadingMissed.value = false;
    }
  }

  // ─── Fetch Analytics ─────────────────────────────────────
  Future<void> fetchAnalytics() async {
    isLoadingAnalytics.value = true;
    errorMessage.value = '';
    try {
      final response = await _api.get('/student/analytics');
      analytics.value = SemesterAnalyticsModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } catch (e) {
      errorMessage.value = 'Failed to load analytics: $e';
    } finally {
      isLoadingAnalytics.value = false;
    }
  }

  // ─── Fetch Monthly Stats ─────────────────────────────────
  Future<void> fetchMonthlyStats({int? year}) async {
    try {
      final params = year != null ? {'year': year} : null;
      final response = await _api.get('/student/monthly',
          queryParameters: params?.cast<String, dynamic>());
      final data = response.data as Map<String, dynamic>;
      final list = data['months'] as List? ?? [];
      monthlyStats.value = list
          .map((e) => MonthlyStatsModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  // ─── Fetch Enhanced History ──────────────────────────────
  Future<void> fetchEnhancedHistory({
    String period = 'month',
    String? dateFrom,
    String? dateTo,
  }) async {
    filterPeriod.value = period;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final params = <String, dynamic>{'period': period};
      if (dateFrom != null) params['date_from'] = dateFrom;
      if (dateTo != null)   params['date_to']   = dateTo;

      final response = await _api.get('/student/history',
          queryParameters: params);
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

  // ─── Fetch Attendance History (legacy, kept for Reports screen) ──
  Future<void> fetchHistory({String period = 'monthly'}) async {
    final mapping = {'daily': 'today', 'weekly': 'week', 'monthly': 'month'};
    await fetchEnhancedHistory(period: mapping[period] ?? period);
  }

  // ─── Load for Reports screen ─────────────────────────────
  Future<void> loadAttendanceHistory() => fetchHistory(period: 'all');

  // ─── Refresh ─────────────────────────────────────────────
  @override
  Future<void> refresh() async {
    await Future.wait([
      fetchDashboard(),
      fetchTodaySchedule(),
      fetchEnhancedHistory(period: filterPeriod.value),
      _checkActiveSession(),
    ]);
  }
}
