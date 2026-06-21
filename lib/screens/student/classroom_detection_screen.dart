// ============================================================
// SmartAttend — Classroom Detection Screen (BLE Scanner)
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/attendance_controller.dart';
import '../../core/services/ble_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glassmorphism_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/signal_strength_widget.dart';

class ClassroomDetectionScreen extends StatefulWidget {
  const ClassroomDetectionScreen({super.key});

  @override
  State<ClassroomDetectionScreen> createState() =>
      _ClassroomDetectionScreenState();
}

class _ClassroomDetectionScreenState extends State<ClassroomDetectionScreen>
    with SingleTickerProviderStateMixin {
  final BleService _ble = Get.find();
  final AttendanceController _attendance = Get.find();
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startScan();
  }

  void _startScan() {
    _attendance.startBLEScan();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _ble.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ─── App Bar ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: AppTheme.textPrimary, size: 20),
                      onPressed: () => Get.back(),
                    ),
                    const Text(
                      'Classroom Detection',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Scanning for nearby classrooms via Bluetooth',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // ─── Radar Animation ──────────────────────────────
              Obx(() => SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Radar rings
                        ...[0.4, 0.6, 0.8, 1.0].map((scale) => AnimatedBuilder(
                              animation: _radarController,
                              builder: (context, child) {
                                final opacity = (1.0 -
                                        (((_radarController.value + scale - 0.4) %
                                            1.0))) *
                                    0.3;
                                return Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: (_ble.isScanning.value
                                                ? AppTheme.primary
                                                : AppTheme.textHint)
                                            .withValues(alpha: opacity),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )),

                        // Center icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: _ble.isScanning.value
                                ? AppTheme.primaryGradient
                                : LinearGradient(colors: [
                                    AppTheme.bgCardLight,
                                    AppTheme.bgCard
                                  ]),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.bluetooth_searching,
                            color: _ble.isScanning.value
                                ? Colors.white
                                : AppTheme.textHint,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  )),

              // ─── Scan Status ──────────────────────────────────
              Obx(() => Text(
                    _ble.isScanning.value
                        ? 'Scanning...'
                        : _ble.detectedClassrooms.isEmpty
                            ? 'No classrooms found'
                            : '${_ble.detectedClassrooms.length} classroom(s) found',
                    style: TextStyle(
                      color: _ble.isScanning.value
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  )),

              const SizedBox(height: 24),

              // ─── Classroom List ───────────────────────────────
              Expanded(
                child: Obx(() {
                  if (_ble.detectedClassrooms.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GlassmorphismCard(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bluetooth_disabled,
                              color: AppTheme.textHint,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No SmartAttend beacons detected',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Make sure you are inside the classroom\nand Bluetooth is enabled',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _ble.detectedClassrooms.length,
                    itemBuilder: (context, index) {
                      final classroom = _ble.detectedClassrooms[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassmorphismCard(
                          borderColor: classroom.isInRange
                              ? AppTheme.success.withValues(alpha: 0.3)
                              : AppTheme.error.withValues(alpha: 0.3),
                          onTap: () =>
                              _attendance.selectClassroom(classroom),
                          child: Row(
                            children: [
                              // ─── Room icon ─────────────────────
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: classroom.isInRange
                                      ? AppTheme.success.withValues(alpha: 0.1)
                                      : AppTheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.meeting_room_rounded,
                                  color: classroom.isInRange
                                      ? AppTheme.success
                                      : AppTheme.error,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // ─── Room details ──────────────────
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      classroom.name
                                          .replaceAll('_', ' '),
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        SignalIcon(rssi: classroom.rssi),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${classroom.rssi} dBm • ${classroom.signalLabel}',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // ─── Status badge ──────────────────
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: classroom.isInRange
                                          ? AppTheme.success.withValues(alpha: 0.1)
                                          : AppTheme.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      classroom.isInRange
                                          ? 'In Range'
                                          : 'Out of Range',
                                      style: TextStyle(
                                        color: classroom.isInRange
                                            ? AppTheme.success
                                            : AppTheme.error,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  if (classroom.isInRange) ...[
                                    const SizedBox(height: 8),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: AppTheme.primary,
                                      size: 14,
                                    ),
                                  ],
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

              // ─── Rescan Button ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Obx(() => GradientButton(
                      text: _ble.isScanning.value
                          ? 'Scanning...'
                          : 'Rescan',
                      icon: _ble.isScanning.value
                          ? null
                          : Icons.refresh_rounded,
                      isLoading: _ble.isScanning.value,
                      onPressed: _ble.isScanning.value ? null : _startScan,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
