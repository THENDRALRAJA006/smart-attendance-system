// ============================================================
// SmartAttend — Attendance Result Screen
// Displays success, failure, or out-of-range status.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/attendance_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glassmorphism_card.dart';

class AttendanceResultScreen extends StatefulWidget {
  const AttendanceResultScreen({super.key});

  @override
  State<AttendanceResultScreen> createState() =>
      _AttendanceResultScreenState();
}

class _AttendanceResultScreenState extends State<AttendanceResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rippleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AttendanceController>();
    final result = ctrl.result.value;
    final isSuccess = result == AttendanceResult.success;
    final isOutOfRange = result == AttendanceResult.outOfRange;

    final Color mainColor = isSuccess
        ? AppTheme.success
        : isOutOfRange
            ? AppTheme.warning
            : AppTheme.error;

    final IconData mainIcon = isSuccess
        ? Icons.check_circle_rounded
        : isOutOfRange
            ? Icons.signal_wifi_off_rounded
            : Icons.cancel_rounded;

    final String title = isSuccess
        ? 'Attendance Marked!'
        : isOutOfRange
            ? 'Out of Range'
            : 'Verification Failed';

    final String subtitle = isSuccess
        ? 'Your attendance has been recorded successfully'
        : isOutOfRange
            ? 'You are not within classroom BLE range.\nMove closer to the ESP32 beacon and try again.'
            : 'Face verification did not match.\nPlease try again or contact faculty.';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                // ─── Main Result Icon ─────────────────────────
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple rings
                        if (isSuccess)
                          ...List.generate(3, (i) {
                            final delay = i * 0.3;
                            final progress =
                                (_rippleController.value + delay) % 1.0;
                            return Transform.scale(
                              scale: 1.0 + progress * 0.8,
                              child: Opacity(
                                opacity: (1.0 - progress) * 0.15,
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: mainColor,
                                  ),
                                ),
                              ),
                            );
                          }),
                        child!,
                      ],
                    );
                  },
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: mainColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: mainColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(mainIcon, color: mainColor, size: 60),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ─── Title ────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: mainColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ─── Details Card ─────────────────────────────
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: GlassmorphismCard(
                    borderColor: mainColor.withValues(alpha: 0.2),
                    child: Column(
                      children: [
                        if (isSuccess) ...[
                          Obx(() => _DetailRow(
                                icon: Icons.meeting_room_rounded,
                                label: 'Classroom',
                                value: ctrl.selectedClassroom.value?.name
                                        .replaceAll('_', ' ') ??
                                    'Unknown',
                                color: AppTheme.primary,
                              )),
                          const SizedBox(height: 12),
                          Obx(() => _DetailRow(
                                icon: Icons.signal_wifi_4_bar,
                                label: 'Signal Strength',
                                value: '${ctrl.capturedRssi.value} dBm',
                                color: AppTheme.accent,
                              )),
                          const SizedBox(height: 12),
                          Obx(() => _DetailRow(
                                icon: Icons.face_retouching_natural,
                                label: 'Confidence',
                                value:
                                    '${ctrl.confidenceScore.value.toStringAsFixed(1)}%',
                                color: AppTheme.success,
                              )),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Time',
                            value: _formatTime(),
                            color: AppTheme.textSecondary,
                          ),
                        ] else if (isOutOfRange) ...[
                          _DetailRow(
                            icon: Icons.bluetooth_disabled,
                            label: 'Issue',
                            value: 'RSSI below -70 dBm threshold',
                            color: AppTheme.warning,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.tips_and_updates_outlined,
                            label: 'Solution',
                            value: 'Move within 10m of the beacon',
                            color: AppTheme.primary,
                          ),
                        ] else ...[
                          _DetailRow(
                            icon: Icons.info_outline,
                            label: 'Reason',
                            value: ctrl.errorMessage.value.isNotEmpty
                                  ? ctrl.errorMessage.value
                                  : 'Face match below 90% threshold',
                            color: AppTheme.error,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.tips_and_updates_outlined,
                            label: 'Tip',
                            value: 'Ensure good lighting & face is clear',
                            color: AppTheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ─── Actions ──────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      if (!isSuccess) ...[
                        GradientButton(
                          text: 'Try Again',
                          icon: Icons.refresh_rounded,
                          onPressed: () {
                            ctrl.reset();
                            Get.offAllNamed(AppConstants.routeClassroomDetection);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            ctrl.reset();
                            Get.offAllNamed(AppConstants.routeStudentDashboard);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          child: const Text(
                            'Back to Dashboard',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
