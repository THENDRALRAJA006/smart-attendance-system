// Staff Screen — full CRUD for Faculty
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final _search = TextEditingController();
  final AdminController _ctrl = Get.find();

  @override
  void initState() { super.initState(); _ctrl.fetchFaculty(); }

  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      _header(),
      _searchBar(),
      Expanded(child: _list()),
    ]);

    if (Navigator.of(context).canPop()) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          title: const Text('Staff Management'),
          backgroundColor: AppTheme.bgPage,
          elevation: 0,
        ),
        body: body,
      );
    }
    return body;
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      Obx(() => Text('${_ctrl.facultyTotal.value} Staff',
          style: const TextStyle(color: AppTheme.textPrimary,
              fontSize: 20, fontWeight: FontWeight.w700))),
      const Spacer(),
      _btn('+ Add Staff', () => _showForm(null)),
    ]),
  );

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: TextField(
      controller: _search,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search staff...', hintStyle: const TextStyle(color: AppTheme.textSecondary),
        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
        filled: true, fillColor: AppTheme.cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.cardBorder)),
      ),
      onChanged: (v) => _ctrl.fetchFaculty(search: v),
    ),
  );

  Widget _list() => Obx(() {
    if (_ctrl.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_ctrl.faculty.isEmpty) return const Center(child: Text('No staff found', style: TextStyle(color: AppTheme.textSecondary)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: _ctrl.faculty.length,
      itemBuilder: (_, i) => _card(_ctrl.faculty[i]),
    );
  });

  Widget _card(AdminFacultyModel f) {
    final name = f.name.trim().isNotEmpty ? f.name.trim() : 'Faculty Staff';
    final initial = name[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: f.isActive ? AppTheme.cardBorder : AppTheme.error.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: f.isActive ? AppTheme.secondary.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
          child: Text(initial,
              style: TextStyle(color: f.isActive ? AppTheme.secondary : AppTheme.error, fontWeight: FontWeight.w700)),
        ),
        title: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text('${f.email} • ${f.department ?? "—"}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
          color: AppTheme.cardBg,
          onSelected: (v) => _handleAction(v, f),
          itemBuilder: (_) => [
            _item('edit',    Icons.edit_rounded,         'Edit'),
            _item('suspend', f.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                f.isActive ? 'Suspend' : 'Activate'),
            _item('reset',   Icons.lock_reset_rounded,   'Reset Password'),
            _item('delete',  Icons.delete_rounded,       'Delete'),
          ],
        ),
      ),
    );
  }

  void _handleAction(String action, AdminFacultyModel f) async {
    switch (action) {
      case 'edit':   _showForm(f); break;
      case 'suspend': await _ctrl.toggleFacultySuspend(f.id); _snack(); break;
      case 'reset':
        final pwd = await _ctrl.resetFacultyPassword(f.id);
        if (pwd != null) {
          Get.dialog(AlertDialog(
          backgroundColor: AppTheme.bgDark,
          title: const Text('Temp Password', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text(pwd, style: const TextStyle(color: AppTheme.primary, fontSize: 22, fontWeight: FontWeight.w800)),
          actions: [TextButton(onPressed: Get.back, child: const Text('Done'))],
        ));}
        break;
      case 'delete':
        Get.dialog(AlertDialog(
          backgroundColor: AppTheme.bgDark,
          title: const Text('Confirm', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text('Delete ${f.name}?', style: const TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('Cancel')),
            TextButton(onPressed: () async { Get.back(); await _ctrl.deleteFaculty(f.id); _snack(); },
                child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
          ],
        ));
        break;
    }
  }

  void _showForm(AdminFacultyModel? f) {
    final nameCtrl = TextEditingController(text: f?.name ?? '');
    final emailCtrl = TextEditingController(text: f?.email ?? '');
    final deptCtrl = TextEditingController(text: f?.department ?? '');
    final phoneCtrl = TextEditingController(text: f?.phoneNumber ?? '');
    final passCtrl = TextEditingController();
    final isEdit = f != null;

    Get.bottomSheet(Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: AppTheme.bgDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEdit ? 'Edit Staff' : 'Add Staff',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _field(nameCtrl, 'Full Name'), _field(emailCtrl, 'Email'),
          _field(deptCtrl, 'Department'), _field(phoneCtrl, 'Phone'),
          if (!isEdit) _field(passCtrl, 'Password (for staff login)', obscureText: true),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final data = {
                  'name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'department': deptCtrl.text.trim(),
                  'phone_number': phoneCtrl.text.trim(),
                  if (!isEdit && passCtrl.text.trim().isNotEmpty)
                    'password': passCtrl.text.trim(),
                };
                bool ok = isEdit ? await _ctrl.editFaculty(f.id, data)
                    : await _ctrl.createFaculty(data);
                if (ok) Get.back();
                _snack();
              },
              child: Text(isEdit ? 'Save' : 'Create', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    ), isScrollControlled: true);
  }

  Widget _field(TextEditingController c, String label, {bool obscureText = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: c, obscureText: obscureText, style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
          filled: true, fillColor: AppTheme.cardBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.cardBorder)))),
  );

  Widget _btn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
  );

  PopupMenuItem<String> _item(String v, IconData icon, String label) => PopupMenuItem(
    value: v,
    child: Row(children: [Icon(icon, size: 18, color: v == 'delete' ? AppTheme.error : AppTheme.textPrimary),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: v == 'delete' ? AppTheme.error : AppTheme.textPrimary, fontSize: 13))]),
  );

  void _snack() {
    final s = _ctrl.successMessage.value;
    final e = _ctrl.errorMessage.value;
    if (s.isNotEmpty) { Get.snackbar('Success', s, backgroundColor: Colors.green.withValues(alpha: 0.9), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12)); _ctrl.clearMessages(); }
    else if (e.isNotEmpty) { Get.snackbar('Error', e, backgroundColor: AppTheme.error.withValues(alpha: 0.9), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12)); _ctrl.clearMessages(); }
  }
}
