// ============================================================
// SmartAttend — Admin Dashboard (v12 Premium Light)
// Overview stats, attendance trend chart, quick actions,
// recent activity. All AdminController bindings preserved.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:intl/intl.dart';

import '../../../controllers/admin_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../widgets/sa_widgets.dart';
import '../students/students_screen.dart';
import '../staff/staff_screen.dart';
import '../classes/classes_screen.dart';
import '../ble/ble_management_screen.dart';
import '../reports/admin_reports_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();
    return RefreshIndicator(
      onRefresh: ctrl.fetchDashboard,
      color: AppTheme.primary,
      backgroundColor: AppTheme.bgCard,
      child: Obx(() {
        if (ctrl.isLoading.value && ctrl.dashboardStats.value.totalStudents == 0) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final s = ctrl.dashboardStats.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            _SystemOverviewCard(stats: s),
            const SizedBox(height: 20),
            _TodayStatsRow(stats: s),
            const SizedBox(height: 20),
            _OverviewGrid(stats: s),
            const SizedBox(height: 20),
            _AttendanceTrendCard(stats: s),
            const SizedBox(height: 20),
            _QuickActionsCard(),
            const SizedBox(height: 20),
            _RecentActivityCard(activities: s.recentActivity),
          ],
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// System Overview Hero
// ═══════════════════════════════════════════════════════════
class _SystemOverviewCard extends StatelessWidget {
  final AdminDashboardStats stats;
  const _SystemOverviewCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rate = stats.systemAttendanceRate;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('System Overview',
              style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle,
                  color: stats.activeSessions > 0 ? Colors.greenAccent : Colors.white54,
                  size: 8),
              const SizedBox(width: 6),
              Text(stats.activeSessions > 0
                  ? '${stats.activeSessions} Live'
                  : 'All Clear',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text('${rate.toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 40,
                fontWeight: FontWeight.w800, height: 1)),
        Text('Overall Attendance Rate',
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13)),
        const SizedBox(height: 16),
        Row(children: [
          _Pill('${stats.totalStudents} Students'),
          const SizedBox(width: 8),
          _Pill('${stats.totalFaculty} Faculty'),
          const SizedBox(width: 8),
          _Pill('${stats.totalDepartments} Depts'),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: GoogleFonts.poppins(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
  );
}

// ═══════════════════════════════════════════════════════════
// Today Stats Row
// ═══════════════════════════════════════════════════════════
class _TodayStatsRow extends StatelessWidget {
  final AdminDashboardStats stats;
  const _TodayStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _TodayChip(
        label: "Today's Total",
        value: '${stats.todayTotal}',
        icon: Icons.sensors_rounded,
        color: AppTheme.primary,
      )),
      const SizedBox(width: 12),
      Expanded(child: _TodayChip(
        label: 'Present Today',
        value: '${stats.todayPresent}',
        icon: Icons.how_to_reg_rounded,
        color: AppTheme.success,
      )),
      const SizedBox(width: 12),
      Expanded(child: _TodayChip(
        label: 'Absent Today',
        value: '${stats.todayAbsent}',
        icon: Icons.cancel_outlined,
        color: AppTheme.error,
      )),
    ]);
  }
}

class _TodayChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _TodayChip({required this.label, required this.value,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
            maxLines: 2),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Overview Grid
// ═══════════════════════════════════════════════════════════
class _OverviewGrid extends StatelessWidget {
  final AdminDashboardStats stats;
  const _OverviewGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'label': 'Total Students',   'value': '${stats.totalStudents}',   'icon': Icons.school_rounded,        'color': AppTheme.primary},
      {'label': 'Total Faculty',    'value': '${stats.totalFaculty}',    'icon': Icons.badge_rounded,          'color': AppTheme.secondary},
      {'label': 'Departments',      'value': '${stats.totalDepartments}','icon': Icons.account_tree_rounded,   'color': AppTheme.accent},
      {'label': 'Active Sessions',  'value': '${stats.activeSessions}',  'icon': Icons.book_outlined,          'color': AppTheme.accentTeal},
      {'label': 'Classrooms',       'value': '${stats.totalClassrooms}', 'icon': Icons.meeting_room_outlined,  'color': AppTheme.warning},
      {'label': 'Registered Faces', 'value': '${stats.registeredFaces}', 'icon': Icons.face_rounded,           'color': AppTheme.success},
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SASectionHeader(title: 'System Statistics'),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: items.map((item) {
          final color = item['color'] as Color;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.subtleShadow,
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item['icon'] as IconData, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item['value'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  Text(item['label'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppTheme.textSecondary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              )),
            ]),
          );
        }).toList(),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// Attendance Trend Chart
// ═══════════════════════════════════════════════════════════
class _AttendanceTrendCard extends StatelessWidget {
  final AdminDashboardStats stats;
  const _AttendanceTrendCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    // Use monthlyTrends to derive a chart — take up to 7 months
    final trends = stats.monthlyTrends;
    if (trends.isEmpty) return const SizedBox.shrink();

    final spots = trends.take(7).toList().asMap().entries.map((e) {
      final total = e.value.total == 0 ? 1 : e.value.total;
      final rate  = (e.value.present / total * 100).clamp(0, 100).toDouble();
      return FlSpot(e.key.toDouble(), rate);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Attendance Trend',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary))),
          Text('Last 7 days',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 140,
          child: LineChart(LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (v) => FlLine(
                color: AppTheme.border, strokeWidth: 1, dashArray: [4, 4]),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 25,
                  getTitlesWidget: (v, m) => Text(
                    '${v.toInt()}%',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppTheme.textHint)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, m) {
                    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    final idx = v.toInt();
                    if (idx < 0 || idx >= days.length) return const SizedBox();
                    return Text(days[idx],
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: AppTheme.textHint));
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minY: 0, maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppTheme.primary,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (s, x, b, i) => FlDotCirclePainter(
                    radius: 4,
                    color: AppTheme.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.15),
                      AppTheme.primary.withValues(alpha: 0.01),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          )),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Quick Actions
// ═══════════════════════════════════════════════════════════
class _QuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        'label': 'Add Student',
        'icon': Icons.person_add_rounded,
        'color': AppTheme.primary,
        'onTap': () => Get.to(() => const StudentsScreen(), transition: Transition.rightToLeft),
      },
      {
        'label': 'Add Faculty',
        'icon': Icons.badge_rounded,
        'color': AppTheme.secondary,
        'onTap': () => Get.to(() => const StaffScreen(), transition: Transition.rightToLeft),
      },
      {
        'label': 'New Subject',
        'icon': Icons.book_rounded,
        'color': AppTheme.accent,
        'onTap': () => Get.to(() => const ClassesScreen(), transition: Transition.rightToLeft),
      },
      {
        'label': 'View Reports',
        'icon': Icons.assessment_rounded,
        'color': AppTheme.success,
        'onTap': () => Get.to(() => const AdminReportsScreen(), transition: Transition.rightToLeft),
      },
      {
        'label': 'Timetable',
        'icon': Icons.schedule_rounded,
        'color': AppTheme.accentTeal,
        'onTap': () => Get.toNamed(AppConstants.routeAdminTimetable),
      },
      {
        'label': 'BLE Devices',
        'icon': Icons.bluetooth_rounded,
        'color': const Color(0xFF3B82F6),
        'onTap': () => Get.to(() => const BleManagementScreen(), transition: Transition.rightToLeft),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SASectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: actions.map((a) {
            final color = a['color'] as Color;
            final onTap = a['onTap'] as VoidCallback;
            return GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(a['icon'] as IconData, color: color, size: 24),
                    const SizedBox(height: 6),
                    Text(a['label'] as String,
                        style: GoogleFonts.poppins(
                            fontSize: 10, fontWeight: FontWeight.w600,
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

// ═══════════════════════════════════════════════════════════
// Recent Activity
// ═══════════════════════════════════════════════════════════
class _RecentActivityCard extends StatelessWidget {
  final List<dynamic> activities;
  const _RecentActivityCard({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SASectionHeader(title: 'Recent Activity'),
        const SizedBox(height: 14),
        ...activities.take(6).map((a) => _ActivityRow(activity: a)),
      ]),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final dynamic activity;
  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    String title = 'System Activity';
    String detail = '';
    String time = '';

    if (activity is AuditLogModel) {
      final log = activity as AuditLogModel;
      title = log.action.replaceAll('_', ' ');
      if (log.actorName != null && log.actorName!.isNotEmpty) {
        title = '${log.actorName}: $title';
      }
      detail = log.detail ?? '';
      time = DateFormat('MMM d, hh:mm a').format(log.createdAt);
    } else if (activity is Map) {
      title = activity['action']?.toString().replaceAll('_', ' ') ?? 'Activity';
      detail = activity['detail']?.toString() ?? '';
    } else {
      title = activity.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.circle_notifications_rounded,
              color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (detail.isNotEmpty)
            Text(detail,
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (time.isNotEmpty)
          Text(time, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
      ]),
    );
  }
}
