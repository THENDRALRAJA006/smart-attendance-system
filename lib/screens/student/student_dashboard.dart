// ============================================================
// SmartAttend — Student Dashboard (v3)
// StatefulWidget + Timer.periodic session polling (30s)
// Active session detection, "Start Attendance" button
// No standalone QR button — removed in v2, confirmed in v3
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/student_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/attendance_badge.dart';
import '../../widgets/glassmorphism_card.dart';
import 'package:intl/intl.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with WidgetsBindingObserver {
  late final AttendanceController _attendance;
  late final StudentController _student;
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _attendance = Get.find<AttendanceController>();
    _student    = Get.find<StudentController>();
    _auth       = Get.find<AuthController>();

    // Trigger an immediate session check (StudentController polls every 30s
    // automatically, but we want a fresh check on first open)
    _attendance.checkActiveSession();
    _student.fetchDashboard();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh session check when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _attendance.checkActiveSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                _attendance.checkActiveSession(),
                _student.refresh(),
              ]);
            },
            color: AppTheme.primary,
            backgroundColor: AppTheme.bgCard,
            child: CustomScrollView(
              slivers: [
                // ─── Top App Bar ─────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Obx(() {
                            final name = _auth.currentStudent.value?.name ?? 'Student';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Good ${_greeting()}, 👋',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  name.split(' ').first,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        // ─── Avatar ───────────────────────────
                        GestureDetector(
                          onTap: () => _showProfileMenu(context, _auth),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Obx(() {
                                final name = _auth.currentStudent.value?.name ?? 'S';
                                return Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Student Info Strip ───────────────────────
                SliverToBoxAdapter(
                  child: Obx(() {
                    final s = _auth.currentStudent.value;
                    if (s == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.school_outlined,
                                color: AppTheme.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${s.regNo} • ${s.department} • Year ${s.year} - ${s.section}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),

                // ─── Face Registration Warning ────────────────
                SliverToBoxAdapter(
                  child: Obx(() {
                    final s = _auth.currentStudent.value;
                    if (s == null || s.hasFaceRegistered) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: GestureDetector(
                        onTap: () => Get.toNamed(AppConstants.routeFaceRegister),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.warning.withValues(alpha: 0.15),
                                AppTheme.error.withValues(alpha: 0.10),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.warning.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.face_retouching_off_rounded,
                                  color: AppTheme.warning, size: 22),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '⚠️ Face Not Registered',
                                      style: TextStyle(
                                        color: AppTheme.warning,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Tap here to complete face registration — required for attendance.',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: AppTheme.warning, size: 14),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ─── Active Session Card ──────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Obx(() => _ActiveSessionCard(attendance: _attendance)),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ─── Attendance Overview Card ─────────────────
                SliverToBoxAdapter(
                  child: Obx(() {
                    final stats = _student.dashboardStats.value;
                    if (stats == null) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: _LoadingCard(),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GlassmorphismCard(
                        child: Row(
                          children: [
                            _AttendanceRing(percentage: stats.attendancePercentage),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Overall Attendance',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _InfoRow(
                                    label: 'Total Classes',
                                    value: '${stats.totalClasses}',
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  _InfoRow(
                                    label: 'Attended',
                                    value: '${stats.attendedClasses}',
                                    color: AppTheme.success,
                                  ),
                                  const SizedBox(height: 8),
                                  _InfoRow(
                                    label: 'Missed',
                                    value: '${stats.totalClasses - stats.attendedClasses}',
                                    color: AppTheme.error,
                                  ),
                                  const SizedBox(height: 12),
                                  if (stats.attendancePercentage < 75.0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppTheme.error.withValues(alpha: 0.3)),
                                      ),
                                      child: const Text(
                                        '⚠ Below 75% Threshold',
                                        style: TextStyle(
                                          color: AppTheme.error,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ─── Section Title ────────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(
                      'Subject-wise Attendance',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // ─── Subject Cards ────────────────────────────
                Obx(() {
                  final stats = _student.dashboardStats.value;
                  if (stats == null) {
                    return const SliverToBoxAdapter(child: SizedBox(height: 100));
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final subject = stats.subjectWise[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: _SubjectCard(subject: subject),
                        );
                      },
                      childCount: stats.subjectWise.length,
                    ),
                  );
                }),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ─── Recent Activity ──────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Get.toNamed(AppConstants.routeAttendanceHistory),
                          child: const Text(
                            'See All',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Obx(() {
                  final stats = _student.dashboardStats.value;
                  if (stats == null || stats.recentHistory.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No attendance records yet',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final record = stats.recentHistory[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                          child: GlassmorphismCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.book_outlined,
                                      color: AppTheme.primary, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record.subjectName ?? 'Unknown Subject',
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${DateFormat('EEE, d MMM').format(record.date)} • ${record.time}',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AttendanceBadge(status: record.status),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: stats.recentHistory.take(5).length,
                    ),
                  );
                }),

                // ─── View All History Button ──────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    child: TextButton(
                      onPressed: () =>
                          Get.toNamed(AppConstants.routeAttendanceHistory),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View Full History',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded,
                              color: AppTheme.primary, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  void _showProfileMenu(BuildContext context, AuthController auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Obx(() {
              final s = auth.currentStudent.value;
              return ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (s?.name ?? 'S')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                title: Text(s?.name ?? '',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700)),
                subtitle: Text(s?.email ?? '',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              );
            }),
            const Divider(color: AppTheme.bgCardLight),
            ListTile(
              leading: const Icon(Icons.person_rounded, color: AppTheme.primary),
              title: const Text('My Profile',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Get.back();
                Get.toNamed(AppConstants.routeProfile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded, color: AppTheme.accent),
              title: const Text('Attendance Reports',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Get.back();
                Get.toNamed(AppConstants.routeReports);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded, color: AppTheme.warning),
              title: const Text('Attendance History',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Get.back();
                Get.toNamed(AppConstants.routeAttendanceHistory);
              },
            ),
            const Divider(color: AppTheme.bgCardLight),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.error),
              title: const Text('Logout',
                  style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Get.back();
                auth.logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Active Session Card ─────────────────────────────────────
class _ActiveSessionCard extends StatelessWidget {
  final AttendanceController attendance;
  const _ActiveSessionCard({required this.attendance});

  @override
  Widget build(BuildContext context) {
    // Checking indicator
    if (attendance.isCheckingSession.value && !attendance.hasActiveSession) {
      return _buildCheckingCard();
    }

    // Already marked
    if (attendance.alreadyMarked && attendance.hasActiveSession) {
      return _buildAlreadyMarkedCard();
    }

    // Active session available
    if (attendance.hasActiveSession) {
      return _buildActiveSessionCard(context);
    }

    // No session
    return _buildNoSessionCard();
  }

  Widget _buildCheckingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textHint.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checking Session…',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Looking for an active attendance session…',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSessionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textHint.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.textHint.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: AppTheme.textHint, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Attendance Session is Active',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Wait for your faculty to start an attendance session.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Obx(() => attendance.isCheckingSession.value
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.textHint,
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard(BuildContext context) {
    final session = attendance.activeSession.value!;
    return GestureDetector(
      onTap: () => Get.toNamed(AppConstants.routeClassroomDetection),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2940), Color(0xFF1A3520)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppTheme.success.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.success.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _PulsingDot(),
                const SizedBox(width: 10),
                const Text(
                  'Attendance Session Active',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Session info
            Text(
              session.subjectName,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: AppTheme.textSecondary, size: 14),
                const SizedBox(width: 4),
                Text(
                  session.classroomName,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Start Attendance Button
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.successGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Start Attendance',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyMarkedCard() {
    final session = attendance.activeSession.value!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.12),
            AppTheme.accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance Marked ✅',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'You have already marked attendance for ${session.subjectName}.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing Dot Animation ───────────────────────────────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.success.withValues(alpha: _anim.value * 0.5),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Attendance Ring ─────────────────────────────────────────
class _AttendanceRing extends StatelessWidget {
  final double percentage;
  const _AttendanceRing({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 75
        ? AppTheme.success
        : percentage >= 60
            ? AppTheme.warning
            : AppTheme.error;
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percentage / 100,
            strokeWidth: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const Text(
                'Attended',
                style: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final dynamic subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return GlassmorphismCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded,
                    color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.displayLabel,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (subject.facultyName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subject.facultyName,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _pctColor(subject.percentage).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${subject.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _pctColor(subject.percentage),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: subject.percentage / 100,
              minHeight: 6,
              backgroundColor: _pctColor(subject.percentage).withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_pctColor(subject.percentage)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${subject.attended}/${subject.total} classes',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _pctColor(double pct) {
    if (pct >= 75) return AppTheme.success;
    if (pct >= 60) return AppTheme.warning;
    return AppTheme.error;
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }
}
