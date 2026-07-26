// ============================================================
// SmartAttend — ERP Models (v13)
// ============================================================

class ErpDepartment {
  final int id;
  final String name;
  final String shortName;
  final String degreeType;
  final bool isActive;
  final String? createdAt;

  ErpDepartment({
    required this.id,
    required this.name,
    required this.shortName,
    this.degreeType = 'B.E.',
    this.isActive = true,
    this.createdAt,
  });

  factory ErpDepartment.fromJson(Map<String, dynamic> j) => ErpDepartment(
        id:          (j['id'] as num?)?.toInt() ?? 0,
        name:        j['name'] as String? ?? '',
        shortName:   j['short_name'] as String? ?? '',
        degreeType:  j['degree_type'] as String? ?? 'B.E.',
        isActive:    j['is_active'] as bool? ?? true,
        createdAt:   j['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id':          id,
        'name':        name,
        'short_name':  shortName,
        'degree_type': degreeType,
        'is_active':   isActive,
      };
}

class DepartmentSection {
  final int id;
  final int departmentId;
  final int year;
  final String section;
  final int? classroomId;
  final int? studentCount;
  final String? classroomName;

  DepartmentSection({
    required this.id,
    required this.departmentId,
    required this.year,
    required this.section,
    this.classroomId,
    this.studentCount,
    this.classroomName,
  });

  factory DepartmentSection.fromJson(Map<String, dynamic> j) => DepartmentSection(
        id:            (j['id'] as num?)?.toInt() ?? 0,
        departmentId:  (j['department_id'] as num?)?.toInt() ?? 0,
        year:          (j['year'] as num?)?.toInt() ?? 1,
        section:       j['section'] as String? ?? 'A',
        classroomId:   (j['classroom_id'] as num?)?.toInt(),
        studentCount:  (j['student_count'] as num?)?.toInt(),
        classroomName: j['classroom_name'] as String?,
      );
}

class PeriodTiming {
  final int id;
  final String label;
  final String startTime;
  final String endTime;
  final String periodType; // Theory | Lab | Break | Lunch | Tutorial | Elective
  final int orderIndex;
  final bool isActive;

  PeriodTiming({
    required this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
    this.periodType = 'Theory',
    required this.orderIndex,
    this.isActive = true,
  });

  factory PeriodTiming.fromJson(Map<String, dynamic> j) => PeriodTiming(
        id:          (j['id'] as num?)?.toInt() ?? 0,
        label:       j['label'] as String? ?? '',
        startTime:   j['start_time'] as String? ?? '',
        endTime:     j['end_time'] as String? ?? '',
        periodType:  j['period_type'] as String? ?? 'Theory',
        orderIndex:  (j['order_index'] as num?)?.toInt() ?? 0,
        isActive:    j['is_active'] as bool? ?? true,
      );

  bool get isNonTeaching => ['Break', 'Lunch'].contains(periodType);
}

class ErpSubject {
  final int id;
  final String subjectName;
  final String? subjectCode;
  final int departmentId;
  final String? departmentName;
  final String? departmentShort;
  final int? year;
  final int? credits;
  final String subjectType; // Theory | Lab | Elective | Tutorial
  final bool isActive;

  ErpSubject({
    required this.id,
    required this.subjectName,
    this.subjectCode,
    required this.departmentId,
    this.departmentName,
    this.departmentShort,
    this.year,
    this.credits,
    this.subjectType = 'Theory',
    this.isActive = true,
  });

  factory ErpSubject.fromJson(Map<String, dynamic> j) => ErpSubject(
        id:              (j['id'] as num?)?.toInt() ?? 0,
        subjectName:     j['subject_name'] as String? ?? '',
        subjectCode:     j['subject_code'] as String?,
        departmentId:    (j['department_id'] as num?)?.toInt() ?? 0,
        departmentName:  j['department_name'] as String?,
        departmentShort: j['department_short'] as String?,
        year:            (j['year'] as num?)?.toInt(),
        credits:         (j['credits'] as num?)?.toInt(),
        subjectType:     j['subject_type'] as String? ?? 'Theory',
        isActive:        j['is_active'] as bool? ?? true,
      );
}

class ErpFacultyModel {
  final int id;
  final String name;
  final String email;
  final String? department;
  final String? phoneNumber;
  final String? employeeId;
  final String? designation;
  final bool isActive;

  ErpFacultyModel({
    required this.id,
    required this.name,
    required this.email,
    this.department,
    this.phoneNumber,
    this.employeeId,
    this.designation,
    this.isActive = true,
  });

  factory ErpFacultyModel.fromJson(Map<String, dynamic> j) => ErpFacultyModel(
        id:          (j['id'] as num?)?.toInt() ?? 0,
        name:        j['name'] as String? ?? '',
        email:       j['email'] as String? ?? '',
        department:  j['department'] as String?,
        phoneNumber: j['phone_number'] as String?,
        employeeId:  j['employee_id'] as String?,
        designation: j['designation'] as String?,
        isActive:    j['is_active'] as bool? ?? true,
      );
}

class ErpClassroomModel {
  final int id;
  final String roomName;
  final String? bleUuid;

  ErpClassroomModel({
    required this.id,
    required this.roomName,
    this.bleUuid,
  });

  factory ErpClassroomModel.fromJson(Map<String, dynamic> j) => ErpClassroomModel(
        id:       (j['id'] as num?)?.toInt() ?? 0,
        roomName: j['room_name'] as String? ?? '',
        bleUuid:  j['ble_uuid'] as String?,
      );
}

class WeeklyTimetableSlotModel {
  final int id;
  final int departmentId;
  final String? departmentName;
  final String? departmentShort;
  final int year;
  final String section;
  final String dayOfWeek;
  final int periodTimingId;
  final String? periodLabel;
  final String startTime;
  final String endTime;
  final int orderIndex;
  final int? erpSubjectId;
  final String? subjectName;
  final String? subjectCode;
  final int? facultyId;
  final String? facultyName;
  final int? classroomId;
  final String? roomName;
  final String classType;
  final String? status; // active | upcoming | completed

  WeeklyTimetableSlotModel({
    required this.id,
    required this.departmentId,
    this.departmentName,
    this.departmentShort,
    required this.year,
    required this.section,
    required this.dayOfWeek,
    required this.periodTimingId,
    this.periodLabel,
    required this.startTime,
    required this.endTime,
    required this.orderIndex,
    this.erpSubjectId,
    this.subjectName,
    this.subjectCode,
    this.facultyId,
    this.facultyName,
    this.classroomId,
    this.roomName,
    this.classType = 'Theory',
    this.status,
  });

  factory WeeklyTimetableSlotModel.fromJson(Map<String, dynamic> j) =>
      WeeklyTimetableSlotModel(
        id:              (j['id'] as num?)?.toInt() ?? 0,
        departmentId:    (j['department_id'] as num?)?.toInt() ?? 0,
        departmentName:  j['department_name'] as String?,
        departmentShort: j['department_short'] as String?,
        year:            (j['year'] as num?)?.toInt() ?? 1,
        section:         j['section'] as String? ?? 'A',
        dayOfWeek:       j['day_of_week'] as String? ?? '',
        periodTimingId:  (j['period_timing_id'] as num?)?.toInt() ?? 0,
        periodLabel:     j['period_label'] as String?,
        startTime:       j['start_time'] as String? ?? '',
        endTime:         j['end_time'] as String? ?? '',
        orderIndex:      (j['order_index'] as num?)?.toInt() ?? 0,
        erpSubjectId:    (j['erp_subject_id'] as num?)?.toInt(),
        subjectName:     j['subject_name'] as String?,
        subjectCode:     j['subject_code'] as String?,
        facultyId:       (j['faculty_id'] as num?)?.toInt(),
        facultyName:     j['faculty_name'] as String?,
        classroomId:     (j['classroom_id'] as num?)?.toInt(),
        roomName:        j['room_name'] as String?,
        classType:       j['class_type'] as String? ?? 'Theory',
        status:          j['status'] as String?,
      );

  bool get isActive      => status == 'active';
  bool get isCompleted   => status == 'completed';
  bool get isUpcoming    => status == 'upcoming';
  bool get isNonTeaching => ['Break', 'Lunch', 'Free'].contains(classType);
}
