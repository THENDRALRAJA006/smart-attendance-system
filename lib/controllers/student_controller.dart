// ============================================================
// SmartAttend — Student Controller
// Dashboard stats, attendance history
// ============================================================

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../core/network/api_client.dart';
import '../models/models.dart';

class StudentController extends GetxController {
  static StudentController get to => Get.find();

  ApiClient get _api => ApiClient.to;

  // ─── State ──────────────────────────────────────────────
  final Rx<DashboardStats?> dashboardStats = Rx<DashboardStats?>(null);
  final RxList<AttendanceModel> attendanceHistory = <AttendanceModel>[].obs;
  final RxList<Map<String, dynamic>> attendanceRecords = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString filterPeriod = 'monthly'.obs; // daily | weekly | monthly

  @override
  void onInit() {
    super.onInit();
    fetchDashboard();
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
      // keep raw records for reports screen
      attendanceRecords.value = list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Load attendance history for Reports screen ─────────────
  Future<void> loadAttendanceHistory() => fetchHistory(period: 'all');

  // ─── Refresh ─────────────────────────────────────────────
  Future<void> refresh() async {
    await fetchDashboard();
    await fetchHistory(period: filterPeriod.value);
  }
}
