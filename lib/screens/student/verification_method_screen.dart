// ============================================================
// SmartAttend — Verification Method Selection Screen (v2)
// Student chooses: Face Verification OR QR Verification
// v2: Step indicator (2 of 3), alreadyMarked guard,
//     animated entry, loading state
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/attendance_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class VerificationMethodScreen extends StatelessWidget {
  const VerificationMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final attendance = Get.find<AttendanceController>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Obx(() {
            // ─── Already Marked Guard ───────────────────────
            if (attendance.alreadyMarked) {
              return _buildAlreadyMarkedState(attendance);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── App Bar ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 24, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppTheme.textPrimary, size: 20),
                        onPressed: () => Get.back(),
                      ),
                      const Text(
                        'Verify Attendance',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Step Indicator ────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: _StepIndicator(currentStep: 2, totalSteps: 3),
                ),

                const SizedBox(height: 8),

                // ─── Session Info ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Builder(builder: (_) {
                    final subject  = attendance.deepLinkSessionSubject.value;
                    final classroom = attendance.deepLinkSessionClassroom.value;
                    if (subject.isEmpty && classroom.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.book_rounded,
                                color: AppTheme.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (subject.isNotEmpty)
                                  Text(
                                    subject,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                if (classroom.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_rounded,
                                          color: AppTheme.textSecondary, size: 13),
                                      const SizedBox(width: 3),
                                      Text(
                                        classroom,
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
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppTheme.success.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: AppTheme.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 28),

                // ─── Title ────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Choose Verification\nMethod',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Select how you want to verify your attendance. Do not worry — neither option starts automatically.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ─── Method Cards ──────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // ── Face Verification ──────────────────
                        _MethodCard(
                          id: 'face_verification_card',
                          icon: Icons.face_retouching_natural_rounded,
                          title: 'Face Verification',
                          description:
                              'Use your device camera for live face recognition with ArcFace AI. Fastest and most secure method.',
                          badge: 'RECOMMENDED',
                          badgeColor: AppTheme.success,
                          iconColor: AppTheme.primary,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A1535), Color(0xFF1E1A45)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderColor: AppTheme.primary.withValues(alpha: 0.4),
                          onTap: () {
                            attendance.verificationMethod.value =
                                VerificationMethod.face;
                            Get.toNamed(AppConstants.routeAttendanceVerification);
                          },
                        ),

                        const SizedBox(height: 16),

                        // ── QR Verification ────────────────────
                        _MethodCard(
                          id: 'qr_verification_card',
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'QR Verification',
                          description:
                              'Scan the QR code displayed by your faculty using camera, or upload a QR image from gallery or files.',
                          badge: 'ALTERNATIVE',
                          badgeColor: AppTheme.accent,
                          iconColor: AppTheme.accent,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F2030), Color(0xFF0F2535)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderColor: AppTheme.accent.withValues(alpha: 0.35),
                          onTap: () {
                            attendance.verificationMethod.value =
                                VerificationMethod.qr;
                            Get.toNamed(AppConstants.routeQrVerification);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Security Footer ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_rounded,
                          color: AppTheme.textHint.withValues(alpha: 0.6),
                          size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Secured by ArcFace AI • Anti-spoofing enabled',
                        style: TextStyle(
                          color: AppTheme.textHint.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildAlreadyMarkedState(AttendanceController attendance) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 52),
            ),
            const SizedBox(height: 28),
            const Text(
              'Already Marked',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You have already marked attendance for this session.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Get.until(
                    (r) => r.settings.name == AppConstants.routeStudentDashboard),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Back to Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step Indicator ──────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final stepNum = index + 1;
        final isCompleted = stepNum < currentStep;
        final isCurrent  = stepNum == currentStep;
        return Expanded(
          child: Row(
            children: [
              _StepDot(
                number: stepNum,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                label: _stepLabel(stepNum),
              ),
              if (index < totalSteps - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: isCompleted
                          ? AppTheme.primaryGradient
                          : LinearGradient(colors: [
                              AppTheme.textHint.withValues(alpha: 0.3),
                              AppTheme.textHint.withValues(alpha: 0.3),
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

  String _stepLabel(int step) {
    switch (step) {
      case 1: return 'BLE Scan';
      case 2: return 'Choose';
      case 3: return 'Verify';
      default: return '';
    }
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final bool isCompleted;
  final bool isCurrent;
  final String label;

  const _StepDot({
    required this.number,
    required this.isCompleted,
    required this.isCurrent,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    if (isCompleted) {
      bg = AppTheme.success;
      fg = Colors.white;
    } else if (isCurrent) {
      bg = AppTheme.primary;
      fg = Colors.white;
    } else {
      bg = AppTheme.textHint.withValues(alpha: 0.2);
      fg = AppTheme.textHint;
    }

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCurrent ? AppTheme.primary : AppTheme.textHint,
            fontSize: 9,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ─── Method Option Card ──────────────────────────────────────
class _MethodCard extends StatefulWidget {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final String badge;
  final Color badgeColor;
  final Color iconColor;
  final LinearGradient gradient;
  final Color borderColor;
  final VoidCallback onTap;

  const _MethodCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
    required this.badgeColor,
    required this.iconColor,
    required this.gradient,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<_MethodCard> createState() => _MethodCardState();
}

class _MethodCardState extends State<_MethodCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key(widget.id),
      onTapDown: (_) {
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _ctrl.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pressed
                  ? widget.borderColor.withValues(alpha: 0.8)
                  : widget.borderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.iconColor.withValues(alpha: _pressed ? 0.2 : 0.1),
                blurRadius: _pressed ? 24 : 16,
                spreadRadius: _pressed ? 2 : 1,
              ),
            ],
          ),
          child: Row(
            children: [
              // ─── Icon ────────────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: widget.iconColor.withValues(alpha: 0.2)),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 30),
              ),
              const SizedBox(width: 16),
              // ─── Text ────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                    widget.badgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            widget.badge,
                            style: TextStyle(
                              color: widget.badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: widget.iconColor.withValues(alpha: 0.6), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
