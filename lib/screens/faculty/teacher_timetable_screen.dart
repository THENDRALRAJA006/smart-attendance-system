// ============================================================
// SmartAttend — Teacher Timetable Screen (v12)
// Shows today's schedule, current class, upcoming class,
// weekly grid, and auto-fill button for Start Attendance.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/erp_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/timetable_models.dart';
import '../../widgets/glassmorphism_card.dart';

class TeacherTimetableScreen extends StatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen>
    with TickerProviderStateMixin {
  late final ErpController _ctrl;
  late TabController _tabController;

  final List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<ErpController>()
        ? Get.find<ErpController>()
        : Get.put(ErpController());
    _tabController = TabController(length: 2, vsync: this);
    _ctrl.fetchTeacherTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startAttendanceWithAutoFill() async {
    // Fetch current period for auto-fill
    final fill = await _ctrl.fetchCurrentPeriod();
    if (fill == null || !fill.found) {
      Get.snackbar(
        'No Active Period',
        'No timetable entry found for the current time slot.',
        backgroundColor: AppTheme.warning.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }
    // Navigate to start session with auto-fill args
    Get.toNamed(
      AppConstants.routeStartSession,
      arguments: {
        'auto_fill': {
          'department':   fill.department,
          'year':         fill.year,
          'section':      fill.section,
          'subject_id':   fill.subjectId,
          'subject_name': fill.subjectName,
          'classroom_id': fill.classroomId,
          'room':         fill.room,
          'class_type':   fill.classType,
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        title: const Text('My Schedule'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Get.back(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 24),
            tooltip: 'Add Slot',
            onPressed: () => _showAddSlotDialog(context),
          ),
          GestureDetector(
            onTap: _startAttendanceWithAutoFill,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.play_circle_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text('Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSlotDialog(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Class', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ── Tab Bar ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [Tab(text: 'Today'), Tab(text: 'Weekly')],
                    indicator: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: Obx(() {
                  if (_ctrl.isLoading.value &&
                      _ctrl.teacherTimetable.value == null) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary));
                  }
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _TeacherTodayTab(
                        timetable: _ctrl.teacherTimetable.value,
                        onStartAttendance: _startAttendanceWithAutoFill,
                      ),
                      _TeacherWeeklyTab(
                        timetable: _ctrl.teacherTimetable.value,
                        days: _days,
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
      ),
    );
  }

  void _showAddSlotDialog(BuildContext context) {
    final depts = _ctrl.departments;
    final subjects = _ctrl.subjects;
    final periodTimings = _ctrl.periodTimings;
    final classrooms = _ctrl.classrooms;

    String selectedDay = 'Monday';
    int? selectedDeptId = depts.isNotEmpty ? depts.first.id : 7;
    int selectedYear = 3;
    String selectedSection = 'C';
    int? selectedPeriodId = periodTimings.isNotEmpty ? periodTimings.first.id : 1;
    int? selectedSubjectId = subjects.isNotEmpty ? subjects.first.id : null;
    int? selectedClassroomId = classrooms.isNotEmpty ? classrooms.first.id : null;
    String classType = 'Lecture';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24, left: 24, right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Add Timetable Class Slot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Day of Week
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      decoration: const InputDecoration(labelText: 'Day of Week', border: OutlineInputBorder()),
                      items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) => setModalState(() => selectedDay = val!),
                    ),
                    const SizedBox(height: 12),

                    // Year & Section
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedYear,
                            decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                            items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                            onChanged: (val) => setModalState(() => selectedYear = val ?? 3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSection,
                            decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                            items: ['A', 'B', 'C', 'D', 'E', 'F', 'G'].map((s) => DropdownMenuItem(value: s, child: Text('Sec $s'))).toList(),
                            onChanged: (val) => setModalState(() => selectedSection = val ?? 'C'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Period Timing
                    if (periodTimings.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: selectedPeriodId,
                        decoration: const InputDecoration(labelText: 'Period Timing', border: OutlineInputBorder()),
                        items: periodTimings.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.label} (${p.startTime} - ${p.endTime})'))).toList(),
                        onChanged: (val) => setModalState(() => selectedPeriodId = val),
                      ),
                    const SizedBox(height: 12),

                    // Subject
                    if (subjects.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: selectedSubjectId,
                        decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                        items: subjects.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.subjectName} (${s.subjectCode ?? ''})'))).toList(),
                        onChanged: (val) => setModalState(() => selectedSubjectId = val),
                      ),
                    const SizedBox(height: 12),

                    // Classroom
                    if (classrooms.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: selectedClassroomId,
                        decoration: const InputDecoration(labelText: 'Classroom / Venue', border: OutlineInputBorder()),
                        items: classrooms.map((c) => DropdownMenuItem(value: c.id, child: Text(c.roomName))).toList(),
                        onChanged: (val) => setModalState(() => selectedClassroomId = val),
                      ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add Slot to Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (selectedPeriodId == null) return;
                          final ok = await _ctrl.saveSlot(
                            deptId: selectedDeptId,
                            year: selectedYear,
                            section: selectedSection,
                            dayOfWeek: selectedDay,
                            periodTimingId: selectedPeriodId!,
                            subjectId: selectedSubjectId,
                            facultyId: Get.find<AuthController>().currentFaculty.value?.id,
                            classroomId: selectedClassroomId,
                            classType: classType,
                          );
                          Navigator.of(context).pop();
                          if (ok) {
                            await _ctrl.fetchTeacherTimetable();
                            Get.snackbar('Slot Added', 'Timetable slot added successfully', backgroundColor: AppTheme.success, colorText: Colors.white);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


// ─── Today Tab ─────────────────────────────────────────────
class _TeacherTodayTab extends StatelessWidget {
  final StudentTimetableModel? timetable;
  final VoidCallback onStartAttendance;
  const _TeacherTodayTab({
    required this.timetable,
    required this.onStartAttendance,
  });

  @override
  Widget build(BuildContext context) {
    if (timetable == null || timetable!.today.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_available_rounded,
                color: AppTheme.textHint, size: 56),
            const SizedBox(height: 16),
            const Text('No classes scheduled today',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.play_circle_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Start Attendance Manually',
                  style: TextStyle(color: Colors.white)),
              onPressed: () =>
                  Get.toNamed(AppConstants.routeStartSession),
            ),
          ],
        ),
      );
    }

    final currentEntry = timetable!.currentPeriod;
    final upcomingEntry = timetable!.upcomingPeriod;

    return RefreshIndicator(
      onRefresh: () =>
          Get.find<ErpController>().fetchTeacherTimetable(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.bgCard,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          // ── Current class with Start Attendance ──────
          if (currentEntry != null) ...[
            _CurrentClassTeacherCard(
              entry: currentEntry,
              onStartAttendance: onStartAttendance,
            ),
            const SizedBox(height: 16),
          ],

          // ── Upcoming ─────────────────────────────────
          if (upcomingEntry != null) ...[
            _UpcomingTeacherCard(entry: upcomingEntry),
            const SizedBox(height: 16),
          ],

          // ── Today list ───────────────────────────────
          const _Label('Today\'s Classes'),
          const SizedBox(height: 10),
          ...timetable!.today.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TeacherScheduleCard(entry: e),
              )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CurrentClassTeacherCard extends StatelessWidget {
  final TimetableEntryModel entry;
  final VoidCallback onStartAttendance;
  const _CurrentClassTeacherCard({
    required this.entry,
    required this.onStartAttendance,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                  SizedBox(width: 4),
                  Text('CURRENT CLASS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10)),
                ]),
              ),
              const Spacer(),
              Text('${entry.startTime} – ${entry.endTime}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            Text(
              entry.subjectName ?? 'Unknown Subject',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            if (entry.subjectCode != null)
              Text(entry.subjectCode!,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            Row(children: [
              if (entry.room != null) ...[
                const Icon(Icons.meeting_room_outlined,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(entry.room!,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(entry.classType,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10)),
              ),
            ]),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onStartAttendance,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.how_to_reg_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Start Attendance — Auto-filled',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _UpcomingTeacherCard extends StatelessWidget {
  final TimetableEntryModel entry;
  const _UpcomingTeacherCard({required this.entry});

  @override
  Widget build(BuildContext context) => GlassmorphismCard(
        borderColor: AppTheme.accent.withValues(alpha: 0.3),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.schedule_rounded,
                color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('UPCOMING',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 10)),
                Text(
                  entry.subjectName ?? 'Unknown',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                Text(
                  '${entry.startTime} · ${entry.room ?? "—"} · ${entry.classType}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ]),
      );
}

class _TeacherScheduleCard extends StatelessWidget {
  final TimetableEntryModel entry;
  const _TeacherScheduleCard({required this.entry});

  Color get _typeColor {
    switch (entry.classType) {
      case 'Lab':       return AppTheme.accent;
      case 'Break':
      case 'Lunch':     return AppTheme.textHint;
      case 'NPTEL':     return const Color(0xFF00BCD4);
      case 'Placement': return AppTheme.warning;
      case 'Mentoring': return const Color(0xFF9C27B0);
      default:          return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) => GlassmorphismCard(
        borderColor: entry.isActive
            ? AppTheme.success.withValues(alpha: 0.3)
            : _typeColor.withValues(alpha: 0.12),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.startTime.length >= 5
                      ? entry.startTime.substring(0, 5)
                      : entry.startTime,
                  style: TextStyle(
                      color: _typeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
                Text(
                  entry.endTime.length >= 5
                      ? entry.endTime.substring(0, 5)
                      : entry.endTime,
                  style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            width: 3,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _typeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.subjectName ?? 'Unknown',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(children: [
                  if (entry.room != null) ...[
                    const Icon(Icons.meeting_room_outlined,
                        color: AppTheme.textHint, size: 11),
                    const SizedBox(width: 3),
                    Text(entry.room!,
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 11)),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.classType,
                      style: TextStyle(
                          color: _typeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 9),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: (entry.isActive ? AppTheme.success : AppTheme.textHint)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.status?.toUpperCase() ?? 'UPCOMING',
              style: TextStyle(
                  color: entry.isActive
                      ? AppTheme.success
                      : AppTheme.textHint,
                  fontWeight: FontWeight.w800,
                  fontSize: 8),
            ),
          ),
        ]),
      );
}


// ─── Weekly Tab ────────────────────────────────────────────
class _TeacherWeeklyTab extends StatelessWidget {
  final StudentTimetableModel? timetable;
  final List<String> days;
  const _TeacherWeeklyTab({required this.timetable, required this.days});

  @override
  Widget build(BuildContext context) {
    if (timetable == null) {
      return const Center(
          child: Text('No timetable data',
              style: TextStyle(color: AppTheme.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: days.length,
      itemBuilder: (ctx, i) {
        final day = days[i];
        final entries = timetable!.weekly[day] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _DayHeader(day: day),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('No classes',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 12)),
              )
            else
              ...entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TeacherScheduleCard(entry: e),
                  )),
          ],
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String day;
  const _DayHeader({required this.day});

  bool get _isToday {
    const dayOrder = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return DateTime.now().weekday == dayOrder.indexOf(day) + 1;
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _isToday
                ? AppTheme.primary.withValues(alpha: 0.15)
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: _isToday
                ? Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.4))
                : null,
          ),
          child: Text(
            day,
            style: TextStyle(
              color: _isToday ? AppTheme.primary : AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: AppTheme.primary.withValues(alpha: 0.08),
          ),
        ),
      ]);
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      );
}
