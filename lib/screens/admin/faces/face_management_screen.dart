// Face Management Screen
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';

class FaceManagementScreen extends StatefulWidget {
  const FaceManagementScreen({super.key});
  @override State<FaceManagementScreen> createState() => _FMS();
}

class _FMS extends State<FaceManagementScreen> {
  final AdminController _ctrl = Get.find();
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _ctrl.fetchFaceList(); }

  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
        Obx(() => Text('${_ctrl.faceTotal.value} Students', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700))),
        const Spacer(),
        IconButton(icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary), onPressed: () => _ctrl.fetchFaceList()),
      ]),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: TextField(
        controller: _search,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search student...', hintStyle: const TextStyle(color: AppTheme.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
          filled: true, fillColor: AppTheme.cardBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.cardBorder)),
        ),
        onChanged: (v) => _ctrl.fetchFaceList(search: v),
      ),
    ),
    Expanded(child: Obx(() {
      if (_ctrl.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _ctrl.faceList.length,
        itemBuilder: (_, i) {
          final item = _ctrl.faceList[i];
          final isReg = (item['is_registered'] as bool?) ?? false;
          final count = (item['face_count'] as num?)?.toInt() ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isReg ? const Color(0xFF48CAE4).withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
                child: Icon(Icons.face_rounded, color: isReg ? const Color(0xFF48CAE4) : AppTheme.error, size: 22),
              ),
              title: Text(item['name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('${item['reg_no'] ?? ""} • ${item['department'] ?? ""}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              trailing: isReg
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text('$count embeddings', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: AppTheme.error, size: 20),
                      onPressed: () => _confirmDelete(item['student_id'] as int, item['name'] as String),
                    ),
                  ])
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Not Registered', style: TextStyle(color: AppTheme.error, fontSize: 11)),
                  ),
            ),
          );
        },
      );
    })),
    ]);

    if (Navigator.of(context).canPop()) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          title: const Text('Face Recognition'),
          backgroundColor: AppTheme.bgPage,
          elevation: 0,
        ),
        body: body,
      );
    }
    return body;
  }

  void _confirmDelete(int studentId, String name) {
    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.bgDark,
      title: const Text('Delete Face Data?', style: TextStyle(color: AppTheme.textPrimary)),
      content: Text('Remove all face embeddings for $name?', style: const TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: () async { Get.back(); await _ctrl.deleteStudentFace(studentId); _ctrl.fetchFaceList(); },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }
}
