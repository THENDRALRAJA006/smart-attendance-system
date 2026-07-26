// ============================================================
// SmartAttend — Weekly Timetable Spreadsheet Editor (v13 Material 3)
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/erp_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/erp_models.dart';
import '../../../widgets/glassmorphism_card.dart';

class TimetableEditorScreen extends StatefulWidget {
  const TimetableEditorScreen({super.key});

  @override
  State<TimetableEditorScreen> createState() => _TimetableEditorScreenState();
}

class _TimetableEditorScreenState extends State<TimetableEditorScreen> {
  final ErpController ctrl = Get.find();
  final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (ctrl.departments.isEmpty) await ctrl.fetchDepartments();
    if (ctrl.periodTimings.isEmpty) await ctrl.fetchPeriodTimings();
    if (ctrl.classrooms.isEmpty) await ctrl.fetchClassrooms();
    if (ctrl.facultyList.isEmpty) await ctrl.fetchFaculty();
    if (ctrl.selectedDept.value != null) {
      await ctrl.fetchSubjects(departmentId: ctrl.selectedDept.value!.id);
      await ctrl.fetchTimetableGrid();
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
        title: Text('Weekly Timetable Editor', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded, color: AppTheme.primary),
            tooltip: 'Duplicate Timetable',
            onPressed: () => _showDuplicateDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: () => ctrl.fetchTimetableGrid(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: Column(
          children: [
            // Filter Bar: Department | Year | Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.bgCard,
              child: Obx(() {
                if (ctrl.departments.isEmpty) {
                  return const Text('Loading departments...');
                }
                return Row(
                  children: [
                    // Dept
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<ErpDepartment>(
                        value: ctrl.selectedDept.value,
                        isExpanded: true,
                        items: ctrl.departments
                            .map((d) => DropdownMenuItem(value: d, child: Text(d.shortName, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (d) {
                          if (d != null) {
                            ctrl.selectedDept.value = d;
                            ctrl.fetchSubjects(departmentId: d.id);
                            ctrl.fetchTimetableGrid();
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Dept', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Year
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<int>(
                        value: ctrl.selectedYear.value,
                        items: [1, 2, 3, 4]
                            .map((y) => DropdownMenuItem(value: y, child: Text('Y$y')))
                            .toList(),
                        onChanged: (y) {
                          if (y != null) {
                            ctrl.selectedYear.value = y;
                            ctrl.fetchTimetableGrid();
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Year', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Section
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: ctrl.selectedSection.value,
                        items: ['A', 'B', 'C', 'D', 'E', 'F', 'G']
                            .map((s) => DropdownMenuItem(value: s, child: Text('Sec $s')))
                            .toList(),
                        onChanged: (s) {
                          if (s != null) {
                            ctrl.selectedSection.value = s;
                            ctrl.fetchTimetableGrid();
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Sec', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      ),
                    ),
                  ],
                );
              }),
            ),

            // Timetable Spreadsheet Grid
            Expanded(
              child: Obx(() {
                if (ctrl.isLoading.value && ctrl.timetableGrid.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }

                if (ctrl.periodTimings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule_rounded, size: 48, color: AppTheme.textHint),
                        const SizedBox(height: 12),
                        Text('Period timings not configured', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ctrl.seedPeriodTimings(),
                          child: const Text('Seed Default Periods'),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Table(
                      defaultColumnWidth: const FixedColumnWidth(130),
                      border: TableBorder.all(
                        color: AppTheme.border.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      children: [
                        // Header Row (Periods)
                        TableRow(
                          decoration: const BoxDecoration(color: AppTheme.bgCard),
                          children: [
                            TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                alignment: Alignment.center,
                                child: Text('Day \\ Period', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              ),
                            ),
                            ...ctrl.periodTimings.map((p) => TableCell(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Text(p.label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                                    Text('${p.startTime}-${p.endTime}', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textHint)),
                                  ],
                                ),
                              ),
                            )),
                          ],
                        ),

                        // Day Rows (Monday .. Saturday)
                        ...days.map((day) {
                          final daySlots = ctrl.timetableGrid[day] ?? [];

                          return TableRow(
                            children: [
                              // Day Name Column
                              TableCell(
                                child: Container(
                                  height: 90,
                                  color: AppTheme.bgCard,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    day.substring(0, 3).toUpperCase(),
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                  ),
                                ),
                              ),

                              // Cell per Period Timing
                              ...ctrl.periodTimings.map((pt) {
                                final isBreak = pt.periodType == 'Break' || pt.periodType == 'Lunch';
                                if (isBreak) {
                                  return TableCell(
                                    child: Container(
                                      height: 90,
                                      color: pt.periodType == 'Lunch' ? Colors.red.withValues(alpha: 0.05) : Colors.amber.withValues(alpha: 0.05),
                                      alignment: Alignment.center,
                                      child: Text(
                                        pt.label,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: pt.periodType == 'Lunch' ? Colors.red : Colors.amber.shade800,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final slot = daySlots.firstWhereOrNull((s) => s.periodTimingId == pt.id);

                                return TableCell(
                                  child: InkWell(
                                    onTap: () => _showCellEditorDialog(context, day, pt, slot),
                                    child: Container(
                                      height: 90,
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: slot != null ? _getClassTypeColor(slot.classType).withValues(alpha: 0.1) : Colors.transparent,
                                      ),
                                      child: slot != null && slot.subjectName != null
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  slot.subjectName!,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  slot.facultyName ?? '—',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      slot.roomName ?? '—',
                                                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: _getClassTypeColor(slot.classType).withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        slot.classType,
                                                        style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: _getClassTypeColor(slot.classType)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : Center(
                                              child: Text('+ Assign', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
                                            ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Color _getClassTypeColor(String type) {
    switch (type) {
      case 'Lab': return AppTheme.accent;
      case 'Elective': return const Color(0xFF8B5CF6);
      case 'Tutorial': return const Color(0xFF10B981);
      default: return AppTheme.primary;
    }
  }

  void _showCellEditorDialog(BuildContext context, String day, PeriodTiming pt, WeeklyTimetableSlotModel? existing) {
    ErpSubject? selectedSub = ctrl.subjects.firstWhereOrNull((s) => s.id == existing?.erpSubjectId);
    ErpFacultyModel? selectedFac = ctrl.facultyList.firstWhereOrNull((f) => f.id == existing?.facultyId);
    ErpClassroomModel? selectedRm = ctrl.classrooms.firstWhereOrNull((r) => r.id == existing?.classroomId);
    String classType = existing?.classType ?? 'Theory';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('$day · ${pt.label} (${pt.startTime}-${pt.endTime})', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Subject Dropdown
                DropdownButtonFormField<ErpSubject>(
                  value: selectedSub,
                  isExpanded: true,
                  items: ctrl.subjects
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.subjectName, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (s) => setDState(() => selectedSub = s),
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 10),

                // Faculty Dropdown
                DropdownButtonFormField<ErpFacultyModel>(
                  value: selectedFac,
                  isExpanded: true,
                  items: ctrl.facultyList
                      .map((f) => DropdownMenuItem(value: f, child: Text(f.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (f) => setDState(() => selectedFac = f),
                  decoration: const InputDecoration(labelText: 'Faculty'),
                ),
                const SizedBox(height: 10),

                // Classroom Dropdown
                DropdownButtonFormField<ErpClassroomModel>(
                  value: selectedRm,
                  isExpanded: true,
                  items: ctrl.classrooms
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.roomName)))
                      .toList(),
                  onChanged: (r) => setDState(() => selectedRm = r),
                  decoration: const InputDecoration(labelText: 'Classroom / Room'),
                ),
                const SizedBox(height: 10),

                // Class Type
                DropdownButtonFormField<String>(
                  value: classType,
                  items: ['Theory', 'Lab', 'Elective', 'Tutorial']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (t) => setDState(() => classType = t ?? 'Theory'),
                  decoration: const InputDecoration(labelText: 'Class Type'),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await ctrl.deleteSlot(existing.id);
                  Get.back();
                },
                child: const Text('Clear Slot', style: TextStyle(color: AppTheme.error)),
              ),
            TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (ctrl.selectedDept.value != null) {
                  await ctrl.saveSlot(
                    deptId: ctrl.selectedDept.value!.id,
                    year: ctrl.selectedYear.value,
                    section: ctrl.selectedSection.value,
                    dayOfWeek: day,
                    periodTimingId: pt.id,
                    subjectId: selectedSub?.id,
                    facultyId: selectedFac?.id,
                    classroomId: selectedRm?.id,
                    classType: classType,
                  );
                  Get.back();
                }
              },
              child: const Text('Save Slot'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDuplicateDialog(BuildContext context) {
    ErpDepartment? targetDept = ctrl.selectedDept.value;
    int targetYear = ctrl.selectedYear.value;
    String targetSec = 'B';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Duplicate Timetable', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Copy ${ctrl.selectedDept.value?.shortName} Y${ctrl.selectedYear.value} Sec ${ctrl.selectedSection.value} → Target Section:',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ErpDepartment>(
                value: targetDept,
                items: ctrl.departments
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.shortName)))
                    .toList(),
                onChanged: (d) => setDState(() => targetDept = d),
                decoration: const InputDecoration(labelText: 'Target Department'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: targetYear,
                      items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                      onChanged: (y) => setDState(() => targetYear = y ?? 1),
                      decoration: const InputDecoration(labelText: 'Year'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: targetSec,
                      items: ['A', 'B', 'C', 'D', 'E', 'F'].map((s) => DropdownMenuItem(value: s, child: Text('Sec $s'))).toList(),
                      onChanged: (s) => setDState(() => targetSec = s ?? 'B'),
                      decoration: const InputDecoration(labelText: 'Section'),
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
                if (ctrl.selectedDept.value != null && targetDept != null) {
                  final ok = await ctrl.duplicateTimetable(
                    sourceDeptId: ctrl.selectedDept.value!.id,
                    sourceYear: ctrl.selectedYear.value,
                    sourceSection: ctrl.selectedSection.value,
                    targetDeptId: targetDept!.id,
                    targetYear: targetYear,
                    targetSection: targetSec,
                  );
                  if (ok) {
                    Get.back();
                    Get.snackbar(
                      'Duplicated!',
                      'Timetable copied successfully. Switch filters to edit target section.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.success,
                      colorText: Colors.white,
                    );
                  }
                }
              },
              child: const Text('Copy Timetable'),
            ),
          ],
        ),
      ),
    );
  }
}
