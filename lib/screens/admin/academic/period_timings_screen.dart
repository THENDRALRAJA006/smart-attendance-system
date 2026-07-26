// ============================================================
// SmartAttend — Period Timings Screen (v13 Material 3)
// Configures Period 1-7, Break, Lunch & Custom Teacher Timings.
// Includes Edit All and Custom Option for Teachers.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/erp_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glassmorphism_card.dart';

class PeriodTimingsScreen extends StatefulWidget {
  const PeriodTimingsScreen({super.key});

  @override
  State<PeriodTimingsScreen> createState() => _PeriodTimingsScreenState();
}

class _PeriodTimingsScreenState extends State<PeriodTimingsScreen> {
  final ErpController ctrl = Get.find();

  @override
  void initState() {
    super.initState();
    ctrl.fetchPeriodTimings();
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
        title: Text('Period Timings Configuration', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar_rounded, color: AppTheme.primary),
            tooltip: 'Edit All Timings',
            onPressed: () => _showBulkEditDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.alarm_add_rounded, color: AppTheme.primary, size: 26),
            tooltip: 'Add Custom Timing',
            onPressed: () => _showAddPeriodDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: Column(
          children: [
            // Banner for Teacher Custom Timings
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Admins & Teachers can modify default timings, edit all periods at once, or add custom extra-class timing slots.',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Obx(() {
                if (ctrl.periodTimings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule_outlined, size: 48, color: AppTheme.textHint),
                        const SizedBox(height: 12),
                        Text('No period timings configured', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ctrl.seedPeriodTimings(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Seed Default Periods (Period 1-7, Break, Lunch)'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ctrl.periodTimings.length,
                  itemBuilder: (ctx, i) {
                    final p = ctrl.periodTimings[i];
                    final isBreak = p.periodType == 'Break' || p.periodType == 'Lunch';
                    final color = p.periodType == 'Lunch' ? const Color(0xFFEF4444) : isBreak ? const Color(0xFFF59E0B) : AppTheme.primary;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassmorphismCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  isBreak ? Icons.free_breakfast_rounded : Icons.access_time_filled_rounded,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                  Text(
                                    '${p.startTime} — ${p.endTime}',
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                p.periodType,
                                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
                              onPressed: () => _showEditSinglePeriodDialog(context, p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                              onPressed: () => ctrl.deletePeriodTiming(p.id),
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

  void _showAddPeriodDialog(BuildContext context) {
    final labelC = TextEditingController();
    final startC = TextEditingController(text: '15:30');
    final endC = TextEditingController(text: '16:20');
    String type = 'Theory';
    int order = ctrl.periodTimings.length + 1;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Custom Period / Extra Timing', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelC,
              decoration: const InputDecoration(labelText: 'Label (e.g. Extra Class, Zero Period, Period 8)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: startC, decoration: const InputDecoration(labelText: 'Start Time (HH:MM)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: endC, decoration: const InputDecoration(labelText: 'End Time (HH:MM)'))),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: type,
              items: ['Theory', 'Lab', 'Break', 'Lunch', 'Tutorial', 'Elective'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => type = v ?? 'Theory',
              decoration: const InputDecoration(labelText: 'Type'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (labelC.text.trim().isNotEmpty) {
                await ctrl.createPeriodTiming(labelC.text.trim(), startC.text.trim(), endC.text.trim(), type, order);
                Get.back();
              }
            },
            child: const Text('Save Custom Timing'),
          ),
        ],
      ),
    );
  }

  void _showEditSinglePeriodDialog(BuildContext context, dynamic p) {
    final labelC = TextEditingController(text: p.label);
    final startC = TextEditingController(text: p.startTime);
    final endC = TextEditingController(text: p.endTime);
    String type = p.periodType;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Timing: ${p.label}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelC, decoration: const InputDecoration(labelText: 'Period Label')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: startC, decoration: const InputDecoration(labelText: 'Start Time'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: endC, decoration: const InputDecoration(labelText: 'End Time'))),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: type,
              items: ['Theory', 'Lab', 'Break', 'Lunch', 'Tutorial', 'Elective'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => type = v ?? 'Theory',
              decoration: const InputDecoration(labelText: 'Type'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ctrl.createPeriodTiming(labelC.text.trim(), startC.text.trim(), endC.text.trim(), type, p.orderIndex);
              Get.back();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showBulkEditDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit All Default Period Timings', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Text('Adjust timing boundaries globally across all class periods.', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ctrl.periodTimings.length,
                  itemBuilder: (c, idx) {
                    final pt = ctrl.periodTimings[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(width: 80, child: Text(pt.label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(
                            child: TextFormField(
                              initialValue: pt.startTime,
                              decoration: const InputDecoration(isDense: true, labelText: 'Start'),
                              onChanged: (v) => pt.startTime,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: pt.endTime,
                              decoration: const InputDecoration(isDense: true, labelText: 'End'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      ctrl.fetchPeriodTimings();
                    },
                    child: const Text('Save All Changes'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
