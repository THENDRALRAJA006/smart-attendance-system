// ============================================================
// SmartAttend — Student Dashboard
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/student_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/attendance_badge.dart';
import '../../widgets/glassmorphism_card.dart';
import '../../widgets/stat_card.dart';
import 'package:intl/intl.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final student = Get.find<StudentController>();
    final auth = Get.find<AuthController>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: student.refresh,
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
                            final name = auth.currentStudent.value?.name ?? 'Student';
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
                        // ─── Mark Attendance FAB ──────────────
                        GestureDetector(
                          onTap: () => Get.toNamed(AppConstants.routeClassroomDetection),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.fingerprint,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Mark',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ─── Avatar ───────────────────────────
                        GestureDetector(
                          onTap: () => _showProfileMenu(context, auth),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Obx(() {
                                final name =
                                    auth.currentStudent.value?.name ?? 'S';
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
                    final s = auth.currentStudent.value;
                    if (s == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.school_outlined,
                                color: AppTheme.primary, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${s.regNo} • ${s.department} • Year ${s.year} - ${s.section}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),


                // ─── Face Registration Warning Banner ────────
                SliverToBoxAdapter(
                  child: Obx(() {
                    final s = auth.currentStudent.value;
                    print("===== FACE DEBUG =====");
                    print("Student Name: ${s?.name}");
                    print("Face ID: ${s?.faceId}");
                    print("Face URL: ${s?.faceImageUrl}");
                    print("======================");
                    // Show warning if student has not yet registered their face
                    if (s == null || (s.faceId != null && s.faceId!.isNotEmpty)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: GestureDetector(
                        onTap: () => Get.toNamed(AppConstants.routeFaceRegister),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
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

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ─── Attendance Overview Card ─────────────────
                SliverToBoxAdapter(
                  child: Obx(() {
                    final stats = student.dashboardStats.value;
                    
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
                            AttendanceRing(
                              percentage: stats.attendancePercentage,
                              size: 110,
                            ),
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
                                    value:
                                        '${stats.totalClasses - stats.attendedClasses}',
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
                                            color:
                                                AppTheme.error.withValues(alpha: 0.3)),
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
                  final stats = student.dashboardStats.value;
                  if (stats == null) {
                    return const SliverToBoxAdapter(
                        child: SizedBox(height: 100));
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
                  final stats = student.dashboardStats.value;
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                    style:
                        const TextStyle(color: AppTheme.textSecondary)),
              );
            }),
            const Divider(color: AppTheme.bgCardLight),
            ListTile(
              leading: const Icon(Icons.person_rounded,
                  color: AppTheme.primary),
              title: const Text('My Profile',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Get.back();
                Get.toNamed(AppConstants.routeProfile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded,
                  color: AppTheme.accent),
              title: const Text('Attendance Reports',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Get.back();
                Get.toNamed(AppConstants.routeReports);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded,
                  color: AppTheme.success),
              title: const Text('Scan QR Attendance',
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text('Fallback when BLE unavailable',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
              onTap: () {
                Get.back();
                Get.toNamed(AppConstants.routeQrScanner);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded,
                  color: AppTheme.warning),
              title: const Text('Attendance History',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Get.back();
                Get.toNamed(AppConstants.routeAttendanceHistory);
              },
            ),
            const Divider(color: AppTheme.bgCardLight),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: AppTheme.error),
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
              valueColor: AlwaysStoppedAnimation<Color>(
                  _pctColor(subject.percentage)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${subject.attended}/${subject.total} classes',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
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
