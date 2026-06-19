// ============================================================
// SmartAttend — Attendance Verification Screen (Face Verify)
// ============================================================

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/attendance_controller.dart';
import '../../core/services/camera_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glassmorphism_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/signal_strength_widget.dart';

class AttendanceVerificationScreen extends StatefulWidget {
  const AttendanceVerificationScreen({super.key});

  @override
  State<AttendanceVerificationScreen> createState() =>
      _AttendanceVerificationScreenState();
}

class _AttendanceVerificationScreenState
    extends State<AttendanceVerificationScreen> {
  final CameraService _camera = Get.find();
  final AttendanceController _attendance = Get.find();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _camera.initialize();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final classroom = _attendance.selectedClassroom.value;

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
                    const Expanded(
                      child: Text(
                        'Face Verification',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // ─── Classroom Info Strip ─────────────────────────
              if (classroom != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlassmorphismCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.meeting_room_rounded,
                            color: AppTheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                classroom.name.replaceAll('_', ' '),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  SignalIcon(rssi: classroom.rssi),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${classroom.rssi} dBm',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '✓ In Range',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ─── Camera Preview ───────────────────────────────
              Expanded(
                child: Obx(() {
                  if (!_camera.isInitialized.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  if (_attendance.isLoading.value) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.face,
                                color: Colors.white, size: 40),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Verifying with AWS Rekognition...',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This may take a few seconds',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                              strokeWidth: 3,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CameraPreview(_camera.controller!),
                            ),
                            // ─── Face frame overlay ───────────────
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _FaceOvalPainter(),
                              ),
                            ),
                            // ─── AWS badge ────────────────────────
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.cloud_outlined,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 5),
                                    Text(
                                      'AWS Rekognition',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // ─── Steps Guide ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Step(
                        icon: Icons.bluetooth,
                        label: 'BLE',
                        isDone: true),
                    _StepConnector(isDone: true),
                    _Step(
                        icon: Icons.face,
                        label: 'Face',
                        isActive: true),
                    _StepConnector(isDone: false),
                    _Step(
                        icon: Icons.check_circle_outline,
                        label: 'Done',
                        isDone: false),
                  ],
                ),
              ),

              // ─── Capture Button ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Obx(() => GradientButton(
                      text: 'Capture & Verify',
                      icon: Icons.face_retouching_natural_rounded,
                      isLoading: _attendance.isLoading.value,
                      onPressed: _attendance.isLoading.value
                          ? null
                          : _attendance.captureAndVerify,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Oval Face Frame Painter ─────────────────────────────────
class _FaceOvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.6,
      height: size.height * 0.7,
    );
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Step Indicators ─────────────────────────────────────────
class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDone;
  final bool isActive;

  const _Step({
    required this.icon,
    required this.label,
    this.isDone = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color = isDone
        ? AppTheme.success
        : isActive
            ? AppTheme.primary
            : AppTheme.textHint;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(
            isDone ? Icons.check : icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool isDone;
  const _StepConnector({required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.only(bottom: 20),
        color: isDone
            ? AppTheme.success.withValues(alpha: 0.5)
            : AppTheme.textHint.withValues(alpha: 0.2),
      ),
    );
  }
}
