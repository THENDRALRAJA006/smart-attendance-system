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

  bool get hasFaceRegistered => faceId != null && faceId!.isNotEmpty;
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
    required this.date,
    required this.time,
    required this.status,
    this.rssi,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'],
      studentId: json['student_id'],
      studentName: json['student_name'],
      classroomId: json['classroom_id'],
      classroomName: json['classroom_name'],
      subjectId: json['subject_id'],
      subjectName: json['subject_name'],
      date: DateTime.parse(json['date']),
      time: json['time'],
      status: json['status'],
      rssi: json['rssi'],
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

  DashboardStats({
    required this.totalClasses,
    required this.attendedClasses,
    required this.attendancePercentage,
    required this.subjectWise,
    required this.recentHistory,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalClasses: json['total_classes'],
      attendedClasses: json['attended_classes'],
      attendancePercentage: (json['attendance_percentage'] as num).toDouble(),
      subjectWise: (json['subject_wise'] as List)
          .map((e) => SubjectAttendance.fromJson(e))
          .toList(),
      recentHistory: (json['recent_history'] as List)
          .map((e) => AttendanceModel.fromJson(e))
          .toList(),
    );
  }
}

// ─── Subject Attendance Model ───────────────────────────────
class SubjectAttendance {
  final String subjectName;
  final String? subjectCode;
  final String? facultyName;
  final int total;
  final int attended;
  final double percentage;

  SubjectAttendance({
    required this.subjectName,
    this.subjectCode,
    this.facultyName,
    required this.total,
    required this.attended,
    required this.percentage,
  });

  factory SubjectAttendance.fromJson(Map<String, dynamic> json) {
    return SubjectAttendance(
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
      facultyName: json['faculty_name'],
      total: json['total'],
      attended: json['attended'],
      percentage: (json['percentage'] as num).toDouble(),
    );
  }

  bool get isBelowThreshold => percentage < 75.0;

  /// Display label: "AD23511 — Deep Learning" or just "Deep Learning"
  String get displayLabel =>
      subjectCode != null ? '$subjectCode — $subjectName' : subjectName;
}
