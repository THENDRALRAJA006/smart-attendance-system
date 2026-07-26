// ============================================================
// SmartAttend — Session History Screen (v10)
// Paginated list of teacher's past sessions.
// Tap → Session Summary screen.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/session_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  final SessionController _sc = Get.find();
  final _scroll = ScrollController();
  String _filter = 'all'; // all | active | closed

  @override
  void initState() {
    super.initState();
    _sc.fetchSessionHistory();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100) {
      if (!_sc.isLoading.value &&
          _sc.sessionHistory.length < _sc.totalHistory.value) {
        _sc.fetchSessionHistory(
          offset: _sc.sessionHistory.length,
        );
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
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
        title: const Text('Session History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: () => _sc.fetchSessionHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: Obx(() {
              final sessions = _filteredSessions;
              if (_sc.isLoading.value && sessions.isEmpty) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary));
              }
              if (sessions.isEmpty) {
                return _emptyState();
              }
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: sessions.length +
                    (_sc.isLoading.value ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == sessions.length) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          color: AppTheme.primary),
                    ));
                  }
                  return _sessionCard(sessions[i]);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  List<TeacherSessionModel> get _filteredSessions {
    if (_filter == 'active') {
      return _sc.sessionHistory.where((s) => s.isActive).toList();
    } else if (_filter == 'closed') {
      return _sc.sessionHistory.where((s) => !s.isActive).toList();
    }
    return _sc.sessionHistory.toList();
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (final f in [
            ('all', 'All Sessions'),
            ('active', 'Active'),
            ('closed', 'Closed'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.$2),
                selected: _filter == f.$1,
                onSelected: (_) => setState(() => _filter = f.$1),
                selectedColor: AppTheme.primary.withValues(alpha: 0.25),
                checkmarkColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: _filter == f.$1
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                  fontSize: 12,
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

  Widget _sessionCard(TeacherSessionModel session) {
    final isActive = session.isActive;
    final statusColor = isActive ? AppTheme.success : AppTheme.textHint;
    final df = DateFormat('dd MMM yyyy');
    final tf = DateFormat('hh:mm a');

    final attendancePercent = session.totalStudents > 0
        ? (session.attendanceCount / session.totalStudents * 100)
            .toStringAsFixed(0)
        : '--';

    return GestureDetector(
      onTap: () {
        if (isActive) {
          Get.toNamed(AppConstants.routeActiveSession);
        } else {
          Get.toNamed(AppConstants.routeSessionSummary, arguments: session);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppTheme.success.withValues(alpha: 0.4)
                : AppTheme.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.displayName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'CLOSED',
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Meta info
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _chip(Icons.calendar_today_outlined,
                    df.format(session.startTime.toLocal())),
                _chip(Icons.access_time,
                    tf.format(session.startTime.toLocal())),
                if (session.classBadge.isNotEmpty)
                  _chip(Icons.class_outlined, session.classBadge),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: session.totalStudents > 0
                          ? session.attendanceCount / session.totalStudents
                          : 0,
                      backgroundColor:
                          AppTheme.cardBorder.withValues(alpha: 0.5),
                      valueColor:
                          const AlwaysStoppedAnimation(AppTheme.success),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${session.attendanceCount}/${session.totalStudents} ($attendancePercent%)',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textHint),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textHint, fontSize: 11)),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 56, color: AppTheme.textHint),
            const SizedBox(height: 16),
            const Text('No sessions yet',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Your session history will appear here.',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  Get.toNamed(AppConstants.routeStartSession),
              icon: const Icon(Icons.play_circle_filled),
              label: const Text('Start First Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
