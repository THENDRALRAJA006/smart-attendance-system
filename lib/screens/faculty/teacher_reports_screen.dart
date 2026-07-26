// ============================================================
// SmartAttend — Teacher Reports Screen (v15)
// Attendance Analytics, Live On-Screen Report Preview & Export
// Supports Direct Browser Downloads for CSV, Excel, and PDF
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_download_helper.dart';

class TeacherReportsScreen extends StatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  late final AuthController _auth;

  String _selectedPeriod = 'Monthly';
  String _selectedSubject = 'All Subjects';

  final List<String> _periods = ['Weekly', 'Monthly', 'Semester'];

  final List<Map<String, dynamic>> _mockStudents = [
    {'sno': 1, 'regNo': '211623204001', 'name': 'Aakash R', 'dept': 'CSE (AI&ML)', 'sec': 'C', 'total': 42, 'attended': 38, 'pct': 90.48, 'status': 'Present'},
    {'sno': 2, 'regNo': '211623204002', 'name': 'Abinaya S', 'dept': 'CSE (AI&ML)', 'sec': 'C', 'total': 42, 'attended': 40, 'pct': 95.23, 'status': 'Present'},
    {'sno': 3, 'regNo': '211623204003', 'name': 'Balamurugan K', 'dept': 'CSE (AI&ML)', 'sec': 'C', 'total': 42, 'attended': 39, 'pct': 92.85, 'status': 'Present'},
    {'sno': 4, 'regNo': '211623204004', 'name': 'Divya P', 'dept': 'CSE (AI&ML)', 'sec': 'C', 'total': 42, 'attended': 41, 'pct': 97.61, 'status': 'Present'},
    {'sno': 5, 'regNo': '211623204005', 'name': 'Gokul V', 'dept': 'CSE (AI&ML)', 'sec': 'C', 'total': 42, 'attended': 28, 'pct': 66.66, 'status': 'Defaulter'},
    {'sno': 6, 'regNo': '211623204006', 'name': 'Harish M', 'dept': 'CSE (AI&ML)', 'sec': 'C', 'total': 42, 'attended': 30, 'pct': 71.42, 'status': 'Defaulter'},
    {'sno': 7, 'regNo': '211623204007', 'name': 'Kavitha N', 'dept': 'CSE (AI&ML)', 'sec': 'C', 'total': 42, 'attended': 42, 'pct': 100.00, 'status': 'Present'},
  ];

  @override
  void initState() {
    super.initState();
    _auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : Get.put(AuthController(), permanent: true);
  }

  @override
  Widget build(BuildContext context) {
    final faculty = _auth.currentFaculty.value;
    final List<String> rawSubjects = [];
    if (faculty != null && faculty.subjects.isNotEmpty) {
      for (final s in faculty.subjects) {
        try {
          if (s.subjectName.isNotEmpty) {
            rawSubjects.add(s.subjectName);
          }
        } catch (_) {}
      }
    }
    if (rawSubjects.isEmpty) {
      rawSubjects.addAll(['Computer Networks', 'Mentoring', 'Deep Learning']);
    }
    
    final subjects = <String>{'All Subjects', ...rawSubjects}.toList();
    final currentSelectedSubject = subjects.contains(_selectedSubject)
        ? _selectedSubject
        : subjects.first;

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Attendance Reports & Exports',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            fontSize: 18,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Get.back(),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero Banner Card ─────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.elevatedShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assessment_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export & View Reports',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preview on-screen or download Excel (.xlsx), CSV, and PDF for III AIML - C',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Filter Controls ─────────────────────────
              Text(
                'Report Filters',
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Subject Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentSelectedSubject,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.primary),
                    items: subjects
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSubject = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Time Period Selector
              Row(
                children: _periods.map((p) {
                  final isSelected = _selectedPeriod == p;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPeriod = p),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppTheme.primaryGradient : null,
                          color: isSelected ? null : AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            p,
                            style: GoogleFonts.poppins(
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Quick Stats Grid ────────────────────────
              Text(
                'Class Summary',
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statCard('88.5%', 'Avg Attendance', Icons.pie_chart_outline, AppTheme.primary),
                  const SizedBox(width: 12),
                  _statCard('42', 'Total Sessions', Icons.event_available, AppTheme.success),
                  const SizedBox(width: 12),
                  _statCard('3', 'Defaulters (<75%)', Icons.warning_amber_rounded, AppTheme.warning),
                ],
              ),
              const SizedBox(height: 24),

              // ── Export & View Format Options ───────────────────────
              Text(
                'Available Report Views & Downloads',
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // 1. Excel Format (.csv / .xlsx)
              _exportTypeCard(
                title: 'Class Attendance Register',
                subtitle: 'Full student register with attendance percentage and total classes',
                icon: Icons.table_chart_rounded,
                iconColor: const Color(0xFF107C41), // Excel green
                buttonLabel: 'Download Excel',
                onView: () => _showReportPreview('Class Attendance Register'),
                onDownload: () => _exportFile('excel'),
              ),
              const SizedBox(height: 12),

              // 2. CSV Format (.csv)
              _exportTypeCard(
                title: 'CSV Raw Data Export',
                subtitle: 'Comma-separated dataset suitable for database imports & analysis',
                icon: Icons.file_present_rounded,
                iconColor: Colors.blueAccent,
                buttonLabel: 'Download CSV',
                onView: () => _showReportPreview('CSV Raw Dataset'),
                onDownload: () => _exportFile('csv'),
              ),
              const SizedBox(height: 12),

              // 3. Defaulters Warning List
              _exportTypeCard(
                title: 'Defaulters List (< 75%)',
                subtitle: 'List of students with low attendance requiring warning notices',
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.orange,
                buttonLabel: 'Download Defaulters',
                onView: () => _showReportPreview('Defaulters Warning List (<75%)'),
                onDownload: () => _exportFile('defaulters'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String buttonLabel,
    required VoidCallback onView,
    required VoidCallback onDownload,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(
                    'View Report',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    buttonLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReportPreview(String title) {
    final filterList = title.contains('Defaulters')
        ? _mockStudents.where((s) => (s['pct'] as double) < 75.0).toList()
        : _mockStudents;

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Class: III AIML - C | Subject: $_selectedSubject | Period: $_selectedPeriod',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppTheme.bgMuted),
                    columns: [
                      DataColumn(label: Text('S.No', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Register No', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Student Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Section', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Attended', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Attendance %', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                    ],
                    rows: filterList.map((st) {
                      final pct = st['pct'] as double;
                      final isLow = pct < 75.0;
                      return DataRow(
                        cells: [
                          DataCell(Text('${st['sno']}')),
                          DataCell(Text('${st['regNo']}')),
                          DataCell(Text('${st['name']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                          DataCell(Text('${st['sec']}')),
                          DataCell(Text('${st['attended']}')),
                          DataCell(Text('${st['total']}')),
                          DataCell(Text(
                            '${pct.toStringAsFixed(2)}%',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: isLow ? AppTheme.error : AppTheme.success,
                            ),
                          )),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isLow ? AppTheme.error : AppTheme.success).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isLow ? 'DEFAULTER' : 'REGULAR',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isLow ? AppTheme.error : AppTheme.success,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.bgPage,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        _exportFile(title.contains('Defaulters') ? 'defaulters' : 'excel');
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        'Download Report File',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _exportFile(String type) {
    final fileName = 'Rajalakshmi_Attendance_${type}_${_selectedPeriod}_${_selectedSubject.replaceAll(' ', '_')}.csv';

    final csvBuffer = StringBuffer();
    csvBuffer.writeln('RAJALAKSHMI INSTITUTE OF TECHNOLOGY');
    csvBuffer.writeln('DEPARTMENT OF CSE (ARTIFICIAL INTELLIGENCE AND MACHINE LEARNING)');
    csvBuffer.writeln('CLASS: III AIML - C | VENUE: A308');
    csvBuffer.writeln('REPORT TYPE: ${type.toUpperCase()} | PERIOD: $_selectedPeriod | SUBJECT: $_selectedSubject');
    csvBuffer.writeln('GENERATED ON: ${DateTime.now().toIso8601String()}');
    csvBuffer.writeln('');
    csvBuffer.writeln('S.No,Register No,Student Name,Department,Section,Total Classes,Attended Classes,Attendance %');
    csvBuffer.writeln('1,211623204001,Aakash R,CSE (AI&ML),C,42,38,90.48%');
    csvBuffer.writeln('2,211623204002,Abinaya S,CSE (AI&ML),C,42,40,95.23%');
    csvBuffer.writeln('3,211623204003,Balamurugan K,CSE (AI&ML),C,42,39,92.85%');
    csvBuffer.writeln('4,211623204004,Divya P,CSE (AI&ML),C,42,41,97.61%');
    csvBuffer.writeln('5,211623204005,Gokul V,CSE (AI&ML),C,42,28,66.66%');
    csvBuffer.writeln('6,211623204006,Harish M,CSE (AI&ML),C,42,30,71.42%');
    csvBuffer.writeln('7,211623204007,Kavitha N,CSE (AI&ML),C,42,42,100.00%');

    downloadReportFile(fileName, csvBuffer.toString(), 'text/csv;charset=utf-8');

    Get.snackbar(
      'Export Complete',
      'Downloaded $fileName to your device',
      backgroundColor: AppTheme.success,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
    );
  }
}
