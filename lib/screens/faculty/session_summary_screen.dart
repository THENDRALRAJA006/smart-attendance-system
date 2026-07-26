// ============================================================
// SmartAttend — Session Summary Screen (v10)
// Post-close view: stats + full attendance roster + export.
// Receives TeacherSessionModel via Get.arguments or fetches
// fresh from /session/details/{id}.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class SessionSummaryScreen extends StatefulWidget {
  const SessionSummaryScreen({super.key});

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  final SessionController _sc = Get.find();
  TeacherSessionModel? _session;
  bool _loading = true;
  String _filter = 'all'; // all | present | absent | review

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Try argument first (passed from history)
    final arg = Get.arguments;
    if (arg is TeacherSessionModel) {
      // Fetch fresh with full roster
      final fresh = await _sc.fetchSessionDetails(arg.id);
      if (mounted) {
        setState(() {
          _session = fresh ?? arg;
          _loading = false;
        });
      }
    } else if (arg is int) {
      final fresh = await _sc.fetchSessionDetails(arg);
      if (mounted) {
        setState(() {
          _session = fresh;
          _loading = false;
        });
      }
    } else {
      if (mounted) { setState(() => _loading = false); }
    }
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
        title: const Text('Session Summary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (_session != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined,
                  color: AppTheme.accent),
              color: AppTheme.bgCard,
              onSelected: (fmt) =>
                  _sc.exportSession(_session!.id, fmt),
              itemBuilder: (_) => [
                for (final fmt in ['csv', 'xlsx', 'pdf'])
                  PopupMenuItem(
                    value: fmt,
                    child: Row(children: [
                      const Icon(Icons.download,
                          color: AppTheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Text('Export ${fmt.toUpperCase()}',
                          style: const TextStyle(
                              color: AppTheme.textPrimary)),
                    ]),
                  ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _session == null
              ? _noData()
              : _buildContent(_session!),
    );
  }

  Widget _noData() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 56, color: AppTheme.textHint),
          const SizedBox(height: 16),
          const Text('Session not found',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(TeacherSessionModel session) {
    final df = DateFormat('dd MMM yyyy, hh:mm a');
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : Duration(minutes: session.durationMinutes);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryCard(session, df, duration),
              const SizedBox(height: 16),
              _buildStatsGrid(session),
              const SizedBox(height: 16),
              _buildRosterSection(session),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    TeacherSessionModel session,
    DateFormat df,
    Duration duration,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0A40), Color(0xFF2D1B69)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: AppTheme.success, size: 20),
              const SizedBox(width: 6),
              const Text('COMPLETED',
                  style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (session.classBadge.isNotEmpty)
            Text(session.classBadge,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13)),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          _detailRow(
              'Started', df.format(session.startTime.toLocal())),
          if (session.endTime != null)
            _detailRow(
                'Ended', df.format(session.endTime!.toLocal())),
          _detailRow('Duration',
              '${duration.inMinutes} min'),
          _detailRow(
              'Classroom',
              session.classroomName
                  .replaceAll('CLASSROOM_', '')),
          _detailRow('BLE Radius',
              '${session.attendanceRadius} m'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12)),
          ),
          Text(' · ',
              style: const TextStyle(color: Colors.white38)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(TeacherSessionModel session) {
    final percentage = session.totalStudents > 0
        ? (session.attendanceCount / session.totalStudents * 100)
        : 0.0;

    return Row(
      children: [
        _statBox(
          label: 'Present',
          value: '${session.attendanceCount}',
          color: AppTheme.success,
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(width: 10),
        _statBox(
          label: 'Absent',
          value: '${session.absentCount}',
          color: AppTheme.error,
          icon: Icons.cancel_outlined,
        ),
        const SizedBox(width: 10),
        _statBox(
          label: 'Rate',
          value: '${percentage.toStringAsFixed(0)}%',
          color: AppTheme.accent,
          icon: Icons.pie_chart_outline,
        ),
      ],
    );
  }

  Widget _statBox({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterSection(TeacherSessionModel session) {
    final filtered = _getFiltered(session.students);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Attendance Roster',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const Spacer(),
            Text('${filtered.length} students',
                style: const TextStyle(
                    color: AppTheme.textHint, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        _filterChips(),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No ${_filter == 'all' ? '' : '$_filter '}students',
                  style: const TextStyle(
                      color: AppTheme.textHint)),
            ),
          )
        else
          ...filtered.asMap().entries.map(
                (e) => _rosterTile(e.value, e.key + 1),
              ),
      ],
    );
  }

  List<SessionStudentEntry> _getFiltered(
      List<SessionStudentEntry> all) {
    if (_filter == 'present') {
      return all.where((s) => s.status == 'present').toList();
    } else if (_filter == 'absent') {
      return all.where((s) => s.status == 'absent').toList();
    } else if (_filter == 'review') {
      return all
          .where((s) => s.status == 'manual_review')
          .toList();
    }
    return all;
  }

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in [
            ('all', 'All'),
            ('present', 'Present'),
            ('absent', 'Absent'),
            ('review', 'Review'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.$2),
                selected: _filter == f.$1,
                onSelected: (_) => setState(() => _filter = f.$1),
                selectedColor:
                    AppTheme.primary.withValues(alpha: 0.25),
                checkmarkColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: _filter == f.$1
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: _filter == f.$1
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                backgroundColor: AppTheme.bgCard,
                side: BorderSide(
                  color: _filter == f.$1
                      ? AppTheme.primary
                      : AppTheme.cardBorder,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rosterTile(SessionStudentEntry entry, int index) {
    final statusColor = entry.status == 'present'
        ? AppTheme.success
        : entry.status == 'manual_review'
            ? AppTheme.warning
            : AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('$index',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.studentName,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(entry.regNo,
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.status.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (entry.faceConfidence != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${(entry.faceConfidence! * 100).toStringAsFixed(0)}% match',
                  style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 9),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
