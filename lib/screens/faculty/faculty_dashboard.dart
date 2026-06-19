// ============================================================
// SmartAttend — Faculty Dashboard
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/faculty_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/attendance_badge.dart';
import '../../widgets/glassmorphism_card.dart';
import '../../widgets/gradient_button.dart';
import 'package:intl/intl.dart';

class FacultyDashboard extends StatelessWidget {
  const FacultyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final faculty = Get.find<FacultyController>();
    final auth = Get.find<AuthController>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
          child: SafeArea(
            child: Column(
              children: [
                // ─── Header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Obx(() {
                          final name = auth.currentFaculty.value?.name ??
                              'Faculty';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.currentFaculty.value?.department ?? 'Faculty Portal',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      // Create Session Button
                      GestureDetector(
                        onTap: () => _showCreateSessionDialog(context, faculty),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 5),
                              Text(
                                'New Session',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => auth.logout(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.logout_rounded,
                              color: AppTheme.error, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Active Session Banner ────────────────────────
                Obx(() {
                  final session = faculty.activeSession.value;
                  if (session == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.success.withValues(alpha: 0.2),
                            AppTheme.accent.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.success.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppTheme.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Active: ${session.displayLabel}',
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      session.classroomName,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Copy Link button
                              GestureDetector(
                                onTap: () => faculty.copyAttendanceLink(session),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppTheme.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: const Column(
                                    children: [
                                      Text(
                                        'LINK',
                                        style: TextStyle(
                                          color: AppTheme.textHint,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      Icon(Icons.copy_rounded,
                                          color: AppTheme.primary, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.stop_circle_outlined,
                                    color: AppTheme.error),
                                onPressed: () =>
                                    faculty.endSession(session.id),
                                tooltip: 'End Session',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // WhatsApp Share + Copy Link + Live count row
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => faculty.shareViaWhatsApp(session),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFF25D366)
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.share_rounded,
                                            color: Color(0xFF25D366), size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Share via WhatsApp',
                                          style: TextStyle(
                                            color: Color(0xFF25D366),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Copy Link Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => faculty.copyAttendanceLink(session),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppTheme.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.copy_rounded,
                                            color: AppTheme.primary, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Copy Link',
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Obx(() => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.people_rounded,
                                        color: AppTheme.primary, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      '\${faculty.liveAttendanceCount.value} present',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // ─── Tab Bar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const TabBar(
                      tabs: [
                        Tab(text: 'Sessions'),
                        Tab(text: 'Reports'),
                        Tab(text: 'Export'),
                      ],
                      indicator: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.textSecondary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      dividerColor: Colors.transparent,
                      padding: EdgeInsets.all(4),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Tab Views ────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    children: [
                      _SessionsTab(faculty: faculty),
                      _ReportsTab(faculty: faculty),
                      _ExportTab(faculty: faculty),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Create Session Dialog ──────────────────────────────────
  void _showCreateSessionDialog(
      BuildContext context, FacultyController faculty) {
    int? selectedClassroomId;
    int? selectedSubjectId;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const Text(
                'Create New Session',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),

              // Classroom Dropdown
              Obx(() => DropdownButtonFormField<int>(
                    dropdownColor: AppTheme.bgCard,
                    decoration: InputDecoration(
                      labelText: 'Classroom',
                      prefixIcon: const Icon(Icons.meeting_room_outlined,
                          color: AppTheme.primary),
                      filled: true,
                      fillColor: AppTheme.bgCardLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: faculty.classrooms
                        .map((c) => DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(c.roomName),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => selectedClassroomId = v);
                    },
                    hint: const Text('Select Classroom',
                        style: TextStyle(color: AppTheme.textHint)),
                  )),

              const SizedBox(height: 14),

              // Subject Dropdown
              Obx(() => DropdownButtonFormField<int>(
                    dropdownColor: AppTheme.bgCard,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: const Icon(Icons.menu_book_rounded,
                          color: AppTheme.primary),
                      filled: true,
                      fillColor: AppTheme.bgCardLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: faculty.subjects
                        .map((s) => DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(s.displayLabel),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => selectedSubjectId = v);
                    },
                    hint: const Text('Select Subject',
                        style: TextStyle(color: AppTheme.textHint)),
                  )),

              const SizedBox(height: 24),

              Obx(() => GradientButton(
                    text: 'Start Session',
                    icon: Icons.play_arrow_rounded,
                    isLoading: faculty.isCreatingSession.value,
                    onPressed: selectedClassroomId != null &&
                            selectedSubjectId != null
                        ? () {
                            Navigator.pop(ctx);
                            faculty.createSession(
                              classroomId: selectedClassroomId!,
                              subjectId: selectedSubjectId!,
                            );
                          }
                        : null,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sessions Tab ─────────────────────────────────────────────
class _SessionsTab extends StatelessWidget {
  final FacultyController faculty;
  const _SessionsTab({required this.faculty});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (faculty.isLoading.value && faculty.sessions.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary));
      }

      if (faculty.sessions.isEmpty) {
        return const Center(
          child: Text(
            'No sessions yet.\nCreate one to start tracking attendance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: faculty.sessions.length,
        itemBuilder: (context, i) {
          final s = faculty.sessions[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassmorphismCard(
              borderColor: s.isActive
                  ? AppTheme.success.withValues(alpha: 0.3)
                  : AppTheme.primary.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: s.isActive
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      s.isActive
                          ? Icons.play_circle_filled_rounded
                          : Icons.stop_circle_outlined,
                      color: s.isActive
                          ? AppTheme.success
                          : AppTheme.textHint,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.displayLabel,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.classroomName} • ${DateFormat('d MMM, hh:mm a').format(s.startTime)}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.attendanceCode,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

// ─── Reports Tab ──────────────────────────────────────────────
class _ReportsTab extends StatefulWidget {
  final FacultyController faculty;
  const _ReportsTab({required this.faculty});

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  String _period = 'weekly';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.faculty.fetchReport(period: _period);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              _PeriodButton(
                  label: 'Daily',
                  isSelected: _period == 'daily',
                  onTap: () {
                    setState(() => _period = 'daily');
                    widget.faculty.fetchReport(period: 'daily');
                  }),
              const SizedBox(width: 8),
              _PeriodButton(
                  label: 'Weekly',
                  isSelected: _period == 'weekly',
                  onTap: () {
                    setState(() => _period = 'weekly');
                    widget.faculty.fetchReport(period: 'weekly');
                  }),
              const SizedBox(width: 8),
              _PeriodButton(
                  label: 'Monthly',
                  isSelected: _period == 'monthly',
                  onTap: () {
                    setState(() => _period = 'monthly');
                    widget.faculty.fetchReport(period: 'monthly');
                  }),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            if (widget.faculty.isReportLoading.value) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary));
            }
            
            if (widget.faculty.reportErrorMessage.value.isNotEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.error,
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.faculty.reportErrorMessage.value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                        label: const Text('Retry'),
                        onPressed: () {
                          widget.faculty.fetchReport(period: _period);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final report = widget.faculty.attendanceReport;
            if (report.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_late_outlined,
                      color: AppTheme.textHint,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No attendance records found',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: report.length,
              itemBuilder: (context, i) {
                final r = report[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassmorphismCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.studentName ?? 'Unknown',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${r.subjectName ?? 'Unknown'} • ${DateFormat('d MMM').format(r.date)}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AttendanceBadge(status: r.status),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

// ─── Export Tab ───────────────────────────────────────────────
class _ExportTab extends StatelessWidget {
  final FacultyController faculty;
  const _ExportTab({required this.faculty});

  @override
  Widget build(BuildContext context) {
    final exports = [
      {
        'title': 'Export as Excel',
        'subtitle': '.xlsx — Full spreadsheet with charts',
        'icon': Icons.table_chart_rounded,
        'color': AppTheme.success,
        'format': 'xlsx',
      },
      {
        'title': 'Export as CSV',
        'subtitle': '.csv — Raw data for analysis',
        'icon': Icons.text_snippet_rounded,
        'color': AppTheme.accent,
        'format': 'csv',
      },
      {
        'title': 'Export as PDF',
        'subtitle': '.pdf — Print-ready report',
        'icon': Icons.picture_as_pdf_rounded,
        'color': AppTheme.error,
        'format': 'pdf',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Download attendance report in your\npreferred format',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ...exports.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassmorphismCard(
                borderColor: (e['color'] as Color).withValues(alpha: 0.2),
                onTap: () =>
                    faculty.exportAndOpenReport(e['format'] as String),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: (e['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(e['icon'] as IconData,
                          color: e['color'] as Color, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['title'] as String,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            e['subtitle'] as String,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(() => faculty.isExporting.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(Icons.download_rounded,
                            color: e['color'] as Color, size: 22)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
