// ============================================================
// SmartAttend — Teacher Dashboard (v12 Premium Light)
// Welcome hero, active session, quick actions, my classes,
// recent sessions. All logic from SessionController preserved.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/erp_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../models/timetable_models.dart';
import '../../widgets/sa_widgets.dart';
import 'teacher_timetable_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final SessionController    _sc;
  late final AuthController       _auth;
  late final ErpController        _tt;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
    _sc   = Get.find<SessionController>();
    // Safe lookup — shell may or may not have pre-registered it
    _tt   = Get.isRegistered<ErpController>()
        ? Get.find<ErpController>()
        : Get.put(ErpController());
    _sc.fetchActiveSession();
    _sc.fetchMyClasses();
    _sc.fetchSessionHistory();
    _tt.fetchTeacherTimetable();
    // Tick every second for live countdown
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.bgCard,
        onRefresh: () async {
          await _sc.fetchActiveSession();
          await _sc.fetchMyClasses();
          await _sc.fetchSessionHistory();
        },
        child: !isDesktop
            ? CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _WelcomeHero(auth: _auth, greeting: _greeting())),
                  SliverToBoxAdapter(child: Obx(() {
                    final tt = _tt.teacherTimetable.value;
                    if (tt == null) return const SizedBox.shrink();
                    return _TodayScheduleSection(today: tt.today);
                  })),
                  SliverToBoxAdapter(child: Obx(() {
                    final tt = _tt.teacherTimetable.value;
                    if (tt == null) return const SizedBox.shrink();
                    return _NextPeriodCard(tt: tt, sc: _sc);
                  })),
                  SliverToBoxAdapter(child: Obx(() {
                    final session = _sc.activeSession.value;
                    if (session == null) return const SizedBox.shrink();
                    return _ActiveSessionBanner(session: session, sc: _sc);
                  })),
                  SliverToBoxAdapter(child: _QuickActions(sc: _sc)),
                  SliverToBoxAdapter(child: Obx(() {
                    if (_sc.myClasses.isEmpty) return const SizedBox.shrink();
                    return _MyClassesSection(classes: _sc.myClasses);
                  })),
                  SliverToBoxAdapter(child: Obx(() {
                    if (_sc.sessionHistory.isEmpty) return const SizedBox.shrink();
                    return _RecentSessionsSection(sessions: _sc.sessionHistory);
                  })),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
                    children: [
                      _WelcomeHero(auth: _auth, greeting: _greeting()),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              children: [
                                Obx(() {
                                  final tt = _tt.teacherTimetable.value;
                                  if (tt == null) return const SizedBox.shrink();
                                  return _NextPeriodCard(tt: tt, sc: _sc);
                                }),
                                const SizedBox(height: 20),
                                Obx(() {
                                  final session = _sc.activeSession.value;
                                  if (session == null) return const SizedBox.shrink();
                                  return _ActiveSessionBanner(session: session, sc: _sc);
                                }),
                                const SizedBox(height: 20),
                                _QuickActions(sc: _sc),
                                const SizedBox(height: 20),
                                Obx(() {
                                  if (_sc.myClasses.isEmpty) return const SizedBox.shrink();
                                  return _MyClassesSection(classes: _sc.myClasses);
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                Obx(() {
                                  final tt = _tt.teacherTimetable.value;
                                  if (tt == null) return const SizedBox.shrink();
                                  return _TodayScheduleSection(today: tt.today);
                                }),
                                const SizedBox(height: 20),
                                Obx(() {
                                  if (_sc.sessionHistory.isEmpty) return const SizedBox.shrink();
                                  return _RecentSessionsSection(sessions: _sc.sessionHistory);
                                }),
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
// Today's Schedule
// ═══════════════════════════════════════════════════════════
class _TodayScheduleSection extends StatelessWidget {
  final List<TimetableEntryModel> today;
  const _TodayScheduleSection({required this.today});

  @override
  Widget build(BuildContext context) {
    if (today.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.today_rounded, color: AppTheme.primary, size: 18),
            const SizedBox(width: 6),
            Text("Today's Schedule",
                style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            const Spacer(),
            Text(DateFormat('EEEE').format(now),
                style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          ...today.map((entry) => _periodRow(entry, now)),
        ],
      ),
    );
  }

  Widget _periodRow(TimetableEntryModel e, DateTime now) {
    final isBreak = e.isNonTeaching;
    final start   = _parseTime(e.startTime, now);
    final end     = _parseTime(e.endTime, now);
    final isNow   = start != null && end != null && now.isAfter(start) && now.isBefore(end);
    final isDone  = end != null && now.isAfter(end);

    Color statusColor;
    String statusLabel;
    if (isNow) { statusColor = AppTheme.success; statusLabel = 'Ongoing'; }
    else if (isDone) { statusColor = AppTheme.textHint; statusLabel = 'Done'; }
    else { statusColor = AppTheme.primary; statusLabel = 'Upcoming'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isNow
            ? AppTheme.success.withValues(alpha: 0.07)
            : isBreak
                ? AppTheme.bgMuted
                : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNow ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          // Time column
          SizedBox(
            width: 50,
            child: Text(e.startTime,
                style: GoogleFonts.poppins(
                    color: isBreak ? AppTheme.textHint : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          if (isBreak)
            Expanded(child: Text(e.classType,
                style: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 13, fontStyle: FontStyle.italic)))
          else ...[
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.subjectName ?? '—',
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              if (e.section != null || e.room != null)
                Text([if (e.section != null) e.section!, if (e.room != null) e.room!].join(' · '),
                    style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: GoogleFonts.poppins(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  DateTime? _parseTime(String t, DateTime base) {
    try {
      final parts = t.split(':');
      return DateTime(base.year, base.month, base.day,
          int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) { return null; }
  }
}


// ═══════════════════════════════════════════════════════════
// Next Period Card
// ═══════════════════════════════════════════════════════════
class _NextPeriodCard extends StatelessWidget {
  final StudentTimetableModel tt;
  final SessionController sc;
  const _NextPeriodCard({required this.tt, required this.sc});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Determine next period (first upcoming non-teaching-break class)
    TimetableEntryModel? next;
    for (final e in tt.today) {
      if (e.isNonTeaching) continue;
      final start = _parseTime(e.startTime, now);
      if (start != null && start.isAfter(now.subtract(const Duration(minutes: 1)))) {
        next = e;
        break;
      }
    }

    if (next == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppTheme.success, size: 24),
          const SizedBox(width: 12),
          Text('No More Classes Today',
              style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }

    final start = _parseTime(next.startTime, now)!;
    final diff  = start.difference(now);
    final within5 = diff.inMinutes <= 5 && diff.inSeconds >= 0;
    final isOngoing = diff.inSeconds <= 0;

    final countdown = isOngoing
        ? 'In progress'
        : _formatDiff(diff);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.92),
            AppTheme.secondary.withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label
        Text('NEXT PERIOD',
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text(next.subjectName ?? '—',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        const SizedBox(height: 8),
        // Detail row
        Row(children: [
          _infoChip(Icons.group_outlined, next.section ?? '—'),
          const SizedBox(width: 8),
          _infoChip(Icons.meeting_room_outlined, next.room ?? '—'),
          const SizedBox(width: 8),
          _infoChip(Icons.schedule_outlined, '${next.startTime} – ${next.endTime}'),
        ]),
        const SizedBox(height: 14),
        // Countdown
        Row(children: [
          const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text('Starts in  ', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
          Text(countdown,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
        ]),
        const SizedBox(height: 14),
        // Start button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (within5 || isOngoing)
                ? () => Get.toNamed(AppConstants.routeStartSession)
                : null,
            icon: const Icon(Icons.play_circle_filled_rounded, size: 20),
            label: Text(
              within5 || isOngoing ? 'Start Attendance' : 'Available ${_formatDiff(diff)} before class',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white70, size: 12),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
    ]),
  );

  String _formatDiff(Duration d) {
    if (d.isNegative) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  DateTime? _parseTime(String t, DateTime base) {
    try {
      final parts = t.split(':');
      return DateTime(base.year, base.month, base.day,
          int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) { return null; }
  }
}


// ═══════════════════════════════════════════════════════════
// Welcome Hero
// ═══════════════════════════════════════════════════════════
class _WelcomeHero extends StatelessWidget {
  final AuthController auth;
  final String greeting;
  const _WelcomeHero({required this.auth, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Obx(() {
        final faculty = auth.currentFaculty.value;
        final name    = faculty?.name ?? (auth.role.value == 'faculty' ? 'Mrs. Starlin M.A' : 'Teacher');
        final dept    = (faculty?.department != null && faculty!.department!.isNotEmpty) ? faculty.department! : 'AI&ML';
        return Row(children: [
          // Avatar
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: Center(
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting,
                style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12, fontWeight: FontWeight.w400)),
            Text(name,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            if (dept.isNotEmpty)
              Text(dept,
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12)),
          ])),
          // Date badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Text(DateFormat('dd').format(DateTime.now()),
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, height: 1)),
              Text(DateFormat('MMM').format(DateTime.now()),
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
            ]),
          ),
        ]);
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Active Session Banner
// ═══════════════════════════════════════════════════════════
class _ActiveSessionBanner extends StatelessWidget {
  final TeacherSessionModel session;
  final SessionController sc;
  const _ActiveSessionBanner({required this.session, required this.sc});

  @override
  Widget build(BuildContext context) {
    final endTime = session.endTime;
    final timeLeft = endTime != null
        ? endTime.difference(DateTime.now())
        : Duration.zero;
    final mins = timeLeft.inMinutes.clamp(0, 999);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.circle, color: AppTheme.success, size: 8),
              const SizedBox(width: 6),
              Text('ACTIVE SESSION', style: GoogleFonts.poppins(
                  color: AppTheme.success, fontWeight: FontWeight.w700,
                  fontSize: 10, letterSpacing: 0.5)),
            ]),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$mins min left',
                style: GoogleFonts.poppins(
                    color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(session.subjectName,
            style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.meeting_room_outlined, color: AppTheme.textHint, size: 14),
          const SizedBox(width: 4),
          Text(session.classroomName,
              style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(width: 16),
          const Icon(Icons.people_outline_rounded, color: AppTheme.textHint, size: 14),
          const SizedBox(width: 4),
          Obx(() => Text('${sc.activeSession.value?.attendanceCount ?? 0} present',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Get.toNamed(AppConstants.routeActiveSession),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text('Manage Session',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => sc.endSession(session.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Text('End', style: GoogleFonts.poppins(
                  color: AppTheme.error, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Quick Actions Grid
// ═══════════════════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  final SessionController sc;
  const _QuickActions({required this.sc});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        'label': 'Start\nSession',
        'icon': Icons.play_circle_outline_rounded,
        'color': AppTheme.primary,
        'onTap': () => Get.toNamed(AppConstants.routeStartSession),
      },
      {
        'label': 'Session\nHistory',
        'icon': Icons.history_rounded,
        'color': AppTheme.secondary,
        'onTap': () => Get.toNamed(AppConstants.routeSessionHistory),
      },
      {
        'label': 'Active\nSession',
        'icon': Icons.sensors_rounded,
        'color': AppTheme.success,
        'onTap': () => Get.toNamed(AppConstants.routeActiveSession),
      },
      {
        'label': 'My\nClasses',
        'icon': Icons.class_outlined,
        'color': AppTheme.accent,
        'onTap': () => Get.to(() => const TeacherTimetableScreen()),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick Actions',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 14),
        Row(children: actions.map((a) {
          final color = a['color'] as Color;
          return Expanded(
            child: GestureDetector(
              onTap: a['onTap'] as VoidCallback,
              child: Container(
                margin: EdgeInsets.only(right: a == actions.last ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(a['icon'] as IconData, color: color, size: 24),
                  const SizedBox(height: 6),
                  Text(a['label'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary, height: 1.2),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          );
        }).toList()),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// My Classes
// ═══════════════════════════════════════════════════════════
class _MyClassesSection extends StatelessWidget {
  final List<ClassSummaryModel> classes;
  const _MyClassesSection({required this.classes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SASectionHeader(title: 'My Classes'),
        const SizedBox(height: 12),
        ...classes.take(5).map((c) => _ClassRow(cls: c)),
      ]),
    );
  }
}

class _ClassRow extends StatelessWidget {
  final ClassSummaryModel cls;
  const _ClassRow({required this.cls});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.book_outlined, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cls.subjectName,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          Text('${cls.department ?? "—"}  •  ${cls.totalSessions} sessions',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
        ])),
        GestureDetector(
          onTap: () => Get.toNamed(AppConstants.routeStartSession,
              arguments: {'class': cls}),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Start', style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Recent Sessions
// ═══════════════════════════════════════════════════════════
class _RecentSessionsSection extends StatelessWidget {
  final List<TeacherSessionModel> sessions;
  const _RecentSessionsSection({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SASectionHeader(
          title: 'Recent Sessions',
          actionLabel: 'All',
          onAction: () => Get.toNamed(AppConstants.routeSessionHistory),
        ),
        const SizedBox(height: 12),
        ...sessions.take(4).map((s) => _SessionRow(session: s)),
      ]),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final TeacherSessionModel session;
  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM, HH:mm').format(session.startTime);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.history_edu_rounded, color: AppTheme.secondary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(session.subjectName,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          Text('$date  •  ${session.attendanceCount} present',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint, size: 18),
      ]),
    );
  }
}
