// Reports Screen — export PDF/CSV/Excel
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final AdminController _ctrl = Get.find();
  String _period = 'monthly';
  String? _dept;
  bool _exporting = false;

  final _periods = ['daily', 'weekly', 'monthly'];

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: const Row(children: [
            Icon(Icons.bar_chart_rounded, color: Colors.white, size: 32),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Export Reports', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Generate PDF, CSV, or Excel reports', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),

        // Period selector
        const Text('Report Period', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: _periods.map((p) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _period = p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: _period == p ? AppTheme.primaryGradient : null,
                color: _period == p ? null : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _period == p ? AppTheme.primary : AppTheme.cardBorder),
              ),
              child: Text(p.capitalize!,
                  style: TextStyle(
                      color: _period == p ? Colors.white : AppTheme.textSecondary,
                      fontSize: 13, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ),
          ),
        )).toList()),
        const SizedBox(height: 20),

        // Department filter
        const Text('Department (optional)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Obx(() {
            final depts = _ctrl.students.map((s) => s.department).toSet().toList();
            return DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _dept,
                dropdownColor: AppTheme.bgDark,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                hint: const Text('All Departments', style: TextStyle(color: AppTheme.textSecondary)),
                items: [null, ...depts].map((d) => DropdownMenuItem(
                  value: d, child: Text(d ?? 'All Departments',
                      style: const TextStyle(color: AppTheme.textPrimary)),
                )).toList(),
                onChanged: (v) => setState(() => _dept = v),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // Export buttons
        const Text('Export Format', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...[
          _ExportOption(fmt: 'csv',  icon: Icons.table_chart_rounded, label: 'CSV Spreadsheet', color: const Color(0xFF06D6A0), sub: 'Comma-separated, opens in Excel/Sheets'),
          _ExportOption(fmt: 'xlsx', icon: Icons.grid_on_rounded,     label: 'Excel Workbook',  color: const Color(0xFF00B4D8), sub: 'Formatted .xlsx with charts'),
          _ExportOption(fmt: 'pdf',  icon: Icons.picture_as_pdf_rounded, label: 'PDF Report',  color: const Color(0xFFFF6B6B), sub: 'Printable PDF with letterhead'),
        ].map((opt) => _exportCard(opt)),
      ],
    );

    if (Navigator.of(context).canPop()) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          title: const Text('Reports & Exports'),
          backgroundColor: AppTheme.bgPage,
          elevation: 0,
        ),
        body: body,
      );
    }
    return body;
  }

  Widget _exportCard(_ExportOption opt) {
    return GestureDetector(
      onTap: _exporting ? null : () => _export(opt.fmt),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: opt.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: opt.color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: opt.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(opt.icon, color: opt.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(opt.label, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(opt.sub,   style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ])),
          if (_exporting)
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: opt.color, strokeWidth: 2))
          else
            Icon(Icons.download_rounded, color: opt.color, size: 22),
        ]),
      ),
    );
  }

  Future<void> _export(String fmt) async {
    setState(() => _exporting = true);
    await _ctrl.exportReport(fmt, period: _period, department: _dept);
    setState(() => _exporting = false);
    final msg = _ctrl.successMessage.value.isNotEmpty
        ? _ctrl.successMessage.value
        : _ctrl.errorMessage.value;
    if (msg.isNotEmpty) {
      Get.snackbar('Export', msg,
          backgroundColor: _ctrl.errorMessage.value.isNotEmpty
              ? AppTheme.error.withValues(alpha: 0.9)
              : Colors.green.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12));
      _ctrl.clearMessages();
    }
  }
}

class _ExportOption {
  final String fmt, label, sub;
  final IconData icon;
  final Color color;
  const _ExportOption({required this.fmt, required this.icon, required this.label, required this.color, required this.sub});
}
