// ============================================================
// SmartAttend — Admin Controller (v4 — Super Admin)
// Full state management for all 10 admin modules
// ============================================================

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../core/network/api_client.dart';
import '../models/models.dart';

class AdminController extends GetxController {
  static AdminController get to => Get.find();
  ApiClient get _api => ApiClient.to;

  // ─── Dashboard ─────────────────────────────────────────────
  final Rx<AdminDashboardStats> dashboardStats =
      AdminDashboardStats.empty().obs;

  // ─── Students ──────────────────────────────────────────────
  final RxList<AdminStudentModel> students = <AdminStudentModel>[].obs;
  final RxInt studentsTotal = 0.obs;

  // ─── Faculty ───────────────────────────────────────────────
  final RxList<AdminFacultyModel> faculty = <AdminFacultyModel>[].obs;
  final RxInt facultyTotal = 0.obs;

  // ─── Classrooms / Subjects ──────────────────────────────────
  final RxList<ClassroomModel> classrooms = <ClassroomModel>[].obs;
  final RxList<SubjectModel> subjects = <SubjectModel>[].obs;

  // ─── Attendance ─────────────────────────────────────────────
  final RxList<AdminAttendanceRecord> attendanceRecords =
      <AdminAttendanceRecord>[].obs;
  final RxInt attendanceTotal = 0.obs;

  // ─── Sessions ───────────────────────────────────────────────
  final RxList<AdminSessionModel> sessions = <AdminSessionModel>[].obs;
  final RxInt sessionsTotal = 0.obs;

  // ─── Faces ──────────────────────────────────────────────────
  final RxList<Map<String, dynamic>> faceList = <Map<String, dynamic>>[].obs;
  final RxInt faceTotal = 0.obs;

  // ─── Device Security ────────────────────────────────────────
  final RxList<DeviceLogModel> deviceLogs = <DeviceLogModel>[].obs;
  final RxInt deviceLogsTotal = 0.obs;
  final RxList<DeviceBindingModel> deviceBindings =
      <DeviceBindingModel>[].obs;
  final RxList<Map<String, dynamic>> duplicateDevices =
      <Map<String, dynamic>>[].obs;

  // ─── BLE Beacons ────────────────────────────────────────────
  final RxList<BleBeaconModel> bleBeacons = <BleBeaconModel>[].obs;

  // ─── Settings ───────────────────────────────────────────────
  final RxMap<String, List<SystemSettingModel>> settings =
      <String, List<SystemSettingModel>>{}.obs;

  // ─── Audit Logs ─────────────────────────────────────────────
  final RxList<AuditLogModel> auditLogs = <AuditLogModel>[].obs;
  final RxInt auditLogsTotal = 0.obs;

  // ─── UI State ───────────────────────────────────────────────
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString successMessage = ''.obs;

  // Legacy
  final RxInt totalStudents = 0.obs;
  final RxInt totalFaculty = 0.obs;
  final RxInt totalDepartments = 0.obs;
  final RxInt totalClassrooms = 0.obs;
  final RxDouble systemAttendanceRate = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDashboard();
  }

  void _setError(dynamic e) {
    if (e is DioException) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } else {
      errorMessage.value = e.toString();
    }
  }

  void _setSuccess(String msg) => successMessage.value = msg;
  void clearMessages() {
    errorMessage.value = '';
    successMessage.value = '';
  }

  // ══════════════════════════════════════════════════════════
  // DASHBOARD
  // ══════════════════════════════════════════════════════════

  Future<void> fetchDashboard() async {
    isLoading.value = true;
    try {
      final res = await _api.get('/admin/dashboard');
      final stats = AdminDashboardStats.fromJson(res.data);
      dashboardStats.value = stats;
      // Keep legacy observables in sync
      totalStudents.value         = stats.totalStudents;
      totalFaculty.value          = stats.totalFaculty;
      totalDepartments.value      = stats.totalDepartments;
      totalClassrooms.value       = stats.totalClassrooms;
      systemAttendanceRate.value  = stats.systemAttendanceRate;
    } catch (e) {
      _setError(e);
    } finally {
      isLoading.value = false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // STUDENTS
  // ══════════════════════════════════════════════════════════

  Future<void> fetchStudents({
    String? search,
    String? department,
    bool? isActive,
    int? year,
    int skip = 0,
    int limit = 50,
  }) async {
    isLoading.value = true;
    try {
      final res = await _api.get('/admin/students', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (department != null) 'department': department,
        if (isActive != null) 'is_active': isActive,
        if (year != null) 'year': year,
        'skip': skip,
        'limit': limit,
      });
      studentsTotal.value = res.data['total'] ?? 0;
      students.value = (res.data['items'] as List)
          .map((e) => AdminStudentModel.fromJson(e))
          .toList();
    } catch (e) {
      _setError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>?> getStudentDetail(int id) async {
    try {
      final res = await _api.get('/admin/students/$id');
      return res.data;
    } catch (e) {
      _setError(e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStudentAttendance(int id,
      {int skip = 0, int limit = 50}) async {
    try {
      final res = await _api.get('/admin/students/$id/attendance',
          queryParameters: {'skip': skip, 'limit': limit});
      return res.data;
    } catch (e) {
      _setError(e);
      return null;
    }
  }

  Future<bool> createStudent(Map<String, dynamic> data) async {
    try {
      await _api.post('/admin/students', data: data);
      _setSuccess('Student created successfully');
      await fetchDashboard();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> editStudent(int id, Map<String, dynamic> data) async {
    try {
      await _api.patch('/admin/students/$id', data: data);
      _setSuccess('Student updated successfully');
      final idx = students.indexWhere((s) => s.id == id);
      if (idx != -1) await fetchStudents();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<void> toggleStudentSuspend(int id) async {
    try {
      final res = await _api.post('/admin/students/$id/suspend');
      final isActive = res.data['is_active'] as bool;
      final idx = students.indexWhere((s) => s.id == id);
      if (idx != -1) {
        final s = students[idx];
        students[idx] = AdminStudentModel(
          id: s.id, name: s.name, regNo: s.regNo,
          department: s.department, year: s.year, section: s.section,
          email: s.email, phoneNumber: s.phoneNumber,
          isActive: isActive,
          faceRegistered: s.faceRegistered, faceCount: s.faceCount,
          faceId: s.faceId, createdAt: s.createdAt,
        );
      }
      _setSuccess(isActive ? 'Student activated' : 'Student suspended');
    } catch (e) {
      _setError(e);
    }
  }

  Future<String?> resetStudentPassword(int id) async {
    try {
      final res = await _api.post('/admin/students/$id/reset-password', data: {});
      _setSuccess('Password reset successfully');
      return res.data['temp_password'] as String?;
    } catch (e) {
      _setError(e);
      return null;
    }
  }

  Future<bool> deleteStudentFace(int id) async {
    try {
      await _api.delete('/admin/students/$id/face');
      _setSuccess('Face data deleted');
      await fetchStudents();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> deleteStudent(int id) async {
    try {
      await _api.delete('/admin/students/$id');
      students.removeWhere((s) => s.id == id);
      totalStudents.value--;
      _setSuccess('Student deleted');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // FACULTY
  // ══════════════════════════════════════════════════════════

  Future<void> fetchFaculty({
    String? search,
    String? department,
    bool? isActive,
    int skip = 0,
    int limit = 50,
  }) async {
    isLoading.value = true;
    try {
      final res = await _api.get('/admin/faculty', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (department != null) 'department': department,
        if (isActive != null) 'is_active': isActive,
        'skip': skip,
        'limit': limit,
      });
      facultyTotal.value = res.data['total'] ?? 0;
      faculty.value = (res.data['items'] as List)
          .map((e) => AdminFacultyModel.fromJson(e))
          .toList();
    } catch (e) {
      _setError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createFaculty(Map<String, dynamic> data) async {
    try {
      await _api.post('/admin/faculty', data: data);
      _setSuccess('Staff created successfully');
      await fetchDashboard();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> editFaculty(int id, Map<String, dynamic> data) async {
    try {
      await _api.patch('/admin/faculty/$id', data: data);
      _setSuccess('Staff updated');
      await fetchFaculty();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<void> toggleFacultySuspend(int id) async {
    try {
      final res = await _api.post('/admin/faculty/$id/suspend');
      final isActive = res.data['is_active'] as bool;
      final idx = faculty.indexWhere((f) => f.id == id);
      if (idx != -1) {
        final f = faculty[idx];
        faculty[idx] = AdminFacultyModel(
          id: f.id, name: f.name, email: f.email,
          department: f.department, phoneNumber: f.phoneNumber,
          isActive: isActive, createdAt: f.createdAt,
        );
      }
      _setSuccess(isActive ? 'Staff activated' : 'Staff suspended');
    } catch (e) {
      _setError(e);
    }
  }

  Future<String?> resetFacultyPassword(int id) async {
    try {
      final res = await _api.post('/admin/faculty/$id/reset-password', data: {});
      _setSuccess('Password reset successfully');
      return res.data['temp_password'] as String?;
    } catch (e) {
      _setError(e);
      return null;
    }
  }

  Future<bool> deleteFaculty(int id) async {
    try {
      await _api.delete('/admin/faculty/$id');
      faculty.removeWhere((f) => f.id == id);
      _setSuccess('Staff deleted');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // CLASSROOMS & SUBJECTS
  // ══════════════════════════════════════════════════════════

  Future<void> fetchClassrooms() async {
    try {
      final res = await _api.get('/admin/classrooms');
      classrooms.value =
          (res.data as List).map((e) => ClassroomModel.fromJson(e)).toList();
    } catch (e) {
      _setError(e);
    }
  }

  Future<bool> addClassroom(String roomName, String bleUuid) async {
    try {
      final res = await _api.post('/admin/classrooms',
          data: {'room_name': roomName, 'ble_uuid': bleUuid});
      classrooms.add(ClassroomModel.fromJson(res.data));
      _setSuccess('Classroom created');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> editClassroom(int id, String roomName, String bleUuid) async {
    try {
      await _api.put('/admin/classrooms/$id',
          data: {'room_name': roomName, 'ble_uuid': bleUuid});
      _setSuccess('Classroom updated');
      await fetchClassrooms();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> deleteClassroom(int id) async {
    try {
      await _api.delete('/admin/classrooms/$id');
      classrooms.removeWhere((c) => c.id == id);
      _setSuccess('Classroom deleted');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<void> fetchSubjects() async {
    try {
      final res = await _api.get('/admin/subjects');
      subjects.value =
          (res.data as List).map((e) => SubjectModel.fromJson(e)).toList();
    } catch (e) {
      _setError(e);
    }
  }

  Future<bool> addSubject(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/admin/subjects', data: data);
      subjects.add(SubjectModel.fromJson(res.data));
      _setSuccess('Subject created');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> editSubject(int id, Map<String, dynamic> data) async {
    try {
      await _api.put('/admin/subjects/$id', data: data);
      _setSuccess('Subject updated');
      await fetchSubjects();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> deleteSubject(int id) async {
    try {
      await _api.delete('/admin/subjects/$id');
      subjects.removeWhere((s) => s.id == id);
      _setSuccess('Subject deleted');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // SESSIONS
  // ══════════════════════════════════════════════════════════

  Future<void> fetchSessions({
    bool? isActive,
    int skip = 0,
    int limit = 50,
  }) async {
    isLoading.value = true;
    try {
      final res = await _api.get('/admin/sessions', queryParameters: {
        if (isActive != null) 'is_active': isActive,
        'skip': skip,
        'limit': limit,
      });
      sessionsTotal.value = res.data['total'] ?? 0;
      sessions.value = (res.data['items'] as List)
          .map((e) => AdminSessionModel.fromJson(e))
          .toList();
    } catch (e) {
      _setError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> closeSession(int id) async {
    try {
      await _api.post('/admin/sessions/$id/close');
      final idx = sessions.indexWhere((s) => s.id == id);
      if (idx != -1) {
        final s = sessions[idx];
        sessions[idx] = AdminSessionModel(
          id: s.id, facultyId: s.facultyId, classroomId: s.classroomId,
          subjectId: s.subjectId, isActive: false,
          startTime: s.startTime, endTime: DateTime.now(),
          attendanceCount: s.attendanceCount,
        );
      }
      _setSuccess('Session closed');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // ATTENDANCE
  // ══════════════════════════════════════════════════════════

  Future<void> fetchAttendance({
    int? studentId,
    int? sessionId,
    String? department,
    String? status,
    String? dateFrom,
    String? dateTo,
    int skip = 0,
    int limit = 50,
  }) async {
    isLoading.value = true;
    try {
      final res = await _api.get('/admin/attendance', queryParameters: {
        if (studentId != null) 'student_id': studentId,
        if (sessionId != null) 'session_id': sessionId,
        if (department != null) 'department': department,
        if (status != null) 'att_status': status,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        'skip': skip,
        'limit': limit,
      });
      attendanceTotal.value = res.data['total'] ?? 0;
      attendanceRecords.value = (res.data['items'] as List)
          .map((e) => AdminAttendanceRecord.fromJson(e))
          .toList();
    } catch (e) {
      _setError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> editAttendanceStatus(int id, String newStatus) async {
    try {
      await _api.patch('/admin/attendance/$id', data: {'status': newStatus});
      final idx = attendanceRecords.indexWhere((a) => a.id == id);
      if (idx != -1) {
        final r = attendanceRecords[idx];
        attendanceRecords[idx] = AdminAttendanceRecord(
          id: r.id, studentId: r.studentId, studentName: r.studentName,
          regNo: r.regNo, sessionId: r.sessionId, date: r.date,
          time: r.time, status: newStatus, rssi: r.rssi,
          faceConfidence: r.faceConfidence,
          livenessVerified: r.livenessVerified,
          attendanceMethod: r.attendanceMethod, markedAt: r.markedAt,
        );
      }
      _setSuccess('Attendance updated');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> deleteAttendance(int id) async {
    try {
      await _api.delete('/admin/attendance/$id');
      attendanceRecords.removeWhere((a) => a.id == id);
      _setSuccess('Record deleted');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> markManualAttendance(
      int studentId, int sessionId, String status) async {
    try {
      await _api.post('/admin/attendance/manual', data: {
        'student_id': studentId,
        'session_id': sessionId,
        'status': status,
      });
      _setSuccess('Attendance marked manually');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // FACE MANAGEMENT
  // ══════════════════════════════════════════════════════════

  Future<void> fetchFaceList({String? search, String? department,
      int skip = 0, int limit = 50}) async {
    isLoading.value = true;
    try {
      final res = await _api.get('/admin/faces', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (department != null) 'department': department,
        'skip': skip,
        'limit': limit,
      });
      faceTotal.value = res.data['total'] ?? 0;
      faceList.value = List<Map<String, dynamic>>.from(res.data['items']);
    } catch (e) {
      _setError(e);
    } finally {
      isLoading.value = false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // DEVICE SECURITY
  // ══════════════════════════════════════════════════════════

  Future<void> fetchDeviceLogs({String? search, int? sessionId,
      int skip = 0, int limit = 50}) async {
    isLoading.value = true;
    try {
      final res = await _api.get('/admin/device-logs', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (sessionId != null) 'session_id': sessionId,
        'skip': skip,
        'limit': limit,
      });
      deviceLogsTotal.value = res.data['total'] ?? 0;
      deviceLogs.value = (res.data['items'] as List)
          .map((e) => DeviceLogModel.fromJson(e))
          .toList();
    } catch (e) {
      _setError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchDuplicateDevices() async {
    try {
      final res = await _api.get('/admin/device-logs/duplicates');
      duplicateDevices.value = List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      _setError(e);
    }
  }

  Future<void> fetchDeviceBindings({String? search}) async {
    try {
      final res = await _api.get('/admin/device-bindings', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      });
      deviceBindings.value = (res.data['items'] as List)
          .map((e) => DeviceBindingModel.fromJson(e))
          .toList();
    } catch (e) {
      _setError(e);
    }
  }

  Future<bool> removeDeviceBinding(int bindingId) async {
    try {
      await _api.delete('/admin/device-bindings/$bindingId');
      deviceBindings.removeWhere((b) => b.id == bindingId);
      _setSuccess('Device binding removed');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> removeStudentDeviceBinding(int studentId) async {
    try {
      await _api.delete('/admin/students/$studentId/device-binding');
      deviceBindings.removeWhere((b) => b.studentId == studentId);
      _setSuccess('Device binding removed');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // BLE BEACONS
  // ══════════════════════════════════════════════════════════

  Future<void> fetchBleBeacons() async {
    try {
      final res = await _api.get('/admin/ble-beacons');
      bleBeacons.value =
          (res.data as List).map((e) => BleBeaconModel.fromJson(e)).toList();
    } catch (e) {
      _setError(e);
    }
  }

  Future<bool> addBleBeacon(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/admin/ble-beacons', data: data);
      bleBeacons.add(BleBeaconModel.fromJson(res.data));
      _setSuccess('BLE beacon added');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> updateBleBeacon(int id, Map<String, dynamic> data) async {
    try {
      final res = await _api.put('/admin/ble-beacons/$id', data: data);
      final idx = bleBeacons.indexWhere((b) => b.id == id);
      if (idx != -1) bleBeacons[idx] = BleBeaconModel.fromJson(res.data);
      _setSuccess('BLE beacon updated');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<void> toggleBleBeacon(int id) async {
    try {
      final res = await _api.patch('/admin/ble-beacons/$id/toggle');
      final isActive = res.data['is_active'] as bool;
      final idx = bleBeacons.indexWhere((b) => b.id == id);
      if (idx != -1) {
        final b = bleBeacons[idx];
        bleBeacons[idx] = BleBeaconModel(
          id: b.id, classroomId: b.classroomId, beaconUuid: b.beaconUuid,
          beaconName: b.beaconName, rssiThreshold: b.rssiThreshold,
          txPower: b.txPower, isActive: isActive, lastSeenAt: b.lastSeenAt,
        );
      }
    } catch (e) {
      _setError(e);
    }
  }

  Future<bool> deleteBleBeacon(int id) async {
    try {
      await _api.delete('/admin/ble-beacons/$id');
      bleBeacons.removeWhere((b) => b.id == id);
      _setSuccess('BLE beacon deleted');
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // SETTINGS
  // ══════════════════════════════════════════════════════════

  Future<void> fetchSettings() async {
    isLoading.value = true;
    try {
      final res = await _api.get('/admin/settings');
      final raw = res.data as Map<String, dynamic>;
      settings.value = raw.map((cat, items) => MapEntry(
        cat,
        (items as List).map((e) => SystemSettingModel.fromJson(e)).toList(),
      ));
    } catch (e) {
      _setError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateSettings(Map<String, String> updates) async {
    try {
      await _api.patch('/admin/settings', data: updates);
      _setSuccess('Settings saved');
      await fetchSettings();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // AUDIT LOGS
  // ══════════════════════════════════════════════════════════

  Future<void> fetchAuditLogs({
    String? action,
    String? targetType,
    String? dateFrom,
    String? dateTo,
    int skip = 0,
    int limit = 50,
  }) async {
    isLoading.value = true;
    try {
      final res = await _api.get('/admin/audit-logs', queryParameters: {
        if (action != null && action.isNotEmpty) 'action': action,
        if (targetType != null) 'target_type': targetType,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        'skip': skip,
        'limit': limit,
      });
      auditLogsTotal.value = res.data['total'] ?? 0;
      auditLogs.value = (res.data['items'] as List)
          .map((e) => AuditLogModel.fromJson(e))
          .toList();
    } catch (e) {
      _setError(e);
    } finally {
      isLoading.value = false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // EXPORT
  // ══════════════════════════════════════════════════════════

  Future<void> exportReport(String fmt,
      {String period = 'monthly', String? department}) async {
    try {
      await _api.get('/admin/export/$fmt', queryParameters: {
        'period': period,
        if (department != null) 'department': department,
      });
      _setSuccess('Report exported');
    } catch (e) {
      _setError(e);
    }
  }
}
