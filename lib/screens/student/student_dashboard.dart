// ============================================================
// SmartAttend — Student Dashboard (v12 Premium Light)
// Modern university ERP style — white cards, Poppins,
// floating nav shell, all existing logic preserved.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/student_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sa_button.dart';
import '../../widgets/sa_widgets.dart';
import '../../models/models.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with WidgetsBindingObserver {
  late final AttendanceController _attendance;
  late final StudentController    _student;
  late final AuthController       _auth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attendance = Get.find<AttendanceController>();
    _student    = Get.find<StudentController>();
    _auth       = Get.find<AuthController>();
    _attendance.checkActiveSession();
    _student.fetchDashboard();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _attendance.checkActiveSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _attendance.checkActiveSession(),
            _student.refresh(),
          ]);
        },
        color: AppTheme.primary,
        backgroundColor: AppTheme.bgCard,
        child: !isDesktop
            ? CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _ProfileHero(
                    auth: _auth,
                    greeting: _greeting(),
                    onMarkAttendance: () async {
                      await _attendance.checkActiveSession();
                      _attendance.reset();
                      Get.toNamed(AppConstants.routeClassroomDetection);
                    },
                  )),
                  SliverToBoxAdapter(child: Obx(() {
                    final s = _auth.currentStudent.value;
                    if (s == null || s.hasFaceRegistered) return const SizedBox.shrink();
                    return _FaceWarningBanner();
                  })),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: SAButton(
                        label: 'Mark Attendance',
                        icon: Icons.bluetooth_searching_rounded,
                        height: 56,
                        onPressed: () async {
                          await _attendance.checkActiveSession();
                          _attendance.reset();
                          Get.toNamed(AppConstants.routeClassroomDetection);
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Obx(() {
                      final checking = _attendance.isCheckingSession.value;
                      final session  = _attendance.activeSession.value;
                      final marked   = session != null && _attendance.alreadyMarked;
                      if (checking && session == null) return _SessionCheckingCard();
                      if (session != null && marked) return _AlreadyMarkedCard(session: session);
                      if (session != null) return _ActiveSessionCard(session: session, attendance: _attendance);
                      return const SizedBox.shrink();
                    }),
                  ),
                  SliverToBoxAdapter(child: Obx(() {
                    final stats = _student.dashboardStats.value;
                    if (stats == null && _student.isLoading.value) return const _Skeleton(height: 130);
                    if (stats == null) return const SizedBox.shrink();
                    return _OverallAttendanceCard(stats: stats);
                  })),
                  SliverToBoxAdapter(child: Obx(() {
                    final stats = _student.dashboardStats.value;
                    if (stats == null) return const SizedBox.shrink();
                    return _QuickStatsRow(stats: stats);
                  })),
                  SliverToBoxAdapter(child: Obx(() {
                    final schedule = _student.todayScheduleLive;
                    return _TodayScheduleSection(schedule: schedule.toList());
                  })),
                  SliverToBoxAdapter(child: Obx(() {
                    final stats = _student.dashboardStats.value;
                    if (stats == null) return const SizedBox.shrink();
                    return _SubjectSection(stats: stats);
                  })),
                  SliverToBoxAdapter(child: Obx(() {
                    final stats = _student.dashboardStats.value;
                    if (stats == null || stats.recentHistory.isEmpty) return const SizedBox.shrink();
                    return _RecentHistorySection(records: stats.recentHistory);
                  })),
                  const SliverToBoxAdapter(child: _QuickActionsSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
                    children: [
                      _ProfileHero(
                        auth: _auth,
                        greeting: _greeting(),
                        onMarkAttendance: () async {
                          await _attendance.checkActiveSession();
                          _attendance.reset();
                          Get.toNamed(AppConstants.routeClassroomDetection);
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left column (Active Session, Overall Attendance & Schedule)
                          Expanded(
                            flex: 7,
                            child: Column(
                              children: [
                                Obx(() {
                                  final s = _auth.currentStudent.value;
                                  if (s == null || s.hasFaceRegistered) return const SizedBox.shrink();
                                  return _FaceWarningBanner();
                                }),
                                Obx(() {
                                  final checking = _attendance.isCheckingSession.value;
                                  final session  = _attendance.activeSession.value;
                                  final marked   = session != null && _attendance.alreadyMarked;
                                  if (checking && session == null) return _SessionCheckingCard();
                                  if (session != null && marked) return _AlreadyMarkedCard(session: session);
                                  if (session != null) return _ActiveSessionCard(session: session, attendance: _attendance);
                                  return const SizedBox.shrink();
                                }),
                                const SizedBox(height: 20),
                                Obx(() {
                                  final stats = _student.dashboardStats.value;
                                  if (stats == null && _student.isLoading.value) return const _Skeleton(height: 130);
                                  if (stats == null) return const SizedBox.shrink();
                                  return _OverallAttendanceCard(stats: stats);
                                }),
                                const SizedBox(height: 20),
                                Obx(() {
                                  final schedule = _student.todayScheduleLive;
                                  return _TodayScheduleSection(schedule: schedule.toList());
                                }),
                                const SizedBox(height: 20),
                                Obx(() {
                                  final stats = _student.dashboardStats.value;
                                  if (stats == null) return const SizedBox.shrink();
                                  return _SubjectSection(stats: stats);
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right column (Mark CTA, Quick Stats, History, Actions)
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                SAButton(
                                  label: 'Mark Attendance',
                                  icon: Icons.bluetooth_searching_rounded,
                                  height: 56,
                                  onPressed: () async {
                                    await _attendance.checkActiveSession();
                                    _attendance.reset();
                                    Get.toNamed(AppConstants.routeClassroomDetection);
                                  },
                                ),
                                const SizedBox(height: 20),
                                Obx(() {
                                  final stats = _student.dashboardStats.value;
                                  if (stats == null) return const SizedBox.shrink();
                                  return _QuickStatsRow(stats: stats);
                                }),
                                const SizedBox(height: 20),
                                Obx(() {
                                  final stats = _student.dashboardStats.value;
                                  if (stats == null || stats.recentHistory.isEmpty) return const SizedBox.shrink();
                                  return _RecentHistorySection(records: stats.recentHistory);
                                }),
                                const SizedBox(height: 20),
                                const _QuickActionsSection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Profile Hero Card
// ═══════════════════════════════════════════════════════════
class _ProfileHero extends StatelessWidget {
  final AuthController auth;
  final String greeting;
  final VoidCallback onMarkAttendance;

  const _ProfileHero({
    required this.auth,
    required this.greeting,
    required this.onMarkAttendance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Obx(() {
          final s = auth.currentStudent.value;
          final name = s?.name ?? 'Student';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row ─────────────────
              Row(children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good $greeting 👋',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        name.split(' ').first,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification bell
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 20),
                ),
              ]),
              if (s != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.badge_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${s.regNo}  •  ${s.department}  •  Year ${s.year}-${s.section}',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat('d MMM').format(DateTime.now()),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Face Warning Banner
// ═══════════════════════════════════════════════════════════
class _FaceWarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppConstants.routeFaceRegister),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warningLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.face_retouching_off_rounded,
              color: AppTheme.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Face Not Registered',
                    style: GoogleFonts.poppins(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text('Tap to register — required for attendance.',
                    style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: AppTheme.warning, size: 14),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Active Session Cards
// ═══════════════════════════════════════════════════════════
class _SessionCheckingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(children: [
        const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            color: AppTheme.primary, strokeWidth: 2.5),
        ),
        const SizedBox(width: 14),
        Text('Checking for active sessions...',
            style: GoogleFonts.poppins(
                color: AppTheme.textSecondary, fontSize: 14)),
      ]),
    );
  }
}

class _AlreadyMarkedCard extends StatelessWidget {
  final dynamic session;
  const _AlreadyMarkedCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.successLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: AppTheme.success, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Attendance Marked! ✓',
                style: GoogleFonts.poppins(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            Text('You\'re marked present for this session.',
                style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _ActiveSessionCard extends StatefulWidget {
  final dynamic session;
  final AttendanceController attendance;
  const _ActiveSessionCard({required this.session, required this.attendance});

  @override
  State<_ActiveSessionCard> createState() => _ActiveSessionCardState();
}

class _ActiveSessionCardState extends State<_ActiveSessionCard> {
  Timer? _timer;
  String _timeLeft = '';

  @override
  void initState() {
    super.initState();
    _updateTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimer());
  }

  void _updateTimer() {
    if (!mounted) return;
    // ActiveSessionInfo does not expose endTime — show a generic label.
    setState(() => _timeLeft = 'Active');
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.circle, color: Colors.greenAccent, size: 8),
              const SizedBox(width: 6),
              Text('LIVE SESSION',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.5)),
            ]),
          ),
          const Spacer(),
          Text(_timeLeft,
              style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ]),
        const SizedBox(height: 14),
        Text(
          session?.subjectName ?? 'Unknown Subject',
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18),
        ),
        const SizedBox(height: 6),
        Row(children: [
          if ((session?.classroomName ?? '').isNotEmpty) ...[
            const Icon(Icons.meeting_room_outlined, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(session!.classroomName,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 16),
          ],
        ]),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            widget.attendance.reset();
            Get.toNamed(AppConstants.routeClassroomDetection);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.how_to_reg_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Mark My Attendance',
                    style: GoogleFonts.poppins(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Overall Attendance Card
// ═══════════════════════════════════════════════════════════
class _OverallAttendanceCard extends StatelessWidget {
  final dynamic stats;
  const _OverallAttendanceCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final pct = stats.attendancePercentage as double;
    final Color pctColor = pct >= 75 ? AppTheme.success : AppTheme.error;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Overall Attendance',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const Spacer(),
            if (pct < 75)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Below 75%',
                    style: GoogleFonts.poppins(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            // Circular ring
            SAProgressRing(
              percentage: pct,
              size: 90,
              strokeWidth: 8,
              color: pctColor,
            ),
            const SizedBox(width: 24),
            Expanded(child: Column(children: [
              _StatRow(label: 'Total Classes', value: '${stats.totalClasses}', color: AppTheme.textPrimary),
              const SizedBox(height: 10),
              _StatRow(label: 'Attended', value: '${stats.attendedClasses}', color: AppTheme.success),
              const SizedBox(height: 10),
              _StatRow(label: 'Missed', value: '${stats.totalClasses - stats.attendedClasses}', color: AppTheme.error),
            ])),
          ]),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label,
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
      const Spacer(),
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// Quick Stats Row
// ═══════════════════════════════════════════════════════════
class _QuickStatsRow extends StatelessWidget {
  final dynamic stats;
  const _QuickStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Row(children: [
        _Chip(label: 'Today', value: '${stats.todayClasses}',
            icon: Icons.today_rounded, color: AppTheme.primary),
        const SizedBox(width: 8),
        _Chip(label: 'Week', value: '${stats.weekClasses}',
            icon: Icons.date_range_rounded, color: AppTheme.secondary),
        const SizedBox(width: 8),
        _Chip(label: 'Streak', value: '${stats.streak}d',
            icon: Icons.local_fire_department_rounded, color: AppTheme.warning),
        const SizedBox(width: 8),
        _Chip(label: 'Missed', value: '${stats.missedThisMonth}',
            icon: Icons.cancel_outlined, color: AppTheme.error,
            onTap: () => Get.toNamed(AppConstants.routeMissedClasses)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _Chip({required this.label, required this.value, required this.icon,
    required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text(label,
                style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Today's Schedule
// ═══════════════════════════════════════════════════════════
class _TodayScheduleSection extends StatelessWidget {
  final List<TodayScheduleEntry> schedule;
  const _TodayScheduleSection({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SASectionHeader(
          title: "Today's Classes",
          actionLabel: 'Full Timetable',
          onAction: () => Get.toNamed(AppConstants.routeStudentTimetable),
        ),
        const SizedBox(height: 12),
        if (schedule.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  color: AppTheme.textHint, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No classes scheduled today. Import a timetable from Admin panel.',
                  style: GoogleFonts.poppins(
                      color: AppTheme.textHint, fontSize: 12),
                ),
              ),
            ]),
          )
        else
          ...schedule.map((item) => _TimetableRow(item: item)),
      ]),
    );
  }
}


class _TimetableRow extends StatelessWidget {
  final TodayScheduleEntry item;
  const _TimetableRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final attendance    = Get.find<AttendanceController>();
    final isNow         = item.isCurrentPeriod;
    final isMarked      = item.isMarked;      // attStatus == 'present'
    final isAbsent      = item.isAbsent;      // attStatus == 'absent'
    final isNotMarked   = !isMarked && !isAbsent && item.attStatus == 'not_marked';
    final sessionActive = item.isActive;

    // ── Color scheme ───────────────────────────────────────
    Color borderColor = AppTheme.border;
    Color bgColor     = AppTheme.bgCard;
    if (isMarked) {
      borderColor = AppTheme.success.withValues(alpha: 0.35);
      bgColor     = AppTheme.success.withValues(alpha: 0.04);
    } else if (isAbsent) {
      borderColor = AppTheme.error.withValues(alpha: 0.35);
      bgColor     = AppTheme.error.withValues(alpha: 0.04);
    } else if (isNow) {
      borderColor = AppTheme.primary.withValues(alpha: 0.4);
      bgColor     = AppTheme.primary.withValues(alpha: 0.04);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isNow ? 1.5 : 1),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Period badge
            if (item.periodNumber > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.bgMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('P${item.periodNumber}',
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppTheme.textHint)),
              ),
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isNow ? AppTheme.primary : AppTheme.bgMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.timeLabel.isNotEmpty
                    ? item.timeLabel
                    : (item.startTime ?? '--'),
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isNow ? Colors.white : AppTheme.textSecondary),
              ),
            ),
            if (isNow) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('NOW',
                    style: GoogleFonts.poppins(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 0.5)),
              ),
            ],
            const Spacer(),
            // Status chip
            if (isMarked)
              _StatusChip(
                label: 'Present ✓',
                color: AppTheme.success,
                icon: Icons.check_circle_rounded,
              )
            else if (isAbsent)
              _StatusChip(
                label: 'Absent',
                color: AppTheme.error,
                icon: Icons.cancel_rounded,
              )
            else if (isNow && sessionActive)
              _StatusChip(
                label: 'LIVE',
                color: AppTheme.primary,
                icon: Icons.circle,
                pulse: true,
              )
            else if (isNotMarked)
              _StatusChip(
                label: 'Not Marked',
                color: AppTheme.warning,
                icon: Icons.warning_amber_rounded,
              )
            else
              _StatusChip(
                label: 'Upcoming',
                color: AppTheme.textHint,
                icon: Icons.schedule_rounded,
              ),
          ]),
          const SizedBox(height: 8),
          // Subject name
          Text(
            item.subjectName,
            style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
          const SizedBox(height: 2),
          // Faculty & room
          Row(children: [
            if (item.facultyName != null && item.facultyName!.isNotEmpty) ...[
              const Icon(Icons.person_outline_rounded,
                  color: AppTheme.textHint, size: 13),
              const SizedBox(width: 4),
              Flexible(
                child: Text(item.facultyName!,
                    style: GoogleFonts.poppins(
                        color: AppTheme.textHint, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
            if (item.classroom.isNotEmpty) ...[
              const SizedBox(width: 10),
              const Icon(Icons.meeting_room_outlined,
                  color: AppTheme.textHint, size: 13),
              const SizedBox(width: 3),
              Text(item.classroom,
                  style: GoogleFonts.poppins(
                      color: AppTheme.textHint, fontSize: 11)),
            ],
          ]),

          // Mark Attendance CTA — only when period is live AND session is active
          if (isNow && sessionActive && !isMarked) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await attendance.checkActiveSession();
                  attendance.reset();
                  Get.toNamed(AppConstants.routeClassroomDetection);
                },
                icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
                label: Text('Mark Attendance Now',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ] else if (isNow && !sessionActive && !isMarked) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: AppTheme.textHint, size: 14),
              const SizedBox(width: 6),
              Text('Waiting for teacher to start session...',
                  style: GoogleFonts.poppins(
                      color: AppTheme.textHint,
                      fontSize: 11,
                      fontStyle: FontStyle.italic)),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Reusable colored status chip
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool pulse;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.poppins(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Subject-wise Attendance
// ═══════════════════════════════════════════════════════════
class _SubjectSection extends StatelessWidget {
  final dynamic stats;
  const _SubjectSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.subjectWise.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SASectionHeader(
          title: 'Subject-wise Attendance',
          actionLabel: 'Details',
          onAction: () => Get.toNamed(AppConstants.routeSubjectDetail),
        ),
        const SizedBox(height: 12),
        ...stats.subjectWise.map<Widget>((sub) => _SubjectCard(subject: sub)),
      ]),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final dynamic subject;
  const _SubjectCard({required this.subject});

  Color get _color {
    final pct = (subject as SubjectAttendance).percentage;
    if (pct >= 75) return AppTheme.success;
    if (pct >= 60) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final pct   = (subject as SubjectAttendance).percentage;
    final total = (subject as SubjectAttendance).total;
    final pres  = (subject as SubjectAttendance).attended;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.book_outlined, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subject.subjectName ?? '—',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis),
            Text(subject.facultyName ?? '—',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${pct.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _color)),
            Text('$pres / $total',
                style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
          ]),
        ]),
        const SizedBox(height: 12),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: AppTheme.bgMuted,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Recent History
// ═══════════════════════════════════════════════════════════
class _RecentHistorySection extends StatelessWidget {
  final List<dynamic> records;
  const _RecentHistorySection({required this.records});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SASectionHeader(
          title: 'Recent Attendance',
          actionLabel: 'View All',
          onAction: () => Get.toNamed(AppConstants.routeAttendanceHistory),
        ),
        const SizedBox(height: 12),
        ...records.take(5).map<Widget>((r) => _HistoryRow(record: r)),
      ]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final dynamic record;
  const _HistoryRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final rec = record as AttendanceModel;
    final status = rec.status;
    final color = status == 'present'
        ? AppTheme.success
        : status == 'late' ? AppTheme.warning : AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rec.subjectName ?? '—',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          Text(rec.date.toString().substring(0, 10),
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
        ])),
        SABadge(label: status[0].toUpperCase() + status.substring(1), color: color),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Quick Actions
// ═══════════════════════════════════════════════════════════
class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    final actions = [
      {'label': 'Full Report', 'icon': Icons.assessment_rounded,
        'color': AppTheme.primary, 'route': AppConstants.routeReports},
      {'label': 'History', 'icon': Icons.history_rounded,
        'color': AppTheme.secondary, 'route': AppConstants.routeAttendanceHistory},
      {'label': 'Analytics', 'icon': Icons.bar_chart_rounded,
        'color': AppTheme.accent, 'route': AppConstants.routeSemesterAnalytics},
      {'label': 'Face Setup', 'icon': Icons.face_rounded,
        'color': AppTheme.warning, 'route': AppConstants.routeFaceRegister},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick Actions',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: actions.map((a) {
            final color = a['color'] as Color;
            return GestureDetector(
              onTap: () => Get.toNamed(a['route'] as String),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(a['icon'] as IconData, color: color, size: 24),
                    const SizedBox(height: 6),
                    Text(a['label'] as String,
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────
class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    height: height,
    decoration: BoxDecoration(
      color: AppTheme.bgMuted,
      borderRadius: BorderRadius.circular(20),
    ),
  );
}
