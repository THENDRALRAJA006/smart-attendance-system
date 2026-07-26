// ============================================================
// SmartAttend — Active Session Screen (v10)
// Live monitor: countdown timer, present/absent counters,
// student roster, end/extend/export actions.
// Auto-polls every 10 seconds via SessionController.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/session_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  final SessionController _sc = Get.find();
  Timer? _localTimer;
  int _localRemaining = 0;

  @override
  void initState() {
    super.initState();
    _sc.fetchActiveSession();
    _sc.startPolling();
    _startLocalCountdown();
  }

  void _startLocalCountdown() {
    _localTimer?.cancel();
    _localRemaining =
        _sc.activeSession.value?.timeRemainingSeconds ?? 0;
    _localTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_localRemaining > 0) {
        if (mounted) setState(() => _localRemaining--);
      } else {
        _localTimer?.cancel();
        // Session may have expired — refresh
        _sc.fetchActiveSession(silent: true);
      }
    });

    // Sync with server refresh
    ever(_sc.activeSession, (s) {
      if (s != null && mounted) {
        setState(() => _localRemaining = s.timeRemainingSeconds);
      }
    });
  }

  @override
  void dispose() {
    _localTimer?.cancel();
    super.dispose();
  }

  String get _timerDisplay {
    if (_localRemaining <= 0) return '00:00';
    final m = _localRemaining ~/ 60;
    final s = _localRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_localRemaining > 300) return AppTheme.success;
    if (_localRemaining > 60)  return AppTheme.warning;
    return AppTheme.error;
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
        title: const Text('Live Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: () => _sc.fetchActiveSession(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Obx(() {
        if (_sc.isLoading.value && _sc.activeSession.value == null) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        if (!_sc.hasActiveSession.value || _sc.activeSession.value == null) {
          return _noActiveSession();
        }

        final session = _sc.activeSession.value!;
        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.bgCard,
          onRefresh: () => _sc.fetchActiveSession(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildSessionHeader(session)),
              SliverToBoxAdapter(child: _buildStatsRow(session)),
              SliverToBoxAdapter(child: _buildActionRow(session)),
              SliverToBoxAdapter(child: _buildRosterHeader(session)),
              if (session.students.isEmpty)
                const SliverToBoxAdapter(child: _EmptyRoster())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _studentTile(session.students[i], i + 1),
                    childCount: session.students.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      }),
    );
  }

  // ── No active session fallback ───────────────────────────
  Widget _noActiveSession() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sensors_off,
                size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            const Text('No Active Session',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Start a session to begin taking attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Get.offNamed(AppConstants.routeStartSession),
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('Start Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Session Header ───────────────────────────────────────
  Widget _buildSessionHeader(TeacherSessionModel session) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppTheme.success.withValues(alpha: 0.25),
              blurRadius: 20)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppTheme.success, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('ACTIVE',
                  style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const Spacer(),
              // Countdown timer
              Text(
                _timerDisplay,
                style: TextStyle(
                    color: _timerColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
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
          const SizedBox(height: 4),
          if (session.classBadge.isNotEmpty)
            Text(
              session.classBadge,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _badgeInfo(Icons.meeting_room_outlined,
                  session.classroomName.replaceAll('CLASSROOM_', '')),
              const SizedBox(width: 12),
              _badgeInfo(Icons.sensors, '${session.attendanceRadius}m radius'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _badgeInfo(Icons.access_time,
                  'Start: ${DateFormat('hh:mm a').format(session.startTime.toLocal())}'),
              if (session.endTime != null) ...[
                const SizedBox(width: 12),
                _badgeInfo(Icons.timer_off,
                    'End: ${DateFormat('hh:mm a').format(session.endTime!.toLocal())}'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white70),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // ── Stats Row ────────────────────────────────────────────
  Widget _buildStatsRow(TeacherSessionModel session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statCard(
            label: 'Present',
            value: '${session.attendanceCount}',
            color: AppTheme.success,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(width: 10),
          _statCard(
            label: 'Absent',
            value: '${session.absentCount}',
            color: AppTheme.error,
            icon: Icons.cancel_outlined,
          ),
          const SizedBox(width: 10),
          _statCard(
            label: 'Total',
            value: '${session.totalStudents}',
            color: AppTheme.accent,
            icon: Icons.people_outline,
          ),
        ],
      ),
    );
  }

  Widget _statCard({
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── Action Row ───────────────────────────────────────────
  Widget _buildActionRow(TeacherSessionModel session) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          // Extend + Export
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: '+5 min',
                  icon: Icons.add_alarm,
                  color: AppTheme.warning,
                  loading: _sc.isExtending.value,
                  onTap: () => _showExtendDialog(session.id),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  label: 'Export',
                  icon: Icons.download_outlined,
                  color: AppTheme.accent,
                  onTap: () => _showExportDialog(session.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // End session
          Obx(() => SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed:
                      _sc.isEnding.value ? null : () => _confirmEnd(session.id),
                  icon: _sc.isEnding.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.stop_circle_outlined),
                  label: Text(
                      _sc.isEnding.value ? 'Ending…' : 'End Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    bool loading = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color))
            else
              Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Roster Header ─────────────────────────────────────────
  Widget _buildRosterHeader(TeacherSessionModel session) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          const Text('Live Roster',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const Spacer(),
          Text('${session.attendanceCount} students',
              style: const TextStyle(
                  color: AppTheme.textHint, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _studentTile(SessionStudentEntry entry, int index) {
    final statusColor = entry.status == 'present'
        ? AppTheme.success
        : entry.status == 'manual_review'
            ? AppTheme.warning
            : AppTheme.error;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          // Index avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$index',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              const SizedBox(height: 2),
              Text(entry.time,
                  style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────
  void _confirmEnd(int sessionId) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppTheme.warning, size: 24),
            SizedBox(width: 8),
            Text('End Session?',
                style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: const Text(
          'Students will no longer be able to mark attendance after this.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              final ok = await _sc.endSession(sessionId);
              if (ok) Get.offNamed(AppConstants.routeTeacherDashboard);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  void _showExtendDialog(int sessionId) {
    int minutes = 5;
    Get.dialog(StatefulBuilder(builder: (_, setS) {
      return AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Extend Session',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many minutes to add?',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final m in [5, 10, 15, 20])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setS(() => minutes = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: minutes == m
                              ? AppTheme.warning
                              : AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: minutes == m
                                ? AppTheme.warning
                                : AppTheme.cardBorder,
                          ),
                        ),
                        child: Text('$m min',
                            style: TextStyle(
                              color: minutes == m
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _sc.extendSession(sessionId, extraMinutes: minutes);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('+$minutes min'),
          ),
        ],
      );
    }));
  }

  void _showExportDialog(int sessionId) {
    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.bgCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Export Attendance',
          style: TextStyle(color: AppTheme.textPrimary)),
      content: const Text('Choose export format:',
          style: TextStyle(color: AppTheme.textSecondary)),
      actions: [
        for (final fmt in ['csv', 'xlsx', 'pdf'])
          TextButton(
            onPressed: () {
              Get.back();
              _sc.exportSession(sessionId, fmt);
            },
            child: Text(
              fmt.toUpperCase(),
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    ));
  }
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty,
                size: 48,
                color: AppTheme.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('Waiting for students…',
                style: TextStyle(
                    color: AppTheme.textHint, fontSize: 14)),
            const Text('Students mark attendance via BLE + Face',
                style: TextStyle(
                    color: AppTheme.textHint, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
