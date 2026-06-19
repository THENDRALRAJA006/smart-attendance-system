// ============================================================
// SmartAttend — Admin Controller
// System analytics, manage users/classrooms/subjects
// ============================================================

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../core/network/api_client.dart';
import '../models/models.dart';

class AdminController extends GetxController {
  static AdminController get to => Get.find();

  final ApiClient _api = ApiClient();

  // ─── State ──────────────────────────────────────────────
  final RxInt totalStudents = 0.obs;
  final RxInt totalFaculty = 0.obs;
  final RxInt totalDepartments = 0.obs;
  final RxInt totalClassrooms = 0.obs;
  final RxDouble systemAttendanceRate = 0.0.obs;
  final RxList<StudentModel> students = <StudentModel>[].obs;
  final RxList<FacultyModel> faculty = <FacultyModel>[].obs;
  final RxList<ClassroomModel> classrooms = <ClassroomModel>[].obs;
  final RxList<SubjectModel> subjects = <SubjectModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAnalytics();
  }

  // ─── Fetch Analytics ─────────────────────────────────────
  Future<void> fetchAnalytics() async {
    isLoading.value = true;
    try {
      final response = await _api.get('/admin/dashboard');
      final data = response.data as Map<String, dynamic>;
      totalStudents.value = data['total_students'];
      totalFaculty.value = data['total_faculty'];
      totalDepartments.value = data['total_departments'];
      totalClassrooms.value = data['total_classrooms'];
      systemAttendanceRate.value = (data['system_attendance_rate'] as num).toDouble();
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Fetch Students ──────────────────────────────────────
  Future<void> fetchStudents({String? search, String? department}) async {
    isLoading.value = true;
    try {
      final response = await _api.get(
        '/admin/students',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (department != null) 'department': department,
        },
      );
      students.value = (response.data as List)
          .map((e) => StudentModel.fromJson(e))
          .toList();
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Delete Student ──────────────────────────────────────
  Future<void> deleteStudent(int id) async {
    try {
      await _api.delete('/admin/students/$id');
      students.removeWhere((s) => s.id == id);
      totalStudents.value--;
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    }
  }

  // ─── Fetch Faculty ───────────────────────────────────────
  Future<void> fetchFaculty() async {
    isLoading.value = true;
    try {
      final response = await _api.get('/admin/faculty');
      faculty.value = (response.data as List)
          .map((e) => FacultyModel.fromJson(e))
          .toList();
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Fetch Classrooms ────────────────────────────────────
  Future<void> fetchClassrooms() async {
    isLoading.value = true;
    try {
      final response = await _api.get('/admin/classrooms');
      classrooms.value = (response.data as List)
          .map((e) => ClassroomModel.fromJson(e))
          .toList();
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Add Classroom ────────────────────────────────────────
  Future<void> addClassroom(String roomName, String bleUuid) async {
    try {
      final response = await _api.post('/admin/classrooms', data: {
        'room_name': roomName,
        'ble_uuid': bleUuid,
      });
      classrooms.add(ClassroomModel.fromJson(response.data));
      totalClassrooms.value++;
    } on DioException catch (e) {
      errorMessage.value = ApiException.fromDioError(e).message;
    }
  }
}
