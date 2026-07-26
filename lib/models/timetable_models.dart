// ============================================================
// SmartAttend — Timetable Models (v13 ERP Compatibility)
// ============================================================

import 'erp_models.dart';

// ─── Timetable Entry (for student + teacher views) ────────
class TimetableEntryModel {
  final int? id;
  final String? department;
  final int? year;
  final String? section;
  final String dayOfWeek;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final String? subjectName;
  final String? subjectCode;
  final String? facultyName;
  final String? room;
  final String classType;
  final int? credits;
  final int? subjectId;
  final int? facultyId;
  final int? classroomId;
  final String? status;   // active | upcoming | completed
  final String? attStatus; // present | absent | upcoming | not_marked

  TimetableEntryModel({
    this.id,
    this.department,
    this.year,
    this.section,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    this.subjectName,
    this.subjectCode,
    this.facultyName,
    this.room,
    this.classType = 'Theory',
    this.credits,
    this.subjectId,
    this.facultyId,
    this.classroomId,
    this.status,
    this.attStatus,
  });

  factory TimetableEntryModel.fromJson(Map<String, dynamic> j) =>
      TimetableEntryModel(
        id:          (j['id'] as num?)?.toInt(),
        department:  j['department_short'] as String? ?? j['department_name'] as String? ?? j['department'] as String?,
        year:        (j['year'] as num?)?.toInt(),
        section:     j['section'] as String?,
        dayOfWeek:   j['day_of_week'] as String? ?? '',
        periodNumber: (j['order_index'] as num?)?.toInt() ?? (j['period_number'] as num?)?.toInt() ?? 0,
        startTime:   j['start_time'] as String? ?? '',
        endTime:     j['end_time'] as String? ?? '',
        subjectName: j['subject_name'] as String?,
        subjectCode: j['subject_code'] as String?,
        facultyName: j['faculty_name'] as String?,
        room:        j['room_name'] as String? ?? j['room'] as String?,
        classType:   j['class_type'] as String? ?? 'Theory',
        credits:     (j['credits'] as num?)?.toInt(),
        subjectId:   (j['erp_subject_id'] as num?)?.toInt() ?? (j['subject_id'] as num?)?.toInt(),
        facultyId:   (j['faculty_id'] as num?)?.toInt(),
        classroomId: (j['classroom_id'] as num?)?.toInt(),
        status:      j['status'] as String?,
        attStatus:   j['att_status'] as String?,
      );

  bool get isActive      => status == 'active';
  bool get isCompleted   => status == 'completed';
  bool get isUpcoming    => status == 'upcoming';
  bool get isPresent     => attStatus == 'present';
  bool get isAbsent      => attStatus == 'absent';
  bool get isNonTeaching =>
      ['Break', 'Lunch', 'Free', 'Mentoring', 'NPTEL', 'Placement']
          .contains(classType);
}


// ─── Student/Teacher Timetable Response ────────────────────
class StudentTimetableModel {
  final List<TimetableEntryModel> today;
  final Map<String, List<TimetableEntryModel>> weekly;
  final TimetableEntryModel? currentPeriod;
  final TimetableEntryModel? upcomingPeriod;
  final String todayDay;
  final String now;

  StudentTimetableModel({
    required this.today,
    required this.weekly,
    this.currentPeriod,
    this.upcomingPeriod,
    required this.todayDay,
    required this.now,
  });

  factory StudentTimetableModel.fromJson(Map<String, dynamic> j) {
    final weeklyRaw = j['weekly'] as Map<String, dynamic>? ?? {};
    final weekly = weeklyRaw.map((day, list) => MapEntry(
      day,
      (list as List).map((e) =>
          TimetableEntryModel.fromJson(e as Map<String, dynamic>)).toList(),
    ));
    return StudentTimetableModel(
      today: (j['today'] as List? ?? [])
          .map((e) => TimetableEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      weekly: weekly,
      currentPeriod: j['current_period'] != null
          ? TimetableEntryModel.fromJson(j['current_period'] as Map<String, dynamic>)
          : null,
      upcomingPeriod: j['upcoming_period'] != null
          ? TimetableEntryModel.fromJson(j['upcoming_period'] as Map<String, dynamic>)
          : null,
      todayDay: j['today_day'] as String? ?? '',
      now: j['now'] as String? ?? '',
    );
  }
}


// ─── Teacher Auto-fill ─────────────────────────────────────
class TimetableAutoFill {
  final bool found;
  final String? department;
  final int? year;
  final String? section;
  final int? subjectId;
  final String? subjectName;
  final String? subjectCode;
  final int? classroomId;
  final String? room;
  final String? classType;
  final int? periodNumber;
  final String? startTime;
  final String? endTime;

  TimetableAutoFill({
    required this.found,
    this.department,
    this.year,
    this.section,
    this.subjectId,
    this.subjectName,
    this.subjectCode,
    this.classroomId,
    this.room,
    this.classType,
    this.periodNumber,
    this.startTime,
    this.endTime,
  });

  factory TimetableAutoFill.notFound() => TimetableAutoFill(found: false);

  factory TimetableAutoFill.fromJson(Map<String, dynamic> j) {
    final af = j['auto_fill'] as Map<String, dynamic>?;
    if (af == null) return TimetableAutoFill.notFound();
    return TimetableAutoFill(
      found:        j['found'] as bool? ?? false,
      department:   af['department'] as String?,
      year:         (af['year'] as num?)?.toInt(),
      section:      af['section'] as String?,
      subjectId:    (af['subject_id'] as num?)?.toInt(),
      subjectName:  af['subject_name'] as String?,
      subjectCode:  af['subject_code'] as String?,
      classroomId:  (af['classroom_id'] as num?)?.toInt(),
      room:         af['room'] as String?,
      classType:    af['class_type'] as String?,
      periodNumber: (af['period_number'] as num?)?.toInt(),
      startTime:    af['start_time'] as String?,
      endTime:      af['end_time'] as String?,
    );
  }
}
