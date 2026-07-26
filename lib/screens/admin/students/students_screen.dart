import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _search = TextEditingController();
  final AdminController _ctrl = Get.find();
  String? _dept;
  bool? _activeFilter;

  @override
  void initState() {
    super.initState();
    _ctrl.fetchStudents();
  }

  void _applyFilters() =>
      _ctrl.fetchStudents(search: _search.text, department: _dept, isActive: _activeFilter);

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        _buildFilterChips(),
        Expanded(child: _buildList()),
      ],
    );

    if (Navigator.of(context).canPop()) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          title: const Text('Students Directory'),
          backgroundColor: AppTheme.bgPage,
          elevation: 0,
        ),
        body: body,
      );
    }
    return body;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Obx(() => Text('${_ctrl.studentsTotal.value} Students',
              style: const TextStyle(color: AppTheme.textPrimary,
                  fontSize: 20, fontWeight: FontWeight.w700))),
          const Spacer(),
          _iconBtn(Icons.refresh_rounded, () => _applyFilters()),
          const SizedBox(width: 8),
          _primaryBtn('+ Add', () => _showStudentForm(null)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        controller: _search,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search name, reg no, email...',
          hintStyle: const TextStyle(color: AppTheme.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
          suffixIcon: _search.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                  onPressed: () { _search.clear(); _applyFilters(); })
              : null,
          filled: true,
          fillColor: AppTheme.cardBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.cardBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.cardBorder)),
        ),
        onChanged: (_) => _applyFilters(),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          _filterChip('All', _activeFilter == null,
              () => setState(() { _activeFilter = null; _applyFilters(); })),
          const SizedBox(width: 8),
          _filterChip('Active', _activeFilter == true,
              () => setState(() { _activeFilter = true; _applyFilters(); })),
          const SizedBox(width: 8),
          _filterChip('Suspended', _activeFilter == false,
              () => setState(() { _activeFilter = false; _applyFilters(); })),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Obx(() {
      if (_ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
      }
      if (_ctrl.students.isEmpty) {
        return const Center(
          child: Text('No students found',
              style: TextStyle(color: AppTheme.textSecondary)));
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        itemCount: _ctrl.students.length,
        itemBuilder: (_, i) => _studentCard(_ctrl.students[i]),
      );
    });
  }

  Widget _studentCard(AdminStudentModel s) {
    final name = s.name.trim().isNotEmpty ? s.name.trim() : 'Student';
    final initial = name[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.isActive ? AppTheme.cardBorder : AppTheme.error.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: s.isActive
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.error.withValues(alpha: 0.15),
          child: Text(initial,
              style: TextStyle(
                  color: s.isActive ? AppTheme.primary : AppTheme.error,
                  fontWeight: FontWeight.w700)),
        ),
        title: Row(
          children: [
            Expanded(child: Text(name,
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontSize: 14, fontWeight: FontWeight.w600))),
            if (!s.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('SUSPENDED',
                    style: TextStyle(color: AppTheme.error, fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('${s.regNo} • ${s.department} • Year ${s.year}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Row(
              children: [
                _badge(s.faceRegistered ? '✓ Face' : '✗ Face',
                    s.faceRegistered ? Colors.green : Colors.grey),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
          color: AppTheme.cardBg,
          onSelected: (v) => _handleStudentAction(v, s),
          itemBuilder: (_) => [
            _menuItem('edit',          Icons.edit_rounded,        'Edit'),
            _menuItem('suspend',       s.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                s.isActive ? 'Suspend' : 'Activate'),
            _menuItem('reset',         Icons.lock_reset_rounded,  'Reset Password'),
            _menuItem('face',          Icons.face_rounded,        'Delete Face'),
            _menuItem('device',        Icons.phone_android_rounded,'Remove Device'),
            _menuItem('delete',        Icons.delete_rounded,      'Delete Student'),
          ],
        ),
        onTap: () => _showStudentDetail(s),
      ),
    );
  }

  void _handleStudentAction(String action, AdminStudentModel s) async {
    switch (action) {
      case 'edit':
        _showStudentForm(s);
        break;
      case 'suspend':
        await _ctrl.toggleStudentSuspend(s.id);
        _showSnack();
        break;
      case 'reset':
        final pwd = await _ctrl.resetStudentPassword(s.id);
        if (pwd != null) _showTempPassword(pwd);
        break;
      case 'face':
        _confirmAction('Delete face data for ${s.name}?',
            () => _ctrl.deleteStudentFace(s.id));
        break;
      case 'device':
        _confirmAction('Remove device binding for ${s.name}?',
            () => _ctrl.removeStudentDeviceBinding(s.id));
        break;
      case 'delete':
        _confirmAction('Delete ${s.name} permanently?',
            () => _ctrl.deleteStudent(s.id));
        break;
    }
  }

  void _showStudentForm(AdminStudentModel? student) {
    final nameCtrl  = TextEditingController(text: student?.name ?? '');
    final regCtrl   = TextEditingController(text: student?.regNo ?? '');
    final emailCtrl = TextEditingController(text: student?.email ?? '');
    final deptCtrl  = TextEditingController(text: student?.department ?? '');
    final secCtrl   = TextEditingController(text: student?.section ?? '');
    final yearCtrl  = TextEditingController(text: student?.year.toString() ?? '1');
    final pwdCtrl   = TextEditingController();
    final isEdit = student != null;
    final editId = student?.id;  // non-null when isEdit is true

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.bgDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit Student' : 'Create Student',
                  style: const TextStyle(color: AppTheme.textPrimary,
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _field(nameCtrl,  'Full Name'),
              _field(regCtrl,   'Register No', enabled: !isEdit),
              _field(emailCtrl, 'Email'),
              _field(deptCtrl,  'Department'),
              Row(children: [
                Expanded(child: _field(secCtrl, 'Section')),
                const SizedBox(width: 12),
                Expanded(child: _field(yearCtrl, 'Year', keyboard: TextInputType.number)),
              ]),
              if (!isEdit) _field(pwdCtrl, 'Password (leave blank to auto-gen)'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final data = {
                      'name': nameCtrl.text, 'reg_no': regCtrl.text,
                      'email': emailCtrl.text, 'department': deptCtrl.text,
                      'section': secCtrl.text, 'year': int.tryParse(yearCtrl.text) ?? 1,
                      if (!isEdit && pwdCtrl.text.isNotEmpty) 'password': pwdCtrl.text,
                    };
                    bool ok;
                    if (isEdit) {
                      ok = await _ctrl.editStudent(editId!, data);
                    } else {
                      ok = await _ctrl.createStudent(data);
                    }
                    if (ok) {
                      Get.back();
                      _ctrl.fetchStudents();
                    }
                    _showSnack();
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Create Student',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showStudentDetail(AdminStudentModel s) {
    Get.dialog(Dialog(
      backgroundColor: AppTheme.bgDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name, style: const TextStyle(color: AppTheme.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w700)),
            const Divider(color: AppTheme.cardBorder, height: 20),
            _detailRow('Reg No', s.regNo),
            _detailRow('Department', s.department),
            _detailRow('Year / Section', 'Year ${s.year} / ${s.section}'),
            _detailRow('Email', s.email),
            _detailRow('Phone', s.phoneNumber ?? '—'),
            _detailRow('Status', s.statusLabel),
            _detailRow('Face Data', s.faceRegistered ? '${s.faceCount} embeddings' : 'Not registered'),
            const SizedBox(height: 16),
            TextButton(onPressed: Get.back, child: const Text('Close')),
          ],
        ),
      ),
    ));
  }

  void _confirmAction(String message, Future<dynamic> Function() action) {
    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.bgDark,
      title: const Text('Confirm', style: TextStyle(color: AppTheme.textPrimary)),
      content: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        TextButton(
          onPressed: () async { Get.back(); await action(); _showSnack(); },
          child: const Text('Confirm', style: TextStyle(color: AppTheme.error)),
        ),
      ],
    ));
  }

  void _showTempPassword(String pwd) {
    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.bgDark,
      title: const Text('Temp Password', style: TextStyle(color: AppTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Share this with the student:',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Text(pwd, style: const TextStyle(color: AppTheme.primary,
                fontSize: 22, fontWeight: FontWeight.w800,
                letterSpacing: 3)),
          ),
        ],
      ),
      actions: [TextButton(onPressed: Get.back, child: const Text('Done'))],
    ));
  }

  void _showSnack() {
    Obx(() {
      if (_ctrl.successMessage.value.isNotEmpty) {
        Get.snackbar('Success', _ctrl.successMessage.value,
            backgroundColor: Colors.green.withValues(alpha: 0.8),
            colorText: Colors.white);
        _ctrl.clearMessages();
      }
      if (_ctrl.errorMessage.value.isNotEmpty) {
        Get.snackbar('Error', _ctrl.errorMessage.value,
            backgroundColor: AppTheme.error.withValues(alpha: 0.8),
            colorText: Colors.white);
        _ctrl.clearMessages();
      }
      return const SizedBox();
    });
    final s = _ctrl.successMessage.value;
    final e = _ctrl.errorMessage.value;
    if (s.isNotEmpty) {
      Get.snackbar('Success', s,
          backgroundColor: Colors.green.withValues(alpha: 0.9), colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      _ctrl.clearMessages();
    } else if (e.isNotEmpty) {
      Get.snackbar('Error', e,
          backgroundColor: AppTheme.error.withValues(alpha: 0.9), colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      _ctrl.clearMessages();
    }
  }

  // ─── Helpers ───────────────────────────────────────────────
  Widget _field(TextEditingController c, String label,
      {bool enabled = true, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        enabled: enabled,
        keyboardType: keyboard,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
          filled: true,
          fillColor: AppTheme.cardBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.cardBorder)),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.cardBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
    );
  }

  Widget _primaryBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110,
              child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(child: Text(value,
              style: const TextStyle(color: AppTheme.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: value == 'delete' ? AppTheme.error : AppTheme.textPrimary),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: value == 'delete' ? AppTheme.error : AppTheme.textPrimary,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
