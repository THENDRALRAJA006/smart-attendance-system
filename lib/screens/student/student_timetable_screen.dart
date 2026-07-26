// ============================================================
// SmartAttend — Student Timetable Screen (v12)
// Shows today's schedule, current/upcoming class, weekly grid.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/erp_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/timetable_models.dart';
import '../../widgets/glassmorphism_card.dart';

class StudentTimetableScreen extends StatefulWidget {
  const StudentTimetableScreen({super.key});

  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen>
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
    _ctrl.fetchStudentTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: const Text('My Timetable'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Get.back(),
              )
            : null,
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
                      _ctrl.studentTimetable.value == null) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary));
                  }
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _TodayTab(timetable: _ctrl.studentTimetable.value),
                      _WeeklyTab(
                        timetable: _ctrl.studentTimetable.value,
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
}


// ─── Today Tab ─────────────────────────────────────────────
class _TodayTab extends StatelessWidget {
  final StudentTimetableModel? timetable;
  const _TodayTab({required this.timetable});

  @override
  Widget build(BuildContext context) {
    if (timetable == null || timetable!.today.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_rounded,
                color: AppTheme.textHint, size: 56),
            SizedBox(height: 16),
            Text('No classes scheduled today',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => Get.find<ErpController>().fetchStudentTimetable(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.bgCard,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          // Current class banner
          if (timetable!.currentPeriod != null) ...[
            _CurrentClassBanner(entry: timetable!.currentPeriod!),
            const SizedBox(height: 16),
          ],

          // Upcoming banner
          if (timetable!.upcomingPeriod != null) ...[
            _UpcomingBanner(entry: timetable!.upcomingPeriod!),
            const SizedBox(height: 16),
          ],

          // Full today list
          const _SectionTitle('Today\'s Schedule'),
          const SizedBox(height: 10),
          ...timetable!.today.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScheduleCard(entry: e),
              )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CurrentClassBanner extends StatelessWidget {
  final TimetableEntryModel entry;
  const _CurrentClassBanner({required this.entry});

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
            Row(
              children: [
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
                    Text('ONGOING',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10)),
                  ]),
                ),
                const Spacer(),
                Text(
                  '${entry.startTime} – ${entry.endTime}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
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
            const SizedBox(height: 8),
            Row(children: [
              if (entry.room != null) ...[
                const Icon(Icons.meeting_room_outlined,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(entry.room!,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 14),
              ],
              if (entry.facultyName != null) ...[
                const Icon(Icons.person_outline_rounded,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(entry.facultyName!,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ]),
          ],
        ),
      );
}

class _UpcomingBanner extends StatelessWidget {
  final TimetableEntryModel entry;
  const _UpcomingBanner({required this.entry});

  @override
  Widget build(BuildContext context) => GlassmorphismCard(
        borderColor: AppTheme.accent.withValues(alpha: 0.3),
        child: Row(
          children: [
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
                  const Text('NEXT CLASS',
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
                    '${entry.startTime} · ${entry.room ?? "—"}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}


// ─── Weekly Tab ────────────────────────────────────────────
class _WeeklyTab extends StatelessWidget {
  final StudentTimetableModel? timetable;
  final List<String> days;
  const _WeeklyTab({required this.timetable, required this.days});

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
            const SizedBox(height: 4),
            _DayHeader(day: day),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'No classes',
                  style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 12),
                ),
              )
            else
              ...entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ScheduleCard(entry: e),
                  )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String day;
  const _DayHeader({required this.day});

  bool get _isToday =>
      DateTime.now().weekday ==
      ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
          .indexOf(day) + 1;

  @override
  Widget build(BuildContext context) => Row(
        children: [
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
          if (_isToday) ...[
            const SizedBox(width: 6),
            const Text('TODAY',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      );
}

// ─── Shared Schedule Card ──────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final TimetableEntryModel entry;
  const _ScheduleCard({required this.entry});

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
  Widget build(BuildContext context) {
    if (entry.isNonTeaching) {
      return _NonTeachingCard(entry: entry, color: _typeColor);
    }

    // Determine attendance status color
    Color attColor = AppTheme.textHint;
    String attLabel = 'UPCOMING';
    IconData attIcon = Icons.schedule_rounded;

    if (entry.isPresent) {
      attColor = AppTheme.success;
      attLabel = 'PRESENT';
      attIcon  = Icons.check_circle_rounded;
    } else if (entry.isAbsent) {
      attColor = AppTheme.error;
      attLabel = 'ABSENT';
      attIcon  = Icons.cancel_rounded;
    } else if (entry.isActive) {
      attColor = AppTheme.primary;
      attLabel = 'LIVE';
      attIcon  = Icons.circle;
    } else if (entry.isCompleted) {
      attColor = AppTheme.warning;
      attLabel = 'MISSED';
      attIcon  = Icons.warning_amber_rounded;
    }

    final borderColor = entry.isPresent
        ? AppTheme.success.withValues(alpha: 0.3)
        : entry.isAbsent
            ? AppTheme.error.withValues(alpha: 0.3)
            : entry.isActive
                ? AppTheme.success.withValues(alpha: 0.3)
                : _typeColor.withValues(alpha: 0.12);

    return GlassmorphismCard(
      borderColor: borderColor,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Time column
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
                    fontSize: 13,
                  ),
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
            height: 50,
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
                  entry.subjectName ?? 'Unknown Subject',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
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
                  if (entry.facultyName != null) ...[
                    const Icon(Icons.person_outline_rounded,
                        color: AppTheme.textHint, size: 11),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(entry.facultyName!,
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
                if (entry.classType == 'Lab')
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('LAB',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 9)),
                  ),
              ],
            ),
          ),
          // Attendance status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: attColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: attColor.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(attIcon, color: attColor, size: 9),
              const SizedBox(width: 3),
              Text(
                attLabel,
                style: TextStyle(
                    color: attColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 8),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NonTeachingCard extends StatelessWidget {
  final TimetableEntryModel entry;
  final Color color;
  const _NonTeachingCard({required this.entry, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Text(
              entry.startTime.length >= 5
                  ? entry.startTime.substring(0, 5)
                  : entry.startTime,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.subjectName ?? entry.classType,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                entry.classType.toUpperCase(),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 8),
              ),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

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
