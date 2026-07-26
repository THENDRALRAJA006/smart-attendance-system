// ============================================================
// SmartAttend — Biometric Progress Bar Widget (Enterprise v3)
// Flow-aware: Face flow → BLE · Liveness · Face Match · Done
//             QR   flow → BLE · QR Scan · Done
// ============================================================

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

// ─── Flow mode ────────────────────────────────────────────────
enum AttendanceFlowMode { face, qr }

enum BiometricStep { ble, qr, liveness, face, done }

class BiometricProgressBar extends StatelessWidget {
  final BiometricStep currentStep;
  final bool bleVerified;
  final bool qrVerified;
  final bool livenessVerified;
  final bool faceVerified;

  /// Controls which set of steps is rendered.
  /// face → BLE ✓ · Liveness · Face Match · Done
  /// qr   → BLE ✓ · QR Scan · Done
  final AttendanceFlowMode flowMode;

  const BiometricProgressBar({
    super.key,
    required this.currentStep,
    this.bleVerified = false,
    this.qrVerified = false,
    this.livenessVerified = false,
    this.faceVerified = false,
    this.flowMode = AttendanceFlowMode.face,
  });

  @override
  Widget build(BuildContext context) {
    final steps = flowMode == AttendanceFlowMode.qr
        ? _buildQrSteps()
        : _buildFaceSteps();

    return Row(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: step.isCompleted
                            ? AppTheme.success
                            : step.isCurrent
                                ? AppTheme.primary
                                : AppTheme.bgCardLight,
                        border: Border.all(
                          color: step.isCompleted
                              ? AppTheme.success
                              : step.isCurrent
                                  ? AppTheme.primary
                                  : AppTheme.textHint.withValues(alpha: 0.3),
                          width: step.isCurrent ? 2 : 1.5,
                        ),
                        boxShadow: step.isCurrent || step.isCompleted
                            ? AppTheme.subtleGlow(step.isCompleted
                                ? AppTheme.success
                                : AppTheme.primary)
                            : null,
                      ),
                      child: Center(
                        child: step.isCompleted
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 16)
                            : Icon(step.icon,
                                color: step.isCurrent
                                    ? Colors.white
                                    : AppTheme.textHint,
                                size: 14),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.label,
                      style: TextStyle(
                        color: step.isCompleted
                            ? AppTheme.success
                            : step.isCurrent
                                ? AppTheme.textPrimary
                                : AppTheme.textHint,
                        fontSize: 9,
                        fontWeight: step.isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: step.isCompleted
                          ? const LinearGradient(
                              colors: [AppTheme.success, AppTheme.success])
                          : LinearGradient(colors: [
                              AppTheme.textHint.withValues(alpha: 0.2),
                              AppTheme.textHint.withValues(alpha: 0.1),
                            ]),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ─── Face flow: BLE → Liveness → Face Match → Done ─────────
  List<_StepData> _buildFaceSteps() => [
        _StepData(
          label: 'BLE',
          icon: Icons.bluetooth,
          isCompleted: bleVerified,
          isCurrent: currentStep == BiometricStep.ble,
        ),
        _StepData(
          label: 'Liveness',
          icon: Icons.face_retouching_natural,
          isCompleted: livenessVerified,
          isCurrent: currentStep == BiometricStep.liveness,
        ),
        _StepData(
          label: 'Face Match',
          icon: Icons.fingerprint,
          isCompleted: faceVerified,
          isCurrent: currentStep == BiometricStep.face,
        ),
        _StepData(
          label: 'Done',
          icon: Icons.check_circle_outline_rounded,
          isCompleted: faceVerified,
          isCurrent: currentStep == BiometricStep.done,
        ),
      ];

  // ─── QR flow: BLE → QR Scan → Done ─────────────────────────
  List<_StepData> _buildQrSteps() => [
        _StepData(
          label: 'BLE',
          icon: Icons.bluetooth,
          isCompleted: bleVerified,
          isCurrent: currentStep == BiometricStep.ble,
        ),
        _StepData(
          label: 'QR Scan',
          icon: Icons.qr_code_scanner,
          isCompleted: qrVerified,
          isCurrent: currentStep == BiometricStep.qr,
        ),
        _StepData(
          label: 'Done',
          icon: Icons.check_circle_outline_rounded,
          isCompleted: qrVerified,
          isCurrent: currentStep == BiometricStep.done,
        ),
      ];
}

class _StepData {
  final String label;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;

  const _StepData({
    required this.label,
    required this.icon,
    required this.isCompleted,
    required this.isCurrent,
  });
}

