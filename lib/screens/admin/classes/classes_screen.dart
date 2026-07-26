import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});
  @override State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final AdminController _ctrl = Get.find();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _ctrl.fetchClassrooms();
    _ctrl.fetchSubjects();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      Container(
        color: AppTheme.cardBg,
        child: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [Tab(text: 'Classrooms'), Tab(text: 'Subjects')],
        ),
      ),
      Expanded(child: TabBarView(controller: _tab, children: [_classrooms(), _subjects()])),
    ]);

    if (Navigator.of(context).canPop()) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          title: const Text('Classes & Subjects'),
          backgroundColor: AppTheme.bgCard,
          elevation: 0,
        ),
        body: body,
      );
    }
    return body;
  }

  // ─── Classrooms ─────────────────────────────────────────────
  Widget _classrooms() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          const Text('Classrooms', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          _addBtn(() => _addClassroomDialog()),
        ]),
      ),
      Expanded(child: Obx(() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _ctrl.classrooms.length,
        itemBuilder: (_, i) {
          final c = _ctrl.classrooms[i];
          return _tile(
            leading: const Icon(Icons.class_rounded, color: AppTheme.primary),
            title: c.roomName,
            subtitle: 'BLE: ${c.bleUuid.length > 20 ? "${c.bleUuid.substring(0,20)}..." : c.bleUuid}',
            trailing: IconButton(
              icon: const Icon(Icons.delete_rounded, color: AppTheme.error, size: 20),
              onPressed: () => _ctrl.deleteClassroom(c.id),
            ),
          );
        },
      ))),
    ]);
  }

  // ─── Subjects ───────────────────────────────────────────────
  Widget _subjects() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          const Text('Subjects', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          _addBtn(() => _addSubjectDialog()),
        ]),
      ),
      Expanded(child: Obx(() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _ctrl.subjects.length,
        itemBuilder: (_, i) {
          final s = _ctrl.subjects[i];
          return _tile(
            leading: const Icon(Icons.book_rounded, color: AppTheme.secondary),
            title: s.subjectName,
            subtitle: '${s.subjectCode ?? "—"} • Faculty: ${s.facultyName ?? "—"}',
          );
        },
      ))),
    ]);
  }

  Widget _tile({required Widget leading, required String title, required String subtitle, Widget? trailing}) {
    String displayTitle = title;
    if (displayTitle.startsWith('CLASSROOM_')) {
      displayTitle = 'Room ${displayTitle.replaceFirst('CLASSROOM_', '')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder)),
      child: Row(children: [
        leading, const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(displayTitle,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (trailing != null) trailing,
      ]),
    );
  }

  void _addClassroomDialog() {
    final nameCtrl = TextEditingController();
    final uuidCtrl = TextEditingController();
    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.bgDark,
      title: const Text('Add Classroom', style: TextStyle(color: AppTheme.textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(nameCtrl, 'Room Name (e.g. A101)'),
        const SizedBox(height: 10),
        _field(uuidCtrl, 'BLE UUID'),
      ]),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          onPressed: () async {
            if (nameCtrl.text.isNotEmpty && uuidCtrl.text.isNotEmpty) {
              await _ctrl.addClassroom(nameCtrl.text, uuidCtrl.text);
              Get.back();
            }
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _addSubjectDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final facIdCtrl = TextEditingController();
    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.bgDark,
      title: const Text('Add Subject', style: TextStyle(color: AppTheme.textPrimary)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(nameCtrl, 'Subject Name'), _field(codeCtrl, 'Subject Code'),
        _field(deptCtrl, 'Department'), _field(facIdCtrl, 'Faculty ID', keyboard: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          onPressed: () async {
            await _ctrl.addSubject({'subject_name': nameCtrl.text,
              'subject_code': codeCtrl.text, 'department': deptCtrl.text,
              'faculty_id': int.tryParse(facIdCtrl.text) ?? 0});
            Get.back();
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard}) => TextField(
    controller: c, keyboardType: keyboard,
    style: const TextStyle(color: AppTheme.textPrimary),
    decoration: InputDecoration(labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true, fillColor: AppTheme.cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.cardBorder))),
  );

  Widget _addBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
      child: const Text('+ Add', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    ),
  );
}
