// ============================================================
// SmartAttend — Student Reports Screen
// Subject-wise attendance, monthly trend chart, PDF export
// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/student_controller.dart';
import '../../core/theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final StudentController _ctrl = Get.find<StudentController>();
  bool _loading = true;
  List<Map<String, dynamic>> _subjectStats = [];
  List<Map<String, dynamic>> _monthlyData = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      await _ctrl.loadAttendanceHistory();
      _buildSubjectStats();
      _buildMonthlyData();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _buildSubjectStats() {
    final records = _ctrl.attendanceRecords;
    final bySubject = <String, Map<String, int>>{};
    for (final r in records) {
      final sub = r['subject_name'] ?? 'Unknown';
      bySubject.putIfAbsent(sub, () => {'present': 0, 'total': 0});
      bySubject[sub]!['total'] = bySubject[sub]!['total']! + 1;
      if (r['status'] == 'present') {
        bySubject[sub]!['present'] = bySubject[sub]!['present']! + 1;
      }
    }
    _subjectStats = bySubject.entries.map((e) {
      final pct = e.value['total']! > 0
          ? (e.value['present']! / e.value['total']!) * 100
          : 0.0;
      return {
        'subject': e.key,
        'present': e.value['present'],
        'total': e.value['total'],
        'percentage': pct,
      };
    }).toList()
      ..sort((a, b) => (b['percentage'] as double).compareTo(a['percentage'] as double));
  }

  void _buildMonthlyData() {
    final records = _ctrl.attendanceRecords;
    final byMonth = <String, Map<String, int>>{};
    for (final r in records) {
      final raw = r['date'] as String? ?? '';
      if (raw.isEmpty) continue;
      final dt = DateTime.tryParse(raw);
      if (dt == null) continue;
      final key = DateFormat('MMM yy').format(dt);
      byMonth.putIfAbsent(key, () => {'present': 0, 'total': 0});
      byMonth[key]!['total'] = byMonth[key]!['total']! + 1;
      if (r['status'] == 'present') {
        byMonth[key]!['present'] = byMonth[key]!['present']! + 1;
      }
    }
    _monthlyData = byMonth.entries.map((e) {
      final pct = e.value['total']! > 0
          ? (e.value['present']! / e.value['total']!) * 100
          : 0.0;
      return {'month': e.key, 'percentage': pct};
    }).toList();
  }

  Future<void> _exportPdf() async {
    final student = AuthController.to.currentStudent.value;
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text('SmartAttend — Attendance Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 10),
        if (student != null) ...[
          pw.Text('Student: ${student.name}'),
          pw.Text('Reg No: ${student.regNo}'),
          pw.Text('Department: ${student.department}'),
          pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}'),
          pw.SizedBox(height: 20),
        ],
        pw.Header(level: 1, text: 'Subject-wise Attendance'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Subject', 'Present', 'Total', '%'],
          data: _subjectStats.map((s) => [
            s['subject'],
            '${s['present']}',
            '${s['total']}',
            '${(s['percentage'] as double).toStringAsFixed(1)}%',
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo100),
          cellAlignment: pw.Alignment.center,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Header ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: AppTheme.textPrimary),
                      onPressed: () => Get.back(),
                    ),
                    const Text('Attendance Reports',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        )),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.primary),
                      onPressed: _loadData,
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: AppTheme.error),
                      onPressed: _subjectStats.isEmpty ? null : _exportPdf,
                      tooltip: 'Export PDF',
                    ),
                  ],
                ),
              ),

              // ─── Tabs ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicator: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: const [
                      Tab(text: 'By Subject'),
                      Tab(text: 'Monthly Trend'),
                    ],
                  ),
                ),
              ),

              // ─── Tab Content ───────────────────────────
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary))
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _SubjectTab(stats: _subjectStats),
                          _MonthlyTab(data: _monthlyData),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Subject-wise Tab ─────────────────────────────────────
class _SubjectTab extends StatelessWidget {
  final List<Map<String, dynamic>> stats;
  const _SubjectTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(
        child: Text('No attendance data found.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: stats.length,
      itemBuilder: (_, i) {
        final s = stats[i];
        final pct = (s['percentage'] as double).clamp(0.0, 100.0);
        final color = pct >= 75
            ? AppTheme.success
            : pct >= 50
                ? AppTheme.warning
                : AppTheme.error;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassmorphismCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      s['subject'] as String,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: AppTheme.bgCardLight,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${s['present']} of ${s['total']} classes attended',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Monthly Trend Tab ────────────────────────────────────
class _MonthlyTab extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _MonthlyTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('No monthly data available.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final bars = data.asMap().entries.map((e) {
      final pct = (e.value['percentage'] as double).clamp(0.0, 100.0);
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: pct,
            gradient: const LinearGradient(
              colors: [Color(0xFF7C5CFF), Color(0xFF00D4FF)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            height: 260,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassmorphismCard,
            child: BarChart(
              BarChartData(
                maxY: 100,
                barGroups: bars,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (val, _) => Text(
                        '${val.toInt()}%',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final i = val.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox();
                        return Text(
                          data[i]['month'] as String,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.bgCard,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${rod.toY.toStringAsFixed(1)}%',
                      const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Table summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassmorphismCard,
            child: Column(
              children: [
                const Row(
                  children: [
                    Expanded(
                        child: Text('Month',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12))),
                    Text('Attendance %',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),
                const Divider(height: 16, color: Color(0x22FFFFFF)),
                ...data.map((d) {
                  final pct = (d['percentage'] as double);
                  final color = pct >= 75
                      ? AppTheme.success
                      : pct >= 50
                          ? AppTheme.warning
                          : AppTheme.error;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(d['month'] as String,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 13)),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
