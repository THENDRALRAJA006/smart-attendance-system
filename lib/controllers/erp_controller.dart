// ============================================================
// SmartAttend — ERP Controller (v13)
// ============================================================

import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/erp_models.dart';
import '../models/timetable_models.dart';

class ErpController extends GetxController {
  static ErpController get to => Get.find();

  ApiClient get _api => ApiClient.to;

  // ── State ──────────────────────────────────────────────
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Departments
  final RxList<ErpDepartment> departments = <ErpDepartment>[].obs;
  final RxMap<String, List<DepartmentSection>> departmentSections = <String, List<DepartmentSection>>{}.obs;

  // Subjects
  final RxList<ErpSubject> subjects = <ErpSubject>[].obs;

  // Faculty
  final RxList<ErpFacultyModel> facultyList = <ErpFacultyModel>[].obs;

  // Classrooms
  final RxList<ErpClassroomModel> classrooms = <ErpClassroomModel>[].obs;

  // Period Timings
  final RxList<PeriodTiming> periodTimings = <PeriodTiming>[].obs;

  // Timetable Slot Grid: Map<Day, List<Slot>>
  final RxMap<String, List<WeeklyTimetableSlotModel>> timetableGrid = <String, List<WeeklyTimetableSlotModel>>{}.obs;

  // Student & Teacher timetable
  final Rx<StudentTimetableModel?> studentTimetable = Rx(null);
  final Rx<StudentTimetableModel?> teacherTimetable = Rx(null);
  final Rx<TimetableAutoFill?> autoFill = Rx(null);

  // Selected filters for grid editor
  final Rxn<ErpDepartment> selectedDept = Rxn(null);
  final RxInt selectedYear = 1.obs;
  final RxString selectedSection = 'A'.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDepartments();
    fetchPeriodTimings();
    fetchClassrooms();
  }

  // ── Departments ────────────────────────────────────────
  Future<void> fetchDepartments() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final resp = await _api.get(AppConstants.apiErpDepartments);
      final list = (resp.data['departments'] as List? ?? []);
      departments.value = list.map((e) => ErpDepartment.fromJson(e)).toList();
      if (departments.isNotEmpty && selectedDept.value == null) {
        selectedDept.value = departments.first;
      }
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createDepartment(String name, String shortName, String degreeType) async {
    isLoading.value = true;
    try {
      await _api.post(AppConstants.apiErpDepartments, data: {
        'name': name,
        'short_name': shortName,
        'degree_type': degreeType,
      });
      await fetchDepartments();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateDepartment(int id, String name, String shortName, String degreeType) async {
    isLoading.value = true;
    try {
      await _api.put('${AppConstants.apiErpDepartments}/$id', data: {
        'name': name,
        'short_name': shortName,
        'degree_type': degreeType,
      });
      await fetchDepartments();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteDepartment(int id) async {
    try {
      await _api.delete('${AppConstants.apiErpDepartments}/$id');
      await fetchDepartments();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  Future<bool> seedDepartments() async {
    isLoading.value = true;
    try {
      await _api.post('${AppConstants.apiErpDepartments}/seed');
      await fetchDepartments();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Sections per department
  Future<void> fetchSections(int deptId) async {
    try {
      final resp = await _api.get('${AppConstants.apiErpDepartments}/$deptId/sections');
      final list = (resp.data['sections'] as List? ?? []);
      departmentSections[deptId.toString()] = list.map((e) => DepartmentSection.fromJson(e)).toList();
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
    }
  }

  Future<bool> addSection(int deptId, int year, String section) async {
    try {
      await _api.post('${AppConstants.apiErpDepartments}/$deptId/sections', data: {
        'year': year,
        'section': section,
      });
      await fetchSections(deptId);
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  Future<bool> deleteSection(int deptId, int sectionId) async {
    try {
      await _api.delete('${AppConstants.apiErpDepartments}/$deptId/sections/$sectionId');
      await fetchSections(deptId);
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  // ── Subjects ───────────────────────────────────────────
  Future<void> fetchSubjects({int? departmentId, int? year}) async {
    isLoading.value = true;
    try {
      final params = <String, dynamic>{};
      if (departmentId != null) params['department_id'] = departmentId;
      if (year != null) params['year'] = year;

      final resp = await _api.get(AppConstants.apiErpSubjects, queryParameters: params);
      final list = (resp.data['subjects'] as List? ?? []);
      subjects.value = list.map((e) => ErpSubject.fromJson(e)).toList();
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createSubject(String name, String? code, int deptId, int? year, int credits, String type) async {
    try {
      await _api.post(AppConstants.apiErpSubjects, data: {
        'subject_name': name,
        'subject_code': code,
        'department_id': deptId,
        'year': year,
        'credits': credits,
        'subject_type': type,
      });
      await fetchSubjects(departmentId: deptId);
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  Future<bool> deleteSubject(int id, int deptId) async {
    try {
      await _api.delete('${AppConstants.apiErpSubjects}/$id');
      await fetchSubjects(departmentId: deptId);
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  // ── Faculty ────────────────────────────────────────────
  Future<void> fetchFaculty({String? department}) async {
    isLoading.value = true;
    try {
      final params = <String, dynamic>{};
      if (department != null) params['department'] = department;

      final resp = await _api.get(AppConstants.apiErpFaculty, queryParameters: params);
      final list = (resp.data['faculty'] as List? ?? []);
      facultyList.value = list.map((e) => ErpFacultyModel.fromJson(e)).toList();
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createFaculty(String name, String email, String? empId, String? dept, String? desig, String? phone) async {
    try {
      await _api.post(AppConstants.apiErpFaculty, data: {
        'name': name,
        'email': email,
        'employee_id': empId,
        'department': dept,
        'designation': desig,
        'phone_number': phone,
      });
      await fetchFaculty();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  Future<bool> deleteFaculty(int id) async {
    try {
      await _api.delete('${AppConstants.apiErpFaculty}/$id');
      await fetchFaculty();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  // ── Classrooms ─────────────────────────────────────────
  Future<void> fetchClassrooms() async {
    try {
      final resp = await _api.get(AppConstants.apiErpClassrooms);
      final list = (resp.data['classrooms'] as List? ?? []);
      classrooms.value = list.map((e) => ErpClassroomModel.fromJson(e)).toList();
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
    }
  }

  Future<bool> createClassroom(String roomName, String? bleUuid) async {
    try {
      await _api.post(AppConstants.apiErpClassrooms, data: {
        'room_name': roomName,
        'ble_uuid': bleUuid,
      });
      await fetchClassrooms();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  Future<bool> deleteClassroom(int id) async {
    try {
      await _api.delete('${AppConstants.apiErpClassrooms}/$id');
      await fetchClassrooms();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  Future<bool> seedClassrooms() async {
    try {
      await _api.post('${AppConstants.apiErpClassrooms}/seed');
      await fetchClassrooms();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  // ── Period Timings ─────────────────────────────────────
  Future<void> fetchPeriodTimings() async {
    try {
      final resp = await _api.get(AppConstants.apiErpPeriodTimings);
      final list = (resp.data['period_timings'] as List? ?? []);
      periodTimings.value = list.map((e) => PeriodTiming.fromJson(e)).toList();
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
    }
  }

  Future<bool> createPeriodTiming(String label, String start, String end, String type, int order) async {
    try {
      await _api.post(AppConstants.apiErpPeriodTimings, data: {
        'label': label,
        'start_time': start,
        'end_time': end,
        'period_type': type,
        'order_index': order,
      });
      await fetchPeriodTimings();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  Future<bool> deletePeriodTiming(int id) async {
    try {
      await _api.delete('${AppConstants.apiErpPeriodTimings}/$id');
      await fetchPeriodTimings();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  Future<bool> seedPeriodTimings() async {
    try {
      await _api.post('${AppConstants.apiErpPeriodTimings}/seed');
      await fetchPeriodTimings();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  // ── Timetable Slot Grid ─────────────────────────────────
  Future<void> fetchTimetableGrid({int? deptId, int? year, String? section}) async {
    final dId = deptId ?? selectedDept.value?.id;
    final yr = year ?? selectedYear.value;
    final sec = section ?? selectedSection.value;
    if (dId == null) return;

    isLoading.value = true;
    errorMessage.value = '';
    try {
      final resp = await _api.get(
        AppConstants.apiErpTimetable,
        queryParameters: {
          'department_id': dId,
          'year': yr,
          'section': sec,
        },
      );
      final gridRaw = resp.data['grid'] as Map<String, dynamic>? ?? {};
      final map = gridRaw.map((day, list) => MapEntry(
        day,
        (list as List).map((e) => WeeklyTimetableSlotModel.fromJson(e)).toList(),
      ));
      timetableGrid.value = map;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveSlot({
    required int deptId,
    required int year,
    required String section,
    required String dayOfWeek,
    required int periodTimingId,
    int? subjectId,
    int? facultyId,
    int? classroomId,
    required String classType,
  }) async {
    try {
      await _api.post('${AppConstants.apiErpTimetable}/slot', data: {
        'department_id': deptId,
        'year': year,
        'section': section,
        'day_of_week': dayOfWeek,
        'period_timing_id': periodTimingId,
        'erp_subject_id': subjectId,
        'faculty_id': facultyId,
        'classroom_id': classroomId,
        'class_type': classType,
      });
      await fetchTimetableGrid(deptId: deptId, year: year, section: section);
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  Future<bool> deleteSlot(int slotId) async {
    try {
      await _api.delete('${AppConstants.apiErpTimetable}/slot/$slotId');
      await fetchTimetableGrid();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    }
  }

  Future<bool> duplicateTimetable({
    required int sourceDeptId,
    required int sourceYear,
    required String sourceSection,
    required int targetDeptId,
    required int targetYear,
    required String targetSection,
  }) async {
    isLoading.value = true;
    try {
      await _api.post('${AppConstants.apiErpTimetable}/duplicate', data: {
        'source_department_id': sourceDeptId,
        'source_year': sourceYear,
        'source_section': sourceSection,
        'target_department_id': targetDeptId,
        'target_year': targetYear,
        'target_section': targetSection,
      });
      await fetchTimetableGrid(deptId: targetDeptId, year: targetYear, section: targetSection);
      return true;
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ── Student & Teacher views ─────────────────────────────
  Future<void> fetchStudentTimetable() async {
    isLoading.value = true;
    try {
      final resp = await _api.get(AppConstants.apiErpTimetableStudent);
      studentTimetable.value = StudentTimetableModel.fromJson(resp.data);
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchTeacherTimetable() async {
    isLoading.value = true;
    try {
      final resp = await _api.get(AppConstants.apiErpTimetableTeacher);
      teacherTimetable.value = StudentTimetableModel.fromJson(resp.data);
    } on DioException catch (e) {
      errorMessage.value = _extractError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<TimetableAutoFill?> fetchCurrentPeriod() async {
    try {
      final resp = await _api.get(AppConstants.apiErpCurrentPeriod);
      final fill = TimetableAutoFill.fromJson(resp.data);
      autoFill.value = fill;
      return fill;
    } on DioException {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────
  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return data['detail']?.toString() ?? e.message ?? 'Error';
      }
    } catch (_) {}
    return e.message ?? 'Unknown error';
  }
}
