// ============================================================
// SmartAttend — Department Management Screen (v13 Material 3)
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/erp_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/erp_models.dart';
import '../../../widgets/glassmorphism_card.dart';

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  final ErpController ctrl = Get.find();
  final TextEditingController searchCtrl = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    ctrl.fetchDepartments();
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
        title: Text(
          'Departments Management',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 28),
            onPressed: () => _showAddDeptDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchCtrl,
                onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search department (e.g. CSE, AIML)...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textHint),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            // List
            Expanded(
              child: Obx(() {
                if (ctrl.isLoading.value && ctrl.departments.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }

                final filtered = ctrl.departments.where((d) =>
                    d.name.toLowerCase().contains(searchQuery) ||
                    d.shortName.toLowerCase().contains(searchQuery)).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.business_outlined, size: 48, color: AppTheme.textHint),
                        const SizedBox(height: 12),
                        Text('No departments found', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ctrl.seedDepartments(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Seed Default Departments'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final dept = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassmorphismCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    dept.shortName,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    dept.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
                                  onPressed: () => _showEditDeptDialog(context, dept),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                                  onPressed: () => _confirmDelete(context, dept),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Years & Section Config
                            Text(
                              'Years: 1, 2, 3, 4 | Sections configuration:',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            _SectionConfigRow(dept: dept, ctrl: ctrl),
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

  void _showAddDeptDialog(BuildContext context) {
    final nameC = TextEditingController();
    final shortC = TextEditingController();
    String degree = 'B.E.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Department', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Full Name (e.g. Computer Science Engineering)')),
            const SizedBox(height: 10),
            TextField(controller: shortC, decoration: const InputDecoration(labelText: 'Short Name (e.g. CSE)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: degree,
              items: ['B.E.', 'B.Tech.', 'M.E.', 'M.Tech.', 'MBA', 'MCA']
                  .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => degree = v ?? 'B.E.',
              decoration: const InputDecoration(labelText: 'Degree Type'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.trim().isNotEmpty && shortC.text.trim().isNotEmpty) {
                await ctrl.createDepartment(nameC.text.trim(), shortC.text.trim().toUpperCase(), degree);
                Get.back();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDeptDialog(BuildContext context, ErpDepartment dept) {
    final nameC = TextEditingController(text: dept.name);
    final shortC = TextEditingController(text: dept.shortName);
    String degree = dept.degreeType;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Department', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 10),
            TextField(controller: shortC, decoration: const InputDecoration(labelText: 'Short Name')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: degree,
              items: ['B.E.', 'B.Tech.', 'M.E.', 'M.Tech.', 'MBA', 'MCA']
                  .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => degree = v ?? 'B.E.',
              decoration: const InputDecoration(labelText: 'Degree Type'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ctrl.updateDepartment(dept.id, nameC.text.trim(), shortC.text.trim().toUpperCase(), degree);
              Get.back();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ErpDepartment dept) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text('Are you sure you want to delete ${dept.name}?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ctrl.deleteDepartment(dept.id);
              Get.back();
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _SectionConfigRow extends StatefulWidget {
  final ErpDepartment dept;
  final ErpController ctrl;
  const _SectionConfigRow({required this.dept, required this.ctrl});

  @override
  State<_SectionConfigRow> createState() => _SectionConfigRowState();
}

class _SectionConfigRowState extends State<_SectionConfigRow> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.fetchSections(widget.dept.id);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final secs = widget.ctrl.departmentSections[widget.dept.id.toString()] ?? [];
      return Column(
        children: List.generate(4, (yrIdx) {
          final year = yrIdx + 1;
          final yearSecs = secs.where((s) => s.year == year).toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 55,
                  child: Text(
                    'Year $year:',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...yearSecs.map((s) => Chip(
                        label: Text('Sec ${s.section}', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
                        padding: EdgeInsets.zero,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        deleteIcon: const Icon(Icons.close, size: 12, color: AppTheme.error),
                        onDeleted: () => widget.ctrl.deleteSection(widget.dept.id, s.id),
                      )),
                      InkWell(
                        onTap: () => _addSectionDialog(context, year),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.primary),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('+ Add Sec', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      );
    });
  }

  void _addSectionDialog(BuildContext context, int year) {
    final secCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Section (Year $year)', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: secCtrl,
          decoration: const InputDecoration(labelText: 'Section Name (e.g. A, B, C, D, Unlimited)'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (secCtrl.text.trim().isNotEmpty) {
                await widget.ctrl.addSection(widget.dept.id, year, secCtrl.text.trim().toUpperCase());
                Get.back();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
