// Attendance Management Screen — list, filters, edit/delete, manual mark, sessions
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import 'sessions_screen.dart';

class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({super.key});
  @override State<AttendanceManagementScreen> createState() => _AMS();
}

class _AMS extends State<AttendanceManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final AdminController _ctrl = Get.find();
  String? _statusFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _ctrl.fetchAttendance();
    _ctrl.fetchSessions();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      color: AppTheme.cardBg,
      child: TabBar(
        controller: _tab,
        indicatorColor: AppTheme.primary,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        tabs: const [Tab(text: 'Records'), Tab(text: 'Sessions')],
      ),
    ),
    Expanded(child: TabBarView(controller: _tab, children: [_records(), SessionsScreen()])),
  ]);

  Widget _records() => Column(children: [
    _filterBar(),
    Expanded(child: Obx(() {
      if (_ctrl.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
      if (_ctrl.attendanceRecords.isEmpty) return const Center(child: Text('No records', style: TextStyle(color: AppTheme.textSecondary)));
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _ctrl.attendanceRecords.length,
        itemBuilder: (_, i) => _recordCard(_ctrl.attendanceRecords[i]),
      );
    })),
    _manualBtn(),
  ]);

  Widget _filterBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(children: [
      Expanded(child: _searchField()),
      const SizedBox(width: 8),
      _statusDropdown(),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () => _ctrl.fetchAttendance(status: _statusFilter),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 18),
        ),
      ),
    ]),
  );

  Widget _searchField() => SizedBox(
    height: 40,
    child: TextField(
      controller: _searchCtrl,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search student...', hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 18),
        filled: true, fillColor: AppTheme.cardBg, contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.cardBorder)),
      ),
    ),
  );

  Widget _statusDropdown() => Container(
    height: 40, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
      value: _statusFilter,
      dropdownColor: AppTheme.bgDark,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
      hint: const Text('Status', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      items: [null, 'present', 'absent', 'manual_review'].map((v) => DropdownMenuItem(
        value: v, child: Text(v ?? 'All', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
      )).toList(),
      onChanged: (v) => setState(() => _statusFilter = v),
    )),
  );

  Widget _recordCard(AdminAttendanceRecord r) {
    final color = r.status == 'present' ? Colors.green
        : r.status == 'absent' ? AppTheme.error : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(r.status == 'present' ? Icons.check_rounded : Icons.close_rounded, color: color, size: 18)),
        title: Text(r.studentName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text('${r.regNo} • ${r.date} ${r.time}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(r.status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 18),
            color: AppTheme.cardBg,
            onSelected: (v) => _handleRecord(v, r),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'present', child: Text('Mark Present', style: TextStyle(color: Colors.green))),
              const PopupMenuItem(value: 'absent', child: Text('Mark Absent', style: TextStyle(color: AppTheme.error))),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.error))),
            ],
          ),
        ]),
      ),
    );
  }

  void _handleRecord(String action, AdminAttendanceRecord r) {
    if (action == 'delete') {
      Get.dialog(AlertDialog(
        backgroundColor: AppTheme.bgDark,
        title: const Text('Confirm', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Delete this record?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(onPressed: () async { Get.back(); await _ctrl.deleteAttendance(r.id); }, child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
        ],
      ));
    } else {
      _ctrl.editAttendanceStatus(r.id, action);
    }
  }

  Widget _manualBtn() => Container(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
        label: const Text('Mark Manual Attendance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showManualDialog,
      ),
    ),
  );

  void _showManualDialog() {
    final studentIdCtrl = TextEditingController();
    final sessionIdCtrl = TextEditingController();
    String selectedStatus = 'present';
    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.bgDark,
      title: const Text('Manual Attendance', style: TextStyle(color: AppTheme.textPrimary)),
      content: StatefulBuilder(builder: (ctx, ss) => Column(mainAxisSize: MainAxisSize.min, children: [
        _field(studentIdCtrl, 'Student ID', keyboard: TextInputType.number),
        const SizedBox(height: 8),
        _field(sessionIdCtrl, 'Session ID', keyboard: TextInputType.number),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selectedStatus,
          dropdownColor: AppTheme.bgDark,
          decoration: InputDecoration(labelText: 'Status', filled: true, fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.cardBorder))),
          items: ['present', 'absent', 'manual_review'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(color: AppTheme.textPrimary)))).toList(),
          onChanged: (v) => ss(() => selectedStatus = v!),
        ),
      ])),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          onPressed: () async {
            final sid = int.tryParse(studentIdCtrl.text);
            final sesId = int.tryParse(sessionIdCtrl.text);
            if (sid != null && sesId != null) {
              await _ctrl.markManualAttendance(sid, sesId, selectedStatus);
              Get.back();
              Get.snackbar('Success', 'Attendance marked', backgroundColor: Colors.green.withValues(alpha: 0.9), colorText: Colors.white);
            }
          },
          child: const Text('Mark', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard}) => TextField(
    controller: c, keyboardType: keyboard,
    style: const TextStyle(color: AppTheme.textPrimary),
    decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true, fillColor: AppTheme.cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.cardBorder))),
  );
}
