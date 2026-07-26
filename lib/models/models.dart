// ============================================================
// SmartAttend — Data Models
// ============================================================

// ─── Student Model ──────────────────────────────────────────
class StudentModel {
  final int id;
  final String name;
  final String regNo;
  final String department;
  final int year;
  final String section;
  final String email;
  final String? faceId;
  final String? faceImageUrl;
  final double? attendancePercentage;
  final int? totalClasses;
  final int? attendedClasses;
  final DateTime createdAt;

  StudentModel({
    required this.id,
    required this.name,
    required this.regNo,
    required this.department,
    required this.year,
    required this.section,
    required this.email,
    this.faceId,
    this.faceImageUrl,
    this.attendancePercentage,
    this.totalClasses,
    this.attendedClasses,
    required this.createdAt,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      name: json['name'],
      regNo: json['reg_no'],
      department: json['department'],
      year: json['year'],
      section: json['section'],
      email: json['email'],
      faceId: json['face_id'],
      faceImageUrl: json['face_image_url'],
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble(),
      totalClasses: json['total_classes'] as int?,
      attendedClasses: json['attended_classes'] as int?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'reg_no': regNo,
        'department': department,
        'year': year,
        'section': section,
        'email': email,
        'face_id': faceId,
        'created_at': createdAt.toIso8601String(),
      };

  bool get hasFaceRegistered => faceId != null && faceId!.isNotEmpty && faceId!.startsWith('arcface');
}

// ─── Faculty Model ──────────────────────────────────────────
class FacultyModel {
  final int id;
  final String name;
  final String email;
  final String? department;
  final List<SubjectModel> subjects;

  FacultyModel({
    required this.id,
    required this.name,
    required this.email,
    this.department,
    this.subjects = const [],
  });

  factory FacultyModel.fromJson(Map<String, dynamic> json) {
    return FacultyModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      department: json['department'],
      subjects: json['subjects'] != null
          ? (json['subjects'] as List)
              .map((e) => SubjectModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'department': department,
        'subjects': subjects.map((s) => s.toJson()).toList(),
      };
}

// ─── Attendance Model ───────────────────────────────────────
class AttendanceModel {
  final int id;
  final int studentId;
  final String? studentName;
  final int classroomId;
  final String? classroomName;
  final int subjectId;
  final String? subjectName;
  final String? facultyName;  // v11
  final DateTime date;
  final String time;
  final String status; // 'present' | 'absent' | 'late'
  final int? rssi;

  AttendanceModel({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.classroomId,
    this.classroomName,
    required this.subjectId,
    this.subjectName,
    this.facultyName,
    required this.date,
    required this.time,
    required this.status,
    this.rssi,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id:           (json['id'] as num?)?.toInt() ?? 0,
      studentId:    (json['student_id'] as num?)?.toInt() ?? 0,
      studentName:  json['student_name'] as String?,
      classroomId:  (json['classroom_id'] as num?)?.toInt() ?? 0,
      classroomName: json['classroom_name'] as String?,
      subjectId:    (json['subject_id'] as num?)?.toInt() ?? 0,
      subjectName:  json['subject_name'] as String?,
      facultyName:  json['faculty_name'] as String?,
      date:         DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      time:         json['time'] as String? ?? '--:--',
      status:       json['status'] as String? ?? 'unknown',
      rssi:         (json['rssi'] as num?)?.toInt(),
    );
  }

  bool get isPresent => status == 'present';
}

// ─── Classroom Model ────────────────────────────────────────
class ClassroomModel {
  final int id;
  final String roomName;
  final String bleUuid;
  final String? attendanceCode;

  ClassroomModel({
    required this.id,
    required this.roomName,
    required this.bleUuid,
    this.attendanceCode,
  });

  factory ClassroomModel.fromJson(Map<String, dynamic> json) {
    return ClassroomModel(
      id: json['id'],
      roomName: json['room_name'],
      bleUuid: json['ble_uuid'],
      attendanceCode: json['attendance_code'],
    );
  }
}

// ─── Subject Model ──────────────────────────────────────────
class SubjectModel {
  final int id;
  final String subjectName;
  final String? subjectCode;
  final String? department;
  final int facultyId;
  final String? facultyName;

  SubjectModel({
    required this.id,
    required this.subjectName,
    this.subjectCode,
    this.department,
    required this.facultyId,
    this.facultyName,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'],
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
      department: json['department'],
      facultyId: json['faculty_id'] ?? 0,
      facultyName: json['faculty_name'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_name': subjectName,
        'subject_code': subjectCode,
        'department': department,
        'faculty_id': facultyId,
        'faculty_name': facultyName,
      };

  /// Display label: "AD23511 — Deep Learning" or just "Deep Learning"
  String get displayLabel =>
      subjectCode != null ? '$subjectCode — $subjectName' : subjectName;
}

// ─── Session Model ──────────────────────────────────────────
class SessionModel {
  final int id;
  final int classroomId;
  final String classroomName;
  final int subjectId;
  final String subjectName;
  final String? subjectCode;
  final String attendanceCode;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;

  SessionModel({
    required this.id,
    required this.classroomId,
    required this.classroomName,
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    required this.attendanceCode,
    required this.startTime,
    this.endTime,
    required this.isActive,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'],
      classroomId: json['classroom_id'],
      classroomName: json['classroom_name'],
      subjectId: json['subject_id'],
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
      attendanceCode: json['attendance_code'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      isActive: json['is_active'],
    );
  }

  /// Display label: "AD23511 — Deep Learning" or just "Deep Learning"
  String get displayLabel =>
      subjectCode != null ? '$subjectCode — $subjectName' : subjectName;
}

// ─── Dashboard Stats Model ──────────────────────────────────
class DashboardStats {
  final int totalClasses;
  final int attendedClasses;
  final double attendancePercentage;
  final List<SubjectAttendance> subjectWise;
  final List<AttendanceModel> recentHistory;
  // v11 additions
  final List<TodayScheduleEntry> todaySchedule;
  final Map<String, dynamic> quickStats;

  DashboardStats({
    required this.totalClasses,
    required this.attendedClasses,
    required this.attendancePercentage,
    required this.subjectWise,
    required this.recentHistory,
    this.todaySchedule = const [],
    this.quickStats = const {},
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalClasses: (json['total_classes'] as num?)?.toInt() ?? 0,
      attendedClasses: (json['attended_classes'] as num?)?.toInt() ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      subjectWise: (json['subject_wise'] as List? ?? [])
          .map((e) => SubjectAttendance.fromJson(e))
          .toList(),
      recentHistory: (json['recent_history'] as List? ?? [])
          .map((e) => AttendanceModel.fromJson(e))
          .toList(),
      todaySchedule: (json['today_schedule'] as List? ?? [])
          .map((e) => TodayScheduleEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      quickStats: (json['quick_stats'] as Map<String, dynamic>?) ?? {},
    );
  }

  factory DashboardStats.empty() {
    return DashboardStats(
      totalClasses: 0,
      attendedClasses: 0,
      attendancePercentage: 0.0,
      subjectWise: [],
      recentHistory: [],
    );
  }

  int get todayClasses {
    final qs = quickStats;
    if (qs.containsKey('today_classes')) {
      return (qs['today_classes'] as num?)?.toInt() ?? 0;
    }
    final today = DateTime.now();
    return recentHistory.where((a) {
      final d = a.date;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).length;
  }

  int get weekClasses {
    final qs = quickStats;
    if (qs.containsKey('week_attended')) {
      return (qs['week_attended'] as num?)?.toInt() ?? 0;
    }
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return recentHistory.where((a) => a.date.isAfter(cutoff)).length;
  }

  int get missedThisMonth =>
      (quickStats['missed_this_month'] as num?)?.toInt() ?? 0;

  int get streak {
    if (recentHistory.isEmpty) return 0;
    final days = <String>{};
    for (final a in recentHistory) {
      final d = a.date;
      days.add('${d.year}-${d.month}-${d.day}');
    }
    if (days.isEmpty) return 0;
    int count = 0;
    DateTime check = DateTime.now();
    while (true) {
      final key = '${check.year}-${check.month}-${check.day}';
      if (days.contains(key)) {
        count++;
        check = check.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return count;
  }

}

// ─── Subject Attendance Model ───────────────────────────────
class SubjectAttendance {
  final int? subjectId;         // v11 — for navigation
  final String subjectName;
  final String? subjectCode;
  final String? facultyName;
  final String? department;     // v11
  final int total;
  final int attended;
  final int absent;             // v11 — pre-computed
  final double percentage;
  final String statusLabel;     // v11 — Excellent|Good|Warning|Critical

  SubjectAttendance({
    this.subjectId,
    required this.subjectName,
    this.subjectCode,
    this.facultyName,
    this.department,
    required this.total,
    required this.attended,
    int? absent,
    required this.percentage,
    String? statusLabel,
  })  : absent = absent ?? (total - attended),
        statusLabel = statusLabel ?? _computeStatus(percentage);

  static String _computeStatus(double pct) {
    if (pct >= 90) return 'Excellent';
    if (pct >= 75) return 'Good';
    if (pct >= 60) return 'Warning';
    return 'Critical';
  }

  factory SubjectAttendance.fromJson(Map<String, dynamic> json) {
    return SubjectAttendance(
      subjectId:   (json['subject_id'] as num?)?.toInt(),
      subjectName: json['subject_name'] ?? '',
      subjectCode: json['subject_code'],
      facultyName: json['faculty_name'],
      department:  json['department'],
      total:       (json['total'] as num?)?.toInt() ?? 0,
      attended:    (json['attended'] as num?)?.toInt() ?? 0,
      absent:      (json['absent'] as num?)?.toInt(),
      percentage:  (json['percentage'] as num?)?.toDouble() ?? 0.0,
      statusLabel: json['status_label'],
    );
  }

  bool get isBelowThreshold => percentage < 75.0;

  String get displayLabel =>
      subjectCode != null ? '$subjectCode — $subjectName' : subjectName;
}

// ════════════════════════════════════════════════════════════
// ADMIN MODELS
// ════════════════════════════════════════════════════════════

// ─── Admin Dashboard Stats ──────────────────────────────────
class AdminDashboardStats {
  final int totalStudents;
  final int totalFaculty;
  final int totalDepartments;
  final int totalClassrooms;
  final int totalSessions;
  final int activeSessions;
  final int todayPresent;
  final int todayAbsent;
  final int todayManualReview;
  final int todayTotal;
  final int registeredFaces;
  final int registeredDeviceIds;
  final int activeBleDevices;
  final double systemAttendanceRate;
  final List<MonthlyTrend> monthlyTrends;
  final List<AuditLogModel> recentActivity;

  AdminDashboardStats({
    required this.totalStudents,
    required this.totalFaculty,
    required this.totalDepartments,
    required this.totalClassrooms,
    required this.totalSessions,
    required this.activeSessions,
    required this.todayPresent,
    required this.todayAbsent,
    required this.todayManualReview,
    required this.todayTotal,
    required this.registeredFaces,
    required this.registeredDeviceIds,
    required this.activeBleDevices,
    required this.systemAttendanceRate,
    required this.monthlyTrends,
    required this.recentActivity,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalStudents:        (json['total_students'] as num?)?.toInt() ?? 0,
      totalFaculty:         (json['total_faculty'] as num?)?.toInt() ?? 0,
      totalDepartments:     (json['total_departments'] as num?)?.toInt() ?? 0,
      totalClassrooms:      (json['total_classrooms'] as num?)?.toInt() ?? 0,
      totalSessions:        (json['total_sessions'] as num?)?.toInt() ?? 0,
      activeSessions:       (json['active_sessions'] as num?)?.toInt() ?? 0,
      todayPresent:         (json['today_present'] as num?)?.toInt() ?? 0,
      todayAbsent:          (json['today_absent'] as num?)?.toInt() ?? 0,
      todayManualReview:    (json['today_manual_review'] as num?)?.toInt() ?? 0,
      todayTotal:           (json['today_total'] as num?)?.toInt() ?? 0,
      registeredFaces:      (json['registered_faces'] as num?)?.toInt() ?? 0,
      registeredDeviceIds:  (json['registered_device_ids'] as num?)?.toInt() ?? 0,
      activeBleDevices:     (json['active_ble_devices'] as num?)?.toInt() ?? 0,
      systemAttendanceRate: (json['system_attendance_rate'] as num?)?.toDouble() ?? 0.0,
      monthlyTrends:        (json['monthly_trends'] as List? ?? [])
                              .map((e) => MonthlyTrend.fromJson(e)).toList(),
      recentActivity:       (json['recent_activity'] as List? ?? [])
                              .map((e) => AuditLogModel.fromJson(e)).toList(),
    );
  }

  factory AdminDashboardStats.empty() => AdminDashboardStats(
    totalStudents: 0, totalFaculty: 0, totalDepartments: 0,
    totalClassrooms: 0, totalSessions: 0, activeSessions: 0,
    todayPresent: 0, todayAbsent: 0, todayManualReview: 0, todayTotal: 0,
    registeredFaces: 0, registeredDeviceIds: 0, activeBleDevices: 0,
    systemAttendanceRate: 0.0, monthlyTrends: [], recentActivity: [],
  );
}

class MonthlyTrend {
  final String month;
  final int total;
  final int present;
  final double rate;

  MonthlyTrend({required this.month, required this.total, required this.present, required this.rate});

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) => MonthlyTrend(
    month:   json['month'] ?? '',
    total:   (json['total'] as num?)?.toInt() ?? 0,
    present: (json['present'] as num?)?.toInt() ?? 0,
    rate:    (json['rate'] as num?)?.toDouble() ?? 0.0,
  );
}

// ─── Admin Student ──────────────────────────────────────────
class AdminStudentModel {
  final int id;
  final String name;
  final String regNo;
  final String department;
  final int year;
  final String section;
  final String email;
  final String? phoneNumber;
  final bool isActive;
  final bool faceRegistered;
  final int faceCount;
  final String? faceId;
  final DateTime? createdAt;

  AdminStudentModel({
    required this.id,
    required this.name,
    required this.regNo,
    required this.department,
    required this.year,
    required this.section,
    required this.email,
    this.phoneNumber,
    required this.isActive,
    required this.faceRegistered,
    required this.faceCount,
    this.faceId,
    this.createdAt,
  });

  factory AdminStudentModel.fromJson(Map<String, dynamic> json) => AdminStudentModel(
    id:             (json['id'] as num).toInt(),
    name:           json['name'] ?? '',
    regNo:          json['reg_no'] ?? '',
    department:     json['department'] ?? '',
    year:           (json['year'] as num?)?.toInt() ?? 1,
    section:        json['section'] ?? '',
    email:          json['email'] ?? '',
    phoneNumber:    json['phone_number'],
    isActive:       json['is_active'] as bool? ?? true,
    faceRegistered: json['face_registered'] as bool? ?? false,
    faceCount:      (json['face_count'] as num?)?.toInt() ?? 0,
    faceId:         json['face_id'],
    createdAt:      json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
  );

  String get statusLabel => isActive ? 'Active' : 'Suspended';
}

// ─── Admin Faculty ──────────────────────────────────────────
class AdminFacultyModel {
  final int id;
  final String name;
  final String email;
  final String? department;
  final String? phoneNumber;
  final bool isActive;
  final DateTime? createdAt;
  final List<SubjectModel> subjects;

  AdminFacultyModel({
    required this.id,
    required this.name,
    required this.email,
    this.department,
    this.phoneNumber,
    required this.isActive,
    this.createdAt,
    this.subjects = const [],
  });

  factory AdminFacultyModel.fromJson(Map<String, dynamic> json) => AdminFacultyModel(
    id:          (json['id'] as num).toInt(),
    name:        json['name'] ?? '',
    email:       json['email'] ?? '',
    department:  json['department'],
    phoneNumber: json['phone_number'],
    isActive:    json['is_active'] as bool? ?? true,
    createdAt:   json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    subjects:    (json['subjects'] as List? ?? [])
                   .map((e) => SubjectModel.fromJson(e)).toList(),
  );
}

// ─── Admin Attendance Record ────────────────────────────────
class AdminAttendanceRecord {
  final int id;
  final int studentId;
  final String studentName;
  final String regNo;
  final int? sessionId;
  final String date;
  final String time;
  final String status;
  final int? rssi;
  final double? faceConfidence;
  final bool livenessVerified;
  final String? attendanceMethod;
  final String? markedAt;

  AdminAttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.regNo,
    this.sessionId,
    required this.date,
    required this.time,
    required this.status,
    this.rssi,
    this.faceConfidence,
    required this.livenessVerified,
    this.attendanceMethod,
    this.markedAt,
  });

  factory AdminAttendanceRecord.fromJson(Map<String, dynamic> json) => AdminAttendanceRecord(
    id:               (json['id'] as num).toInt(),
    studentId:        (json['student_id'] as num).toInt(),
    studentName:      json['student_name'] ?? '',
    regNo:            json['reg_no'] ?? '',
    sessionId:        (json['session_id'] as num?)?.toInt(),
    date:             json['date'] ?? '',
    time:             json['time'] ?? '',
    status:           json['status'] ?? '',
    rssi:             (json['rssi'] as num?)?.toInt(),
    faceConfidence:   (json['face_confidence'] as num?)?.toDouble(),
    livenessVerified: json['liveness_verified'] as bool? ?? false,
    attendanceMethod: json['attendance_method'],
    markedAt:         json['marked_at'],
  );

  bool get isPresent => status == 'present';
  bool get isManual  => attendanceMethod == 'manual';
}

// ─── Admin Session ──────────────────────────────────────────
class AdminSessionModel {
  final int id;
  final int? facultyId;
  final int? classroomId;
  final int? subjectId;
  final bool isActive;
  final DateTime startTime;
  final DateTime? endTime;
  final int attendanceCount;

  AdminSessionModel({
    required this.id,
    this.facultyId,
    this.classroomId,
    this.subjectId,
    required this.isActive,
    required this.startTime,
    this.endTime,
    required this.attendanceCount,
  });

  factory AdminSessionModel.fromJson(Map<String, dynamic> json) => AdminSessionModel(
    id:              (json['id'] as num).toInt(),
    facultyId:       (json['faculty_id'] as num?)?.toInt(),
    classroomId:     (json['classroom_id'] as num?)?.toInt(),
    subjectId:       (json['subject_id'] as num?)?.toInt(),
    isActive:        json['is_active'] as bool? ?? false,
    startTime:       DateTime.parse(json['start_time']),
    endTime:         json['end_time'] != null ? DateTime.tryParse(json['end_time']) : null,
    attendanceCount: (json['attendance_count'] as num?)?.toInt() ?? 0,
  );

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
}

// ─── Audit Log ──────────────────────────────────────────────
class AuditLogModel {
  final int id;
  final String action;
  final int? actorId;
  final String? actorName;
  final String actorRole;
  final String? targetType;
  final int? targetId;
  final String? detail;
  final String? ipAddress;
  final DateTime createdAt;

  AuditLogModel({
    required this.id,
    required this.action,
    this.actorId,
    this.actorName,
    required this.actorRole,
    this.targetType,
    this.targetId,
    this.detail,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) => AuditLogModel(
    id:         (json['id'] as num).toInt(),
    action:     json['action'] ?? '',
    actorId:    (json['actor_id'] as num?)?.toInt(),
    actorName:  json['actor_name'],
    actorRole:  json['actor_role'] ?? 'admin',
    targetType: json['target_type'],
    targetId:   (json['target_id'] as num?)?.toInt(),
    detail:     json['detail'],
    ipAddress:  json['ip_address'],
    createdAt:  DateTime.parse(json['created_at']),
  );

  String get actionLabel => action.replaceAll('.', ' › ').replaceAll('_', ' ');
  String get icon {
    if (action.contains('delete') || action.contains('remove')) return '🗑️';
    if (action.contains('suspend')) return '🔒';
    if (action.contains('activate')) return '✅';
    if (action.contains('create')) return '➕';
    if (action.contains('reset')) return '🔄';
    if (action.contains('edit') || action.contains('update')) return '✏️';
    if (action.contains('manual')) return '🖐️';
    return '📝';
  }
}

// ─── Device Log ─────────────────────────────────────────────
class DeviceLogModel {
  final int id;
  final int sessionId;
  final int studentId;
  final String studentName;
  final String regNo;
  final String deviceId;
  final DateTime attendanceTime;

  DeviceLogModel({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.regNo,
    required this.deviceId,
    required this.attendanceTime,
  });

  factory DeviceLogModel.fromJson(Map<String, dynamic> json) => DeviceLogModel(
    id:             (json['id'] as num).toInt(),
    sessionId:      (json['session_id'] as num).toInt(),
    studentId:      (json['student_id'] as num).toInt(),
    studentName:    json['student_name'] ?? '',
    regNo:          json['reg_no'] ?? '',
    deviceId:       json['device_id'] ?? '',
    attendanceTime: DateTime.parse(json['attendance_time']),
  );
}

// ─── Device Binding ─────────────────────────────────────────
class DeviceBindingModel {
  final int id;
  final int studentId;
  final String studentName;
  final String regNo;
  final String androidId;
  final String? model;
  final String? manufacturer;
  final String status;
  final DateTime registeredAt;
  final DateTime? lastLogin;

  DeviceBindingModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.regNo,
    required this.androidId,
    this.model,
    this.manufacturer,
    required this.status,
    required this.registeredAt,
    this.lastLogin,
  });

  factory DeviceBindingModel.fromJson(Map<String, dynamic> json) => DeviceBindingModel(
    id:           (json['id'] as num).toInt(),
    studentId:    (json['student_id'] as num).toInt(),
    studentName:  json['student_name'] ?? '',
    regNo:        json['reg_no'] ?? '',
    androidId:    json['android_id'] ?? '',
    model:        json['model'],
    manufacturer: json['manufacturer'],
    status:       json['status'] ?? 'active',
    registeredAt: DateTime.parse(json['registered_at']),
    lastLogin:    json['last_login'] != null ? DateTime.tryParse(json['last_login']) : null,
  );
}

// ─── System Setting ─────────────────────────────────────────
class SystemSettingModel {
  final String key;
  final String? value;
  final String category;
  final String? label;

  SystemSettingModel({required this.key, this.value, required this.category, this.label});

  factory SystemSettingModel.fromJson(Map<String, dynamic> json) => SystemSettingModel(
    key:      json['key'] ?? '',
    value:    json['value'],
    category: json['category'] ?? 'general',
    label:    json['label'],
  );
}

// ─── BLE Beacon Model ───────────────────────────────────────
class BleBeaconModel {
  final int id;
  final int classroomId;
  final String beaconUuid;
  final String beaconName;
  final int rssiThreshold;
  final int? txPower;
  final bool isActive;
  final DateTime? lastSeenAt;

  BleBeaconModel({
    required this.id,
    required this.classroomId,
    required this.beaconUuid,
    required this.beaconName,
    required this.rssiThreshold,
    this.txPower,
    required this.isActive,
    this.lastSeenAt,
  });

  factory BleBeaconModel.fromJson(Map<String, dynamic> json) => BleBeaconModel(
    id:            (json['id'] as num).toInt(),
    classroomId:   (json['classroom_id'] as num).toInt(),
    beaconUuid:    json['beacon_uuid'] ?? '',
    beaconName:    json['beacon_name'] ?? '',
    rssiThreshold: (json['rssi_threshold'] as num?)?.toInt() ?? -80,
    txPower:       (json['tx_power'] as num?)?.toInt(),
    isActive:      json['is_active'] as bool? ?? true,
    lastSeenAt:    json['last_seen_at'] != null ? DateTime.tryParse(json['last_seen_at']) : null,
  );
}


// ════════════════════════════════════════════════════════════
// TEACHER SESSION MODELS (v10)
// ════════════════════════════════════════════════════════════

class SessionStudentEntry {
  final int studentId;
  final String studentName;
  final String regNo;
  final String time;
  final String status;
  final int? rssi;
  final double? faceConfidence;
  final bool livenessVerified;
  final DateTime? markedAt;

  const SessionStudentEntry({
    required this.studentId,
    required this.studentName,
    required this.regNo,
    required this.time,
    required this.status,
    this.rssi,
    this.faceConfidence,
    this.livenessVerified = false,
    this.markedAt,
  });

  factory SessionStudentEntry.fromJson(Map<String, dynamic> json) =>
      SessionStudentEntry(
        studentId:        (json['student_id'] as num).toInt(),
        studentName:      json['student_name'] ?? '',
        regNo:            json['reg_no'] ?? '',
        time:             json['time'] ?? '',
        status:           json['status'] ?? 'present',
        rssi:             (json['rssi'] as num?)?.toInt(),
        faceConfidence:   (json['face_confidence'] as num?)?.toDouble(),
        livenessVerified: json['liveness_verified'] as bool? ?? false,
        markedAt: json['marked_at'] != null
            ? DateTime.tryParse(json['marked_at'])
            : null,
      );
}


class TeacherSessionModel {
  final int id;
  final String? sessionName;
  final int classroomId;
  final String classroomName;
  final int subjectId;
  final String subjectName;
  final String? subjectCode;
  final String? department;
  final int? year;
  final String? section;
  final int attendanceRadius;
  final int durationMinutes;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // 'active' | 'closed'
  final bool isActive;
  final int attendanceCount;
  final int totalStudents;
  final int absentCount;
  final int timeRemainingSeconds;
  final DateTime? createdAt;
  final List<SessionStudentEntry> students;

  const TeacherSessionModel({
    required this.id,
    this.sessionName,
    required this.classroomId,
    required this.classroomName,
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    this.department,
    this.year,
    this.section,
    this.attendanceRadius = 20,
    this.durationMinutes = 15,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.isActive,
    this.attendanceCount = 0,
    this.totalStudents = 0,
    this.absentCount = 0,
    this.timeRemainingSeconds = 0,
    this.createdAt,
    this.students = const [],
  });

  factory TeacherSessionModel.fromJson(Map<String, dynamic> json) =>
      TeacherSessionModel(
        id:               (json['id'] as num).toInt(),
        sessionName:      json['session_name'],
        classroomId:      (json['classroom_id'] as num).toInt(),
        classroomName:    json['classroom_name'] ?? '',
        subjectId:        (json['subject_id'] as num).toInt(),
        subjectName:      json['subject_name'] ?? '',
        subjectCode:      json['subject_code'],
        department:       json['department'],
        year:             (json['year'] as num?)?.toInt(),
        section:          json['section'],
        attendanceRadius: (json['attendance_radius'] as num?)?.toInt() ?? 20,
        durationMinutes:  (json['duration_minutes'] as num?)?.toInt() ?? 15,
        startTime: DateTime.parse(json['start_time']),
        endTime:   json['end_time'] != null ? DateTime.tryParse(json['end_time']) : null,
        status:    json['status'] ?? 'active',
        isActive:  json['is_active'] as bool? ?? true,
        attendanceCount:      (json['attendance_count'] as num?)?.toInt() ?? 0,
        totalStudents:        (json['total_students'] as num?)?.toInt() ?? 0,
        absentCount:          (json['absent_count'] as num?)?.toInt() ?? 0,
        timeRemainingSeconds: (json['time_remaining_seconds'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'])
            : null,
        students: (json['students'] as List<dynamic>?)
                ?.map((s) => SessionStudentEntry.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// Display label — show session_name or fallback
  String get displayName =>
      sessionName ?? '$classroomName · $subjectName';

  /// Human-readable time remaining
  String get timeRemainingDisplay {
    if (timeRemainingSeconds <= 0) return 'Expired';
    final m = timeRemainingSeconds ~/ 60;
    final s = timeRemainingSeconds % 60;
    if (m > 0) return '${m}m ${s}s remaining';
    return '${s}s remaining';
  }

  String get classBadge =>
      [
        if (department != null) department!,
        if (year != null) 'Year $year',
        if (section != null) 'Sec $section',
      ].join(' · ');
}


class ClassSummaryModel {
  final int subjectId;
  final String subjectName;
  final String? subjectCode;
  final String? department;
  final int totalSessions;
  final Map<String, dynamic>? lastSession;

  const ClassSummaryModel({
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    this.department,
    this.totalSessions = 0,
    this.lastSession,
  });

  factory ClassSummaryModel.fromJson(Map<String, dynamic> json) =>
      ClassSummaryModel(
        subjectId:    (json['subject_id'] as num).toInt(),
        subjectName:  json['subject_name'] ?? '',
        subjectCode:  json['subject_code'],
        department:   json['department'],
        totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
        lastSession:  json['last_session'] as Map<String, dynamic>?,
      );
}


// ════════════════════════════════════════════════════════════
// STUDENT ANALYTICS MODELS (v11)
// ════════════════════════════════════════════════════════════

// ─── Today's Schedule Entry ──────────────────────────────────
class TodayScheduleEntry {
  final int sessionId;
  final int timetableId;
  final int periodNumber;
  final String subjectName;
  final String? subjectCode;
  final String classroom;
  final String? facultyName;
  final String? startTime;   // HH:MM (24h) from timetable
  final String? endTime;
  final bool isActive;
  final bool isCurrentPeriod;
  final String status;
  final String attStatus;

  TodayScheduleEntry({
    required this.sessionId,
    this.timetableId = 0,
    this.periodNumber = 0,
    required this.subjectName,
    this.subjectCode,
    required this.classroom,
    this.facultyName,
    this.startTime,
    this.endTime,
    required this.isActive,
    this.isCurrentPeriod = false,
    required this.status,
    required this.attStatus,
  });

  factory TodayScheduleEntry.fromJson(Map<String, dynamic> json) {
    return TodayScheduleEntry(
      sessionId:       (json['session_id'] as num?)?.toInt() ?? 0,
      timetableId:     (json['timetable_id'] as num?)?.toInt() ?? 0,
      periodNumber:    (json['period_number'] as num?)?.toInt() ?? 0,
      subjectName:     json['subject_name'] ?? '',
      subjectCode:     json['subject_code'],
      classroom:       json['classroom'] ?? '',
      facultyName:     json['faculty_name'],
      startTime:       json['start_time'],
      endTime:         json['end_time'],
      isActive:        json['is_active'] as bool? ?? false,
      isCurrentPeriod: json['is_current'] as bool? ?? false,
      status:          json['status'] ?? 'not_started',
      attStatus:       json['att_status'] ?? 'upcoming',
    );
  }

  /// True if student has marked attendance for this period
  bool get isMarked => attStatus == 'present';

  /// True if student was absent for this period
  bool get isAbsent => attStatus == 'absent';

  /// Display time label e.g. "08:00 – 08:50"
  String get timeLabel {
    final s = startTime ?? '';
    final e = endTime ?? '';
    if (s.isEmpty) return '';
    if (e.isEmpty) return s;
    return '$s – $e';
  }
}


// ─── Class Log Entry (Subject Detail) ───────────────────────
class ClassLogEntry {
  final int id;
  final DateTime date;
  final String time;
  final String classroom;
  final String? facultyName;
  final String status;
  final int? rssi;
  final double? faceConfidence;
  final bool livenessVerified;

  ClassLogEntry({
    required this.id,
    required this.date,
    required this.time,
    required this.classroom,
    this.facultyName,
    required this.status,
    this.rssi,
    this.faceConfidence,
    required this.livenessVerified,
  });

  factory ClassLogEntry.fromJson(Map<String, dynamic> json) {
    return ClassLogEntry(
      id:               (json['id'] as num).toInt(),
      date:             DateTime.parse(json['date']),
      time:             json['time'] ?? '',
      classroom:        json['classroom'] ?? '',
      facultyName:      json['faculty_name'],
      status:           json['status'] ?? 'absent',
      rssi:             (json['rssi'] as num?)?.toInt(),
      faceConfidence:   (json['face_confidence'] as num?)?.toDouble(),
      livenessVerified: json['liveness_verified'] as bool? ?? false,
    );
  }
}

// ─── Subject Detail Model ────────────────────────────────────
class SubjectDetailModel {
  final int subjectId;
  final String subjectName;
  final String? subjectCode;
  final String? department;
  final int? facultyId;
  final String? facultyName;
  final int total;
  final int attended;
  final int absent;
  final double percentage;
  final String statusLabel;
  final List<ClassLogEntry> classLog;

  SubjectDetailModel({
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    this.department,
    this.facultyId,
    this.facultyName,
    required this.total,
    required this.attended,
    required this.absent,
    required this.percentage,
    required this.statusLabel,
    required this.classLog,
  });

  factory SubjectDetailModel.fromJson(Map<String, dynamic> json) {
    return SubjectDetailModel(
      subjectId:   (json['subject_id'] as num).toInt(),
      subjectName: json['subject_name'] ?? '',
      subjectCode: json['subject_code'],
      department:  json['department'],
      facultyId:   (json['faculty_id'] as num?)?.toInt(),
      facultyName: json['faculty_name'],
      total:       (json['total'] as num?)?.toInt() ?? 0,
      attended:    (json['attended'] as num?)?.toInt() ?? 0,
      absent:      (json['absent'] as num?)?.toInt() ?? 0,
      percentage:  (json['percentage'] as num?)?.toDouble() ?? 0.0,
      statusLabel: json['status_label'] ?? 'Warning',
      classLog:    (json['class_log'] as List? ?? [])
          .map((e) => ClassLogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Missed Class Model ──────────────────────────────────────
class MissedClassModel {
  final int id;
  final String subjectName;
  final String? subjectCode;
  final String classroom;
  final String? facultyName;
  final DateTime date;
  final String time;
  final String status;
  final String reason;

  MissedClassModel({
    required this.id,
    required this.subjectName,
    this.subjectCode,
    required this.classroom,
    this.facultyName,
    required this.date,
    required this.time,
    required this.status,
    required this.reason,
  });

  factory MissedClassModel.fromJson(Map<String, dynamic> json) {
    return MissedClassModel(
      id:          (json['id'] as num).toInt(),
      subjectName: json['subject_name'] ?? '',
      subjectCode: json['subject_code'],
      classroom:   json['classroom'] ?? '',
      facultyName: json['faculty_name'],
      date:        DateTime.parse(json['date']),
      time:        json['time'] ?? '',
      status:      json['status'] ?? 'absent',
      reason:      json['reason'] ?? 'Attendance Not Marked',
    );
  }
}

// ─── Monthly Stats Model ─────────────────────────────────────
class MonthlyStatsModel {
  final int month;
  final String monthName;
  final int total;
  final int present;
  final int absent;
  final double percentage;

  MonthlyStatsModel({
    required this.month,
    required this.monthName,
    required this.total,
    required this.present,
    required this.absent,
    required this.percentage,
  });

  factory MonthlyStatsModel.fromJson(Map<String, dynamic> json) {
    return MonthlyStatsModel(
      month:      (json['month'] as num).toInt(),
      monthName:  json['month_name'] ?? '',
      total:      (json['total'] as num?)?.toInt() ?? 0,
      present:    (json['present'] as num?)?.toInt() ?? 0,
      absent:     (json['absent'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ─── Semester Analytics Model ────────────────────────────────
class SemesterAnalyticsModel {
  final String semesterStart;
  final int totalClasses;
  final int totalPresent;
  final int totalAbsent;
  final double overallPercentage;
  final String statusLabel;
  final int totalSubjects;
  final int currentStreak;
  final int longestStreak;
  final SubjectAttendance? highestSubject;
  final SubjectAttendance? lowestSubject;
  final List<SubjectAttendance> subjects;

  SemesterAnalyticsModel({
    required this.semesterStart,
    required this.totalClasses,
    required this.totalPresent,
    required this.totalAbsent,
    required this.overallPercentage,
    required this.statusLabel,
    required this.totalSubjects,
    required this.currentStreak,
    required this.longestStreak,
    this.highestSubject,
    this.lowestSubject,
    required this.subjects,
  });

  factory SemesterAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return SemesterAnalyticsModel(
      semesterStart:     json['semester_start'] ?? '',
      totalClasses:      (json['total_classes'] as num?)?.toInt() ?? 0,
      totalPresent:      (json['total_present'] as num?)?.toInt() ?? 0,
      totalAbsent:       (json['total_absent'] as num?)?.toInt() ?? 0,
      overallPercentage: (json['overall_percentage'] as num?)?.toDouble() ?? 0.0,
      statusLabel:       json['status_label'] ?? 'Warning',
      totalSubjects:     (json['total_subjects'] as num?)?.toInt() ?? 0,
      currentStreak:     (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak:     (json['longest_streak'] as num?)?.toInt() ?? 0,
      highestSubject:    json['highest_subject'] != null
          ? SubjectAttendance.fromJson(json['highest_subject'] as Map<String, dynamic>)
          : null,
      lowestSubject: json['lowest_subject'] != null
          ? SubjectAttendance.fromJson(json['lowest_subject'] as Map<String, dynamic>)
          : null,
      subjects: (json['subjects'] as List? ?? [])
          .map((e) => SubjectAttendance.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
