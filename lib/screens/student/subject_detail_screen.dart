// ============================================================
// SmartAttend — Subject Detail Screen (v11)
// Class-by-class attendance log for a single subject.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/student_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/glassmorphism_card.dart';

class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({super.key});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final StudentController _ctrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // Passed via Get.arguments as SubjectAttendance
  SubjectAttendance? _subject;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<StudentController>();

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    final arg = Get.arguments;
    if (arg is SubjectAttendance) {
      _subject = arg;
      if (arg.subjectId != null) {
        _ctrl.fetchSubjectDetail(arg.subjectId!).then((_) => _fadeCtrl.forward());
      }
    } else if (arg is int) {
      _ctrl.fetchSubjectDetail(arg).then((_) => _fadeCtrl.forward());
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Obx(() {
          final name = _ctrl.subjectDetail.value?.subjectName
              ?? _subject?.subjectName
              ?? 'Subject Detail';
          return Text(name);
        }),
      ),
      body: SafeArea(
        child: Obx(() {
          if (_ctrl.isLoadingDetail.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          final detail = _ctrl.subjectDetail.value;
          if (detail == null) {
            return _buildEmpty();
          }
          return FadeTransition(
            opacity: _fadeAnim,
            child: _buildContent(detail),
          );
        }),
      ),
    );
  }


  Widget _buildContent(SubjectDetailModel detail) {
    return CustomScrollView(
      slivers: [
        // ── Stats Header ─────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _StatsHeader(detail: detail),
          ),
        ),

        // ── Progress Bar ────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _ProgressSection(detail: detail),
          ),
        ),

        // ── Class Log Header ─────────────────────────────
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(
              'Class-by-Class Log',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        // ── Class Log List ───────────────────────────────
        if (detail.classLog.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No class records yet.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: _ClassLogCard(entry: detail.classLog[i]),
              ),
              childCount: detail.classLog.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded,
              color: AppTheme.textHint.withValues(alpha: 0.5), size: 60),
          const SizedBox(height: 16),
          const Text('No data available',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Stats Header ────────────────────────────────────────────
class _StatsHeader extends StatelessWidget {
  final SubjectDetailModel detail;
  const _StatsHeader({required this.detail});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(detail.statusLabel);
    return GlassmorphismCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.menu_book_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.subjectCode != null
                          ? '${detail.subjectCode} — ${detail.subjectName}'
                          : detail.subjectName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    if (detail.facultyName != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Faculty: ${detail.facultyName}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                    if (detail.department != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail.department!,
                        style: const TextStyle(
                          color: AppTheme.textHint, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  detail.statusLabel,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats grid
          Row(
            children: [
              _StatBox(label: 'Total', value: '${detail.total}', color: AppTheme.primary),
              _StatBox(label: 'Present', value: '${detail.attended}', color: AppTheme.success),
              _StatBox(label: 'Absent', value: '${detail.absent}', color: AppTheme.error),
              _StatBox(
                label: 'Attendance',
                value: '${detail.percentage.toStringAsFixed(1)}%',
                color: color,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String label) {
    switch (label) {
      case 'Excellent': return AppTheme.success;
      case 'Good':      return const Color(0xFF2196F3);
      case 'Warning':   return AppTheme.warning;
      default:          return AppTheme.error;
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── Progress Section ─────────────────────────────────────────
class _ProgressSection extends StatelessWidget {
  final SubjectDetailModel detail;
  const _ProgressSection({required this.detail});

  @override
  Widget build(BuildContext context) {
    final color = detail.percentage >= 90
        ? AppTheme.success
        : detail.percentage >= 75
            ? const Color(0xFF2196F3)
            : detail.percentage >= 60
                ? AppTheme.warning
                : AppTheme.error;

    return GlassmorphismCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Attendance Progress',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Text(
                '${detail.percentage.toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: detail.percentage / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                minHeight: 10,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          if (detail.percentage < 75.0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.error, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      detail.percentage < 60
                          ? '⚠ Critical — attendance below 60%'
                          : '⚠ Below 75% threshold',
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Class Log Card ───────────────────────────────────────────
class _ClassLogCard extends StatelessWidget {
  final ClassLogEntry entry;
  const _ClassLogCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isPresent = entry.status == 'present';
    final statusColor = isPresent ? AppTheme.success : AppTheme.error;
    final fmt = DateFormat('EEE, d MMM yyyy');

    return GlassmorphismCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Date column
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('d').format(entry.date),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.1,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(entry.date),
                  style: TextStyle(
                    color: statusColor.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmt.format(entry.date),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: AppTheme.textHint, size: 12),
                    const SizedBox(width: 4),
                    Text(entry.time,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined,
                        color: AppTheme.textHint, size: 12),
                    const SizedBox(width: 4),
                    Text(entry.classroom,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
                if (entry.facultyName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Teacher: ${entry.facultyName}',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPresent
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: statusColor,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  isPresent ? 'Present' : 'Absent',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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
