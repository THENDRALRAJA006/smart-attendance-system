// ============================================================
// SmartAttend — Faculty Management Screen (v13 Material 3)
// Fields: Faculty Name, Employee ID, Department, Email, Mobile, Designation
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/erp_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glassmorphism_card.dart';

class ErpFacultyScreen extends StatefulWidget {
  const ErpFacultyScreen({super.key});

  @override
  State<ErpFacultyScreen> createState() => _ErpFacultyScreenState();
}

class _ErpFacultyScreenState extends State<ErpFacultyScreen> {
  final ErpController ctrl = Get.find();
  final TextEditingController searchCtrl = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    ctrl.fetchFaculty();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text('Faculty Management', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: AppTheme.primary, size: 26),
            onPressed: () => _showAddFacultyDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchCtrl,
                onChanged: (v) => setState(() => query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search by name, EMP ID, department...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textHint),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (ctrl.isLoading.value && ctrl.facultyList.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }

                final filtered = ctrl.facultyList.where((f) =>
                    f.name.toLowerCase().contains(query) ||
                    f.email.toLowerCase().contains(query) ||
                    (f.employeeId ?? '').toLowerCase().contains(query) ||
                    (f.department ?? '').toLowerCase().contains(query)).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No faculty found', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final f = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassmorphismCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                              child: Text(
                                f.name.isNotEmpty ? f.name[0].toUpperCase() : 'F',
                                style: GoogleFonts.poppins(color: AppTheme.secondary, fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                  Text(
                                    '${f.designation ?? "Faculty"} · ${f.department ?? "General"}',
                                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  Text(
                                    'EMP ID: ${f.employeeId ?? "—"} · ${f.email}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                              onPressed: () => ctrl.deleteFaculty(f.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFacultyDialog(BuildContext context) {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final empC = TextEditingController();
    final deptC = TextEditingController();
    final desigC = TextEditingController(text: 'Assistant Professor');
    final phoneC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Faculty', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Faculty Name *')),
              const SizedBox(height: 8),
              TextField(controller: empC, decoration: const InputDecoration(labelText: 'Employee ID (e.g. EMP1024)')),
              const SizedBox(height: 8),
              TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email *')),
              const SizedBox(height: 8),
              TextField(controller: deptC, decoration: const InputDecoration(labelText: 'Department (e.g. CSE)')),
              const SizedBox(height: 8),
              TextField(controller: desigC, decoration: const InputDecoration(labelText: 'Designation (e.g. Assistant Professor)')),
              const SizedBox(height: 8),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Mobile Number')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.trim().isNotEmpty && emailC.text.trim().isNotEmpty) {
                await ctrl.createFaculty(
                  nameC.text.trim(),
                  emailC.text.trim(),
                  empC.text.trim().isEmpty ? null : empC.text.trim(),
                  deptC.text.trim().isEmpty ? null : deptC.text.trim(),
                  desigC.text.trim().isEmpty ? null : desigC.text.trim(),
                  phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
                );
                Get.back();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
