// ============================================================
// SmartAttend — Attendance Verification Screen (v4)
// BLE → Liveness Challenge → Face Verification
//
// v4 Flow:
//   1. Confirm BLE classroom info (already verified by BLE service)
//   2. Fetch random liveness challenge (BLINK/SMILE/TURN_LEFT/TURN_RIGHT)
//   3. Student performs challenge while 3 frames auto-captured
//   4. Backend verifies frames → anti-spoofing passed
//   5. Final face selfie captured + sent to Rekognition
//   6. Confidence tier returned (present / manual_review / rejected)
//   7. Success or retry screen
// ============================================================

import 'dart:async';
import 'dart:developer' as dev;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/services/camera_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glassmorphism_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/signal_strength_widget.dart';

// ─── Liveness Step Enum ──────────────────────────────────────
enum _LivenessStep {
  idle,          // Waiting to start
  fetching,      // Fetching challenge from server
  challenged,    // Challenge issued, waiting for student to perform it
  capturing,     // Auto-capturing 3 frames
  verifying,     // Sending frames to backend
  passed,        // Liveness verified
  failed,        // Liveness failed
}

// ─── Screen ───────────────────────────────────────────────────
class AttendanceVerificationScreen extends StatefulWidget {
  const AttendanceVerificationScreen({super.key});

  @override
  State<AttendanceVerificationScreen> createState() =>
      _AttendanceVerificationScreenState();
}

class _AttendanceVerificationScreenState
    extends State<AttendanceVerificationScreen>
    with TickerProviderStateMixin {
  final CameraService _camera = Get.find();
  final AttendanceController _attendance = Get.find();
  final AuthController _auth = Get.find();

  _LivenessStep _livenessStep = _LivenessStep.idle;
  int _captureCountdown = 3;
  Timer? _captureTimer;
  List<String> _capturedFramePaths = [];
  String? _livenessError;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initAnimations();
  }

  Future<void> _initCamera() async {
    await _camera.initialize();
    if (mounted) setState(() {});
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── Challenge Icon Mapping ───────────────────────────────
  IconData _challengeIcon(String challenge) {
    switch (challenge.toUpperCase()) {
      case 'BLINK':
        return Icons.remove_red_eye_outlined;
      case 'SMILE':
        return Icons.sentiment_very_satisfied_outlined;
      case 'TURN_LEFT':
        return Icons.arrow_back_rounded;
      case 'TURN_RIGHT':
        return Icons.arrow_forward_rounded;
      default:
        return Icons.face_outlined;
    }
  }

  // ─── Step 1: Fetch Liveness Challenge ────────────────────
  Future<void> _startLivenessChallenge() async {
    if (!mounted) return;
    setState(() {
      _livenessStep = _LivenessStep.fetching;
      _livenessError = null;
      _capturedFramePaths = [];
    });

    final ok = await _auth.fetchLivenessChallenge();
    if (!mounted) return;

    if (ok) {
      setState(() => _livenessStep = _LivenessStep.challenged);
    } else {
      setState(() {
        _livenessStep = _LivenessStep.failed;
        _livenessError = _auth.errorMessage.value.isNotEmpty
            ? _auth.errorMessage.value
            : 'Failed to fetch challenge. Please try again.';
      });
    }
  }

  // ─── Step 2: Auto-capture 3 frames ───────────────────────
  Future<void> _startFrameCapture() async {
    if (_livenessStep != _LivenessStep.challenged) return;
    if (!_camera.isInitialized.value) return;

    setState(() {
      _livenessStep = _LivenessStep.capturing;
      _captureCountdown = 3;
      _capturedFramePaths = [];
    });

    // Capture a frame every 800ms for 2.4s total
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      setState(() => _captureCountdown = 3 - i);
      await Future.delayed(const Duration(milliseconds: 800));

      try {
        final file = await _camera.captureImage();
        _capturedFramePaths.add(file.path);
      } catch (_) {
        // Continue even if one frame fails
      }
    }

    if (!mounted) return;
    await _verifyLiveness();
  }

  // ─── Step 3: Verify frames with backend ──────────────────
  Future<void> _verifyLiveness() async {
    setState(() => _livenessStep = _LivenessStep.verifying);

    if (_capturedFramePaths.isEmpty) {
      setState(() {
        _livenessStep = _LivenessStep.failed;
        _livenessError = 'No frames captured. Please try again.';
      });
      return;
    }

    final result = await _auth.verifyLiveness(_capturedFramePaths);
    if (!mounted) return;

    dev.log(
      '[LIVENESS_RESULT] Liveness verification response received: passed=${result?['passed']}, '
      'challengeToken=${_auth.liveChallengeToken.value.isNotEmpty ? "JWT_present" : "absent"}',
      name: 'AttendanceVerificationScreen',
    );

    if (result != null && result['passed'] == true) {
      setState(() => _livenessStep = _LivenessStep.passed);
    } else {
      setState(() {
        _livenessStep = _LivenessStep.failed;
        _livenessError = (result?['message'] as String?) ??
            (_auth.errorMessage.value.isNotEmpty
                ? _auth.errorMessage.value
                : 'Liveness check failed. Please try again.');
      });
    }
  }

  // ─── Step 4: Capture face + mark attendance ───────────────
  Future<void> _captureAndVerifyFace() async {
    // Pass liveness token along with face capture
    await _attendance.captureAndVerify(
      livenessToken: _auth.liveChallengeToken.value,
    );
  }

  // ─── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final classroom = _attendance.selectedClassroom.value;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              _buildAppBar(),

              // Classroom strip
              if (classroom != null) _buildClassroomStrip(classroom),

              // Camera preview
              Expanded(child: _buildCameraSection()),

              // Step indicator
              _buildStepIndicator(),

              // Action area
              _buildActionArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: AppTheme.textPrimary, size: 20),
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Text(
              _livenessStep == _LivenessStep.passed
                  ? 'Face Verification'
                  : 'Liveness Check',
              style: const TextStyle(
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
    );
  }

  Widget _buildClassroomStrip(dynamic classroom) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassmorphismCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    classroom.name.toString().replaceAll('_', ' '),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Row(
                    children: [
                      SignalIcon(rssi: classroom.rssi as int),
                      const SizedBox(width: 5),
                      Text(
                        '${classroom.rssi} dBm',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }

  Widget _buildCameraSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Obx(() {
        if (!_camera.isInitialized.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        // Show challenge overlay or camera
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _livenessStep == _LivenessStep.passed
                  ? AppTheme.success
                  : _livenessStep == _LivenessStep.failed
                      ? AppTheme.error
                      : AppTheme.primary.withValues(alpha: 0.5),
              width: 2.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Camera preview
                Positioned.fill(child: CameraPreview(_camera.controller!)),

                // Oval frame
                Positioned.fill(
                  child: CustomPaint(
                    painter: _OvalPainter(
                      color: _livenessStep == _LivenessStep.passed
                          ? AppTheme.success
                          : AppTheme.primary,
                    ),
                  ),
                ),

                // Challenge overlay (shown during challenged/capturing)
                if (_livenessStep == _LivenessStep.challenged ||
                    _livenessStep == _LivenessStep.capturing)
                  _buildChallengeOverlay(),

                // Verifying overlay
                if (_livenessStep == _LivenessStep.verifying)
                  _buildVerifyingOverlay(),

                // Success badge
                if (_livenessStep == _LivenessStep.passed)
                  _buildLivenessPassedBadge(),

                // AWS badge
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_outlined,
                            color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'AWS Rekognition',
                          style: TextStyle(
                            color: Colors.white, fontSize: 10,
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
        );
      }),
    );
  }

  Widget _buildChallengeOverlay() {
    final challenge = _auth.livenessChallenge.value;
    final instruction = _auth.livenessInstruction.value;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.75),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (ctx, _) => Transform.scale(
                scale: _pulseAnim.value,
                child: Icon(
                  _challengeIcon(challenge),
                  color: AppTheme.primary,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (_livenessStep == _LivenessStep.capturing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Capturing frame $_captureCountdown/3...',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text(
              'Verifying liveness...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivenessPassedBadge() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.white, size: 14),
            SizedBox(width: 5),
            Text(
              'Liveness OK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step Indicator ───────────────────────────────────────
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StepDot(
            icon: Icons.bluetooth,
            label: 'BLE',
            isDone: true,
          ),
          _StepConnector(isDone: true),
          _StepDot(
            icon: Icons.security_rounded,
            label: 'Liveness',
            isDone: _livenessStep == _LivenessStep.passed,
            isActive: _livenessStep != _LivenessStep.passed &&
                _livenessStep != _LivenessStep.idle,
          ),
          _StepConnector(isDone: _livenessStep == _LivenessStep.passed),
          _StepDot(
            icon: Icons.face_retouching_natural_rounded,
            label: 'Face',
            isActive: _livenessStep == _LivenessStep.passed,
          ),
          _StepConnector(isDone: false),
          _StepDot(
            icon: Icons.check_circle_outline,
            label: 'Done',
            isDone: false,
          ),
        ],
      ),
    );
  }

  // ─── Action Area ──────────────────────────────────────────
  Widget _buildActionArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          // Error message
          if (_livenessError != null && _livenessStep == _LivenessStep.failed)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _livenessError!,
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Action buttons
          if (_livenessStep == _LivenessStep.idle)
            GradientButton(
              text: 'Start Liveness Check',
              icon: Icons.security_rounded,
              onPressed: _startLivenessChallenge,
            )
          else if (_livenessStep == _LivenessStep.fetching)
            const GradientButton(
              text: 'Fetching challenge...',
              isLoading: true,
            )
          else if (_livenessStep == _LivenessStep.challenged)
            GradientButton(
              text: 'I\'m Ready — Start Capture',
              icon: Icons.camera_alt_rounded,
              onPressed: _startFrameCapture,
            )
          else if (_livenessStep == _LivenessStep.capturing)
            const GradientButton(
              text: 'Capturing frames...',
              isLoading: true,
            )
          else if (_livenessStep == _LivenessStep.verifying)
            const GradientButton(
              text: 'Verifying liveness...',
              isLoading: true,
            )
          else if (_livenessStep == _LivenessStep.failed)
            GradientButton(
              text: 'Try Again',
              icon: Icons.refresh_rounded,
              onPressed: _startLivenessChallenge,
            )
          else if (_livenessStep == _LivenessStep.passed)
            Obx(() => GradientButton(
              text: 'Capture & Verify Face',
              icon: Icons.face_retouching_natural_rounded,
              isLoading: _attendance.isLoading.value,
              onPressed: _attendance.isLoading.value
                  ? null
                  : _captureAndVerifyFace,
            )),
        ],
      ),
    );
  }
}

// ─── Oval Frame Painter ───────────────────────────────────────
class _OvalPainter extends CustomPainter {
  final Color color;
  const _OvalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
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
  bool shouldRepaint(_OvalPainter old) => old.color != color;
}

// ─── Step Dot ────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDone;
  final bool isActive;

  const _StepDot({
    required this.icon,
    required this.label,
    this.isDone = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone
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
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}

// ─── Step Connector ──────────────────────────────────────────
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
