// ============================================================
// SmartAttend — ERP Classrooms Screen (v13 Material 3)
// Room examples: A101, A102, Lab 1, Lab 2, Seminar Hall, Auditorium
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/erp_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glassmorphism_card.dart';

class ErpClassroomsScreen extends StatefulWidget {
  const ErpClassroomsScreen({super.key});

  @override
  State<ErpClassroomsScreen> createState() => _ErpClassroomsScreenState();
}

class _ErpClassroomsScreenState extends State<ErpClassroomsScreen> {
  final ErpController ctrl = Get.find();

  @override
  void initState() {
    super.initState();
    ctrl.fetchClassrooms();
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
        title: Text('Classrooms Management', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 28),
            onPressed: () => _showAddRoomDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: Obx(() {
          if (ctrl.classrooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.meeting_room_outlined, size: 48, color: AppTheme.textHint),
                  const SizedBox(height: 12),
                  Text('No classrooms created yet', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => ctrl.seedClassrooms(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Seed Default Rooms (A101-A203, Lab 1-3, Seminar Hall)'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: ctrl.classrooms.length,
            itemBuilder: (ctx, i) {
              final rm = ctrl.classrooms[i];
              return GlassmorphismCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.meeting_room_rounded, color: AppTheme.primary, size: 20),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 18),
                          onPressed: () => ctrl.deleteClassroom(rm.id),
                        ),
                      ],
                    ),
                    Text(
                      rm.roomName,
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    Text(
                      rm.bleUuid != null ? 'Beacon: Active' : 'No BLE beacon',
                      style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }

  void _showAddRoomDialog(BuildContext context) {
    final roomC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Classroom', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: roomC,
          decoration: const InputDecoration(labelText: 'Room Name (e.g. A101, Lab 1, Seminar Hall)'),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (roomC.text.trim().isNotEmpty) {
                await ctrl.createClassroom(roomC.text.trim(), null);
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
