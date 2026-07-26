// ============================================================
// SmartAttend — Academic Management Hub Screen (v13 Material 3)
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/erp_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glassmorphism_card.dart';
import 'departments_screen.dart';
import 'erp_subjects_screen.dart';
import 'erp_faculty_screen.dart';
import 'erp_classrooms_screen.dart';
import 'period_timings_screen.dart';
import 'timetable_editor_screen.dart';

class AcademicManagementScreen extends StatelessWidget {
  const AcademicManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final erpCtrl = Get.find<ErpController>();

    final menuItems = [
      {
        'title': 'Departments',
        'subtitle': 'Manage departments, years & section configs',
        'icon': Icons.business_rounded,
        'color': AppTheme.primary,
        'route': const DepartmentsScreen(),
      },
      {
        'title': 'Subjects',
        'subtitle': 'Create & manage subjects for each department',
        'icon': Icons.menu_book_rounded,
        'color': AppTheme.accent,
        'route': const ErpSubjectsScreen(),
      },
      {
        'title': 'Faculty',
        'subtitle': 'Add & assign faculty members with EMP IDs',
        'icon': Icons.people_alt_rounded,
        'color': AppTheme.secondary,
        'route': const ErpFacultyScreen(),
      },
      {
        'title': 'Classrooms',
        'subtitle': 'Manage lecture halls, labs & seminar halls',
        'icon': Icons.meeting_room_rounded,
        'color': const Color(0xFF10B981),
        'route': const ErpClassroomsScreen(),
      },
      {
        'title': 'Period Timings',
        'subtitle': 'Configure daily schedules, breaks & lunch timings',
        'icon': Icons.schedule_rounded,
        'color': const Color(0xFFF59E0B),
        'route': const PeriodTimingsScreen(),
      },
      {
        'title': 'Weekly Timetable',
        'subtitle': 'Spreadsheet-style weekly timetable editor',
        'icon': Icons.table_chart_rounded,
        'color': const Color(0xFF8B5CF6),
        'route': const TimetableEditorScreen(),
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Academic Management',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppTheme.primary),
            tooltip: 'Seed Default Data',
            onPressed: () async {
              await erpCtrl.seedDepartments();
              await erpCtrl.seedClassrooms();
              await erpCtrl.seedPeriodTimings();
              Get.snackbar(
                'Success',
                'Default Departments, Classrooms & Period Timings seeded successfully',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppTheme.success,
                colorText: Colors.white,
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ERP Academic System',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Full manual timetable management — Departments, Faculty, Timings & Timetable grid',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ACADEMIC CONFIGURATION',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textHint,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            ...menuItems.map((item) {
              final color = item['color'] as Color;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: GlassmorphismCard(
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Get.to(() => item['route'] as Widget, transition: Transition.rightToLeft),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(item['icon'] as IconData, color: color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['subtitle'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textHint, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
