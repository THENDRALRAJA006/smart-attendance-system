// ============================================================
// SmartAttend — ERP Subjects Management Screen (v13 Material 3)
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/erp_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/erp_models.dart';
import '../../../widgets/glassmorphism_card.dart';

class ErpSubjectsScreen extends StatefulWidget {
  const ErpSubjectsScreen({super.key});

  @override
  State<ErpSubjectsScreen> createState() => _ErpSubjectsScreenState();
}

class _ErpSubjectsScreenState extends State<ErpSubjectsScreen> {
  final ErpController ctrl = Get.find();
  ErpDepartment? selectedDept;

  @override
  void initState() {
    super.initState();
    if (ctrl.departments.isNotEmpty) {
      selectedDept = ctrl.departments.first;
      ctrl.fetchSubjects(departmentId: selectedDept!.id);
    } else {
      ctrl.fetchDepartments().then((_) {
        if (ctrl.departments.isNotEmpty) {
          setState(() {
            selectedDept = ctrl.departments.first;
          });
          ctrl.fetchSubjects(departmentId: selectedDept!.id);
        }
      });
    }
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
        title: Text('Subjects Management', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 28),
            onPressed: selectedDept != null ? () => _showAddSubjectDialog(context) : null,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: Column(
          children: [
            // Department Filter Dropdown
            Obx(() {
              if (ctrl.departments.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppTheme.bgCard,
                child: DropdownButtonFormField<ErpDepartment>(
                  value: selectedDept,
                  items: ctrl.departments
                      .map((d) => DropdownMenuItem(value: d, child: Text('${d.shortName} — ${d.name}', overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (d) {
                    if (d != null) {
                      setState(() => selectedDept = d);
                      ctrl.fetchSubjects(departmentId: d.id);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Select Department', border: OutlineInputBorder()),
                ),
              );
            }),

            // List
            Expanded(
              child: Obx(() {
                if (ctrl.isLoading.value && ctrl.subjects.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }

                if (ctrl.subjects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.menu_book_outlined, size: 48, color: AppTheme.textHint),
                        const SizedBox(height: 12),
                        Text('No subjects created for this department', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddSubjectDialog(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Subject'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ctrl.subjects.length,
                  itemBuilder: (ctx, i) {
                    final sub = ctrl.subjects[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassmorphismCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: sub.subjectType == 'Lab' ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  sub.subjectType == 'Lab' ? Icons.science_rounded : Icons.book_rounded,
                                  color: sub.subjectType == 'Lab' ? AppTheme.accent : AppTheme.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sub.subjectName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                  Text(
                                    'Code: ${sub.subjectCode ?? "—"} · Credits: ${sub.credits ?? 3} · Year ${sub.year ?? "All"} · ${sub.subjectType}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                                  tooltip: 'Edit Subject',
                                  onPressed: () => _showEditSubjectDialog(context, sub),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                                  tooltip: 'Delete Subject',
                                  onPressed: () => _showConfirmDeleteSubject(context, sub),
                                ),
                              ],
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

  void _showAddSubjectDialog(BuildContext context) {
    final nameC = TextEditingController();
    final codeC = TextEditingController();
    int year = 1;
    int credits = 3;
    String type = 'Theory';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Subject (${selectedDept?.shortName})', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Subject Name (e.g. Deep Learning)')),
            const SizedBox(height: 10),
            TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Subject Code (e.g. CS801)')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: year,
                    items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                    onChanged: (v) => year = v ?? 1,
                    decoration: const InputDecoration(labelText: 'Year'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: type,
                    items: ['Theory', 'Lab', 'Elective', 'Tutorial'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => type = v ?? 'Theory',
                    decoration: const InputDecoration(labelText: 'Type'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.trim().isNotEmpty && selectedDept != null) {
                await ctrl.createSubject(
                  nameC.text.trim(),
                  codeC.text.trim().isEmpty ? null : codeC.text.trim().toUpperCase(),
                  selectedDept!.id,
                  year,
                  credits,
                  type,
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

  void _showEditSubjectDialog(BuildContext context, sub) {
    final nameC = TextEditingController(text: sub.subjectName);
    final codeC = TextEditingController(text: sub.subjectCode ?? '');
    int year = sub.year ?? 1;
    int credits = sub.credits ?? 3;
    String type = sub.subjectType ?? 'Theory';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Subject Name')),
            const SizedBox(height: 10),
            TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Subject Code')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: year,
                    items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                    onChanged: (v) => year = v ?? 1,
                    decoration: const InputDecoration(labelText: 'Year'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: type,
                    items: ['Theory', 'Lab', 'Elective', 'Tutorial'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => type = v ?? 'Theory',
                    decoration: const InputDecoration(labelText: 'Type'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.trim().isNotEmpty && selectedDept != null) {
                await ctrl.createSubject(
                  nameC.text.trim(),
                  codeC.text.trim().isEmpty ? null : codeC.text.trim().toUpperCase(),
                  selectedDept!.id,
                  year,
                  credits,
                  type,
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

  void _showConfirmDeleteSubject(BuildContext context, sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppTheme.error)),
        content: Text('Are you sure you want to delete "${sub.subjectName}"?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              if (selectedDept != null) {
                await ctrl.deleteSubject(sub.id, selectedDept!.id);
              }
              Get.back();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
