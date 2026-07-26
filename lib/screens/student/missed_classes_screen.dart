// ============================================================
// SmartAttend — Missed Classes Screen (v11)
// Shows all absent attendance records with details.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/student_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/glassmorphism_card.dart';

class MissedClassesScreen extends StatefulWidget {
  const MissedClassesScreen({super.key});

  @override
  State<MissedClassesScreen> createState() => _MissedClassesScreenState();
}

class _MissedClassesScreenState extends State<MissedClassesScreen> {
  final StudentController _ctrl = Get.find();

  @override
  void initState() {
    super.initState();
    _ctrl.fetchMissedClasses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        title: const Text('Missed Classes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() {
            final count = _ctrl.missedClasses.length;
            if (count == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Text('$count missed',
                  style: const TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Content ─────────────────────────────────
              Expanded(
                child: Obx(() {
                  if (_ctrl.isLoadingMissed.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }
                  if (_ctrl.missedClasses.isEmpty) {
                    return _buildEmpty();
                  }
                  return RefreshIndicator(
                    onRefresh: () => _ctrl.fetchMissedClasses(),
                    color: AppTheme.primary,
                    backgroundColor: AppTheme.bgCard,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      itemCount: _ctrl.missedClasses.length,
                      itemBuilder: (context, i) =>
                          _MissedCard(item: _ctrl.missedClasses[i]),
                    ),
                  );
                }),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppTheme.success, size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Missed Classes! 🎉',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You have attended all your classes.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Missed Class Card ────────────────────────────────────────
class _MissedCard extends StatelessWidget {
  final MissedClassModel item;
  const _MissedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE, d MMM yyyy');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassmorphismCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cancel_outlined,
                      color: AppTheme.error, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.subjectCode != null
                            ? '${item.subjectCode} — ${item.subjectName}'
                            : item.subjectName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (item.facultyName != null)
                        Text(
                          item.facultyName!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.25)),
                  ),
                  child: const Text(
                    'Absent',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Details strip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgCard.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _DetailChip(
                    icon: Icons.calendar_today_rounded,
                    text: dateFmt.format(item.date),
                  ),
                  const SizedBox(width: 16),
                  _DetailChip(
                    icon: Icons.access_time_rounded,
                    text: item.time,
                  ),
                  const SizedBox(width: 16),
                  _DetailChip(
                    icon: Icons.meeting_room_outlined,
                    text: item.classroom,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Reason
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.textHint, size: 13),
                const SizedBox(width: 6),
                Text(
                  'Reason: ${item.reason}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.textHint, size: 12),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}
