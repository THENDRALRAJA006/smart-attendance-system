// ============================================================
// SmartAttend — Attendance History Screen (v11 Enhanced)
// 5-period filter tabs, faculty name display, grouped by date
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/student_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/attendance_badge.dart';
import '../../widgets/glassmorphism_card.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StudentController _student = Get.find();

  // v11: 5 filter periods
  final List<String> _periods = ['Today', 'Week', 'Month', 'Semester', 'All'];
  final List<String> _periodValues = [
    'today',
    'week',
    'month',
    'semester',
    'all'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: 2);
    _tabController.addListener(_onTabChanged);
    _student.fetchEnhancedHistory(period: 'month');
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _student.fetchEnhancedHistory(
          period: _periodValues[_tabController.index]);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
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
        title: const Text('Attendance History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          GestureDetector(
            onTap: () => Get.toNamed(AppConstants.routeMissedClasses),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel_outlined, color: AppTheme.error, size: 14),
                  SizedBox(width: 4),
                  Text('Missed',
                      style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

              // ─── Tab Bar (5 periods) ────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs:
                        _periods.map((p) => Tab(text: p)).toList(),
                    indicator: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Summary Stats ──────────────────────────────
              Obx(() {
                final history = _student.attendanceHistory;
                if (history.isEmpty) return const SizedBox.shrink();
                final total = history.length;
                final present =
                    history.where((a) => a.status == 'present').length;
                final pct = total > 0
                    ? (present / total * 100).toStringAsFixed(1)
                    : '0.0';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _SummaryChip(
                          label: 'Total',
                          value: '$total',
                          color: AppTheme.primary),
                      const SizedBox(width: 10),
                      _SummaryChip(
                          label: 'Present',
                          value: '$present',
                          color: AppTheme.success),
                      const SizedBox(width: 10),
                      _SummaryChip(
                          label: 'Absent',
                          value: '${total - present}',
                          color: AppTheme.error),
                      const SizedBox(width: 10),
                      _SummaryChip(
                          label: 'Rate',
                          value: '$pct%',
                          color: AppTheme.accent),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),

              // ─── History List ────────────────────────────────
              Expanded(
                child: Obx(() {
                  if (_student.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary),
                    );
                  }

                  final history = _student.attendanceHistory;
                  if (history.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: AppTheme.textHint,
                            size: 56,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No attendance records\nfor this period',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Group by date
                  final grouped = _groupByDate(history);
                  final dates = grouped.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  return RefreshIndicator(
                    onRefresh: () => _student.fetchEnhancedHistory(
                        period: _periodValues[_tabController.index]),
                    color: AppTheme.primary,
                    backgroundColor: AppTheme.bgCard,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: dates.length,
                      itemBuilder: (context, dateIdx) {
                        final date = dates[dateIdx];
                        final records = grouped[date]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date header
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _formatDateHeader(date),
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Records for this date
                            ...records.map(
                              (record) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: GlassmorphismCard(
                                  padding: const EdgeInsets.all(14),
                                  borderColor:
                                      _statusColor(record.status)
                                          .withValues(alpha: 0.15),
                                  child: Row(
                                    children: [
                                      // Status stripe
                                      Container(
                                        width: 4,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                              record.status),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              record.subjectName ??
                                                  'Unknown Subject',
                                              style: const TextStyle(
                                                color:
                                                    AppTheme.textPrimary,
                                                fontWeight:
                                                    FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            // Faculty name (v11)
                                            if (record.facultyName !=
                                                null)
                                              Text(
                                                record.facultyName!,
                                                style: const TextStyle(
                                                  color: AppTheme
                                                      .textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .meeting_room_outlined,
                                                  color: AppTheme.textHint,
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    record.classroomName ??
                                                        '—',
                                                    style: const TextStyle(
                                                      color:
                                                          AppTheme.textHint,
                                                      fontSize: 11,
                                                    ),
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons
                                                      .access_time_rounded,
                                                  color: AppTheme.textHint,
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  record.time,
                                                  style: const TextStyle(
                                                    color: AppTheme.textHint,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      AttendanceBadge(
                                          status: record.status),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
      ),
    );
  }

  Map<DateTime, List<AttendanceModel>> _groupByDate(
      List<AttendanceModel> records) {
    final map = <DateTime, List<AttendanceModel>>{};
    for (final r in records) {
      final key = DateTime(r.date.year, r.date.month, r.date.day);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  String _formatDateHeader(DateTime date) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('EEE, d MMM yyyy').format(date);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return AppTheme.success;
      case 'absent':
        return AppTheme.error;
      case 'late':
        return AppTheme.warning;
      default:
        return AppTheme.textHint;
    }
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
