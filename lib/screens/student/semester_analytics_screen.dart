// ============================================================
// SmartAttend — Semester Analytics Screen (v11)
// Summary cards + monthly bar chart + subject rankings.
// Uses fl_chart (already in pubspec.yaml).
// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/student_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/glassmorphism_card.dart';

class SemesterAnalyticsScreen extends StatefulWidget {
  const SemesterAnalyticsScreen({super.key});

  @override
  State<SemesterAnalyticsScreen> createState() =>
      _SemesterAnalyticsScreenState();
}

class _SemesterAnalyticsScreenState extends State<SemesterAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final StudentController _ctrl = Get.find();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    Future.wait([
      _ctrl.fetchAnalytics(),
      _ctrl.fetchMonthlyStats(),
    ]).then((_) => _fadeCtrl.forward());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
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
        title: const Text('Semester Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (_ctrl.isLoadingAnalytics.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          final ana = _ctrl.analytics.value;
          if (ana == null) {
            return _buildEmpty();
          }
          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                _ctrl.fetchAnalytics(),
                _ctrl.fetchMonthlyStats(),
              ]);
            },
            color: AppTheme.primary,
            backgroundColor: AppTheme.bgCard,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _buildContent(ana),
            ),
          );
        }),
      ),
    );
  }


  Widget _buildContent(SemesterAnalyticsModel ana) {
    return CustomScrollView(
      slivers: [
        // ── Overall ring + status ────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _OverallCard(ana: ana),
          ),
        ),

        // ── Quick Summary Grid ───────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _SummaryGrid(ana: ana),
          ),
        ),

        // ── Highest & Lowest ────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _HighLowRow(ana: ana),
          ),
        ),

        // ── Monthly Chart ────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Obx(() => _MonthlyChart(
                  months: _ctrl.monthlyStats,
                )),
          ),
        ),

        // ── Subject Rankings ─────────────────────────────
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(
              'Subject Rankings',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final sorted = [...ana.subjects]
                ..sort((a, b) => b.percentage.compareTo(a.percentage));
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: _RankCard(rank: i + 1, subject: sorted[i]),
              );
            },
            childCount: ana.subjects.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text('No analytics data available.',
          style: TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

// ─── Overall Card ─────────────────────────────────────────────
class _OverallCard extends StatelessWidget {
  final SemesterAnalyticsModel ana;
  const _OverallCard({required this.ana});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(ana.statusLabel);
    return GlassmorphismCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Circular ring
          SizedBox(
            width: 110, height: 110,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: ana.overallPercentage / 100),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, val, __) => Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: val,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(val * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: color, fontWeight: FontWeight.w800,
                          fontSize: 16),
                      ),
                      Text('Overall',
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(ana.statusLabel,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
                const SizedBox(height: 10),
                _MiniRow('Present', '${ana.totalPresent}', AppTheme.success),
                const SizedBox(height: 6),
                _MiniRow('Absent', '${ana.totalAbsent}', AppTheme.error),
                const SizedBox(height: 6),
                _MiniRow('Total', '${ana.totalClasses}', AppTheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12))),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}

// ─── Summary Grid ─────────────────────────────────────────────
class _SummaryGrid extends StatelessWidget {
  final SemesterAnalyticsModel ana;
  const _SummaryGrid({required this.ana});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GridCard(
            label: 'Subjects', value: '${ana.totalSubjects}',
            icon: Icons.menu_book_rounded, color: AppTheme.primary),
        const SizedBox(width: 10),
        _GridCard(
            label: 'Current Streak',
            value: '${ana.currentStreak}d',
            icon: Icons.local_fire_department_rounded,
            color: AppTheme.warning),
        const SizedBox(width: 10),
        _GridCard(
            label: 'Longest Streak',
            value: '${ana.longestStreak}d',
            icon: Icons.emoji_events_rounded,
            color: AppTheme.accent),
      ],
    );
  }
}

class _GridCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _GridCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textHint, fontSize: 10),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── High / Low Row ───────────────────────────────────────────
class _HighLowRow extends StatelessWidget {
  final SemesterAnalyticsModel ana;
  const _HighLowRow({required this.ana});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (ana.highestSubject != null)
          Expanded(
            child: _HighLowCard(
              label: '🏆 Highest',
              subject: ana.highestSubject!,
              color: AppTheme.success,
            ),
          ),
        if (ana.highestSubject != null && ana.lowestSubject != null)
          const SizedBox(width: 10),
        if (ana.lowestSubject != null)
          Expanded(
            child: _HighLowCard(
              label: '⚠ Lowest',
              subject: ana.lowestSubject!,
              color: AppTheme.error,
            ),
          ),
      ],
    );
  }
}

class _HighLowCard extends StatelessWidget {
  final String label;
  final SubjectAttendance subject;
  final Color color;
  const _HighLowCard(
      {required this.label, required this.subject, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassmorphismCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            subject.subjectName,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${subject.percentage.toStringAsFixed(1)}%',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

// ─── Monthly Chart ────────────────────────────────────────────
class _MonthlyChart extends StatelessWidget {
  final List<MonthlyStatsModel> months;
  const _MonthlyChart({required this.months});

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = months
        .map((m) => m.present + m.absent)
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();

    return GlassmorphismCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Attendance',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Present vs Absent per month',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY * 1.2 : 10,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final m = months[group.x];
                      return BarTooltipItem(
                        '${m.monthName}\n',
                        const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                        children: [
                          TextSpan(
                            text: rodIndex == 0
                                ? 'Present: ${m.present}'
                                : 'Absent: ${m.absent}',
                            style: TextStyle(
                              color: rodIndex == 0
                                  ? AppTheme.success
                                  : AppTheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final i = val.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            months[i].monthName.substring(0, 3),
                            style: const TextStyle(
                                color: AppTheme.textHint, fontSize: 9),
                          ),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.cardBorder.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(months.length, (i) {
                  final m = months[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: m.present.toDouble(),
                        color: AppTheme.success,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: m.absent.toDouble(),
                        color: AppTheme.error.withValues(alpha: 0.7),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppTheme.success, label: 'Present'),
              const SizedBox(width: 20),
              _LegendDot(color: AppTheme.error, label: 'Absent'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ─── Rank Card ────────────────────────────────────────────────
class _RankCard extends StatelessWidget {
  final int rank;
  final SubjectAttendance subject;
  const _RankCard({required this.rank, required this.subject});

  @override
  Widget build(BuildContext context) {
    final color = subject.percentage >= 90
        ? AppTheme.success
        : subject.percentage >= 75
            ? const Color(0xFF2196F3)
            : subject.percentage >= 60
                ? AppTheme.warning
                : AppTheme.error;

    return GlassmorphismCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? AppTheme.accent.withValues(alpha: 0.15)
                  : AppTheme.bgCard,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rank <= 3 ? AppTheme.accent : AppTheme.textHint,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Subject info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.displayLabel,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: subject.percentage / 100),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, __) => LinearProgressIndicator(
                      value: val,
                      minHeight: 5,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Percentage
          Text(
            '${subject.percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String label) {
  switch (label) {
    case 'Excellent': return AppTheme.success;
    case 'Good':      return const Color(0xFF2196F3);
    case 'Warning':   return AppTheme.warning;
    default:          return AppTheme.error;
  }
}
