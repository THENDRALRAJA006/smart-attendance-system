// ============================================================
// SmartAttend — Face Registration Screen (v4)
// 15-Pose Guided Face Capture Sequence
//
// Pose sequence (15 steps):
//   1. Front Face        9.  Blink
//   2. Left 15°         10. Neutral
//   3. Left 30°         11. Slight Left
//   4. Right 15°        12. Slight Right
//   5. Right 30°        13. Front Face (again)
//   6. Look Up          14. Smile (again)
//   7. Look Down        15. Final Front Face
//   8. Smile
//
// Features:
//   - Live camera preview with pose-specific arrow guide overlays
//   - Quality validation per frame (brightness, sharpness, single face)
//   - Auto-capture with 3-second countdown
//   - Progress indicator (1/15 → 15/15)
//   - Immediate per-pose upload to backend
//   - S3 folder structure: students/{id}/face_{XX}.jpg
// ============================================================

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/camera_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

// ─── Pose Metadata ────────────────────────────────────────────
class _PoseStep {
  final int index;
  final String type;
  final String title;
  final String instruction;
  final IconData icon;
  final double arrowAngle; // degrees — direction arrow to show

  const _PoseStep({
    required this.index,
    required this.type,
    required this.title,
    required this.instruction,
    required this.icon,
    this.arrowAngle = 0,
  });
}

const List<_PoseStep> _poseSequence = [
  _PoseStep(index: 1,  type: 'front_face',   title: 'Front Face',        instruction: 'Look directly at the camera',            icon: Icons.face,                   arrowAngle: 0),
  _PoseStep(index: 2,  type: 'left_15',      title: 'Left 15°',          instruction: 'Turn your head slightly LEFT',           icon: Icons.arrow_back,             arrowAngle: 180),
  _PoseStep(index: 3,  type: 'left_30',      title: 'Left 30°',          instruction: 'Turn your head further LEFT',            icon: Icons.arrow_back,             arrowAngle: 180),
  _PoseStep(index: 4,  type: 'right_15',     title: 'Right 15°',         instruction: 'Turn your head slightly RIGHT',          icon: Icons.arrow_forward,          arrowAngle: 0),
  _PoseStep(index: 5,  type: 'right_30',     title: 'Right 30°',         instruction: 'Turn your head further RIGHT',           icon: Icons.arrow_forward,          arrowAngle: 0),
  _PoseStep(index: 6,  type: 'look_up',      title: 'Look Up',           instruction: 'Tilt your head UP',                      icon: Icons.arrow_upward,           arrowAngle: 270),
  _PoseStep(index: 7,  type: 'look_down',    title: 'Look Down',         instruction: 'Tilt your head DOWN',                    icon: Icons.arrow_downward,         arrowAngle: 90),
  _PoseStep(index: 8,  type: 'smile',        title: 'Smile',             instruction: 'Smile naturally',                        icon: Icons.sentiment_very_satisfied, arrowAngle: 0),
  _PoseStep(index: 9,  type: 'blink',        title: 'Blink',             instruction: 'Blink once slowly',                     icon: Icons.remove_red_eye,         arrowAngle: 0),
  _PoseStep(index: 10, type: 'neutral',      title: 'Neutral',           instruction: 'Return to neutral expression',           icon: Icons.sentiment_neutral,      arrowAngle: 0),
  _PoseStep(index: 11, type: 'slight_left',  title: 'Slight Left',       instruction: 'Slight turn to the left',                icon: Icons.arrow_back,             arrowAngle: 180),
  _PoseStep(index: 12, type: 'slight_right', title: 'Slight Right',      instruction: 'Slight turn to the right',               icon: Icons.arrow_forward,          arrowAngle: 0),
  _PoseStep(index: 13, type: 'front_face_2', title: 'Front (Again)',     instruction: 'Look at the camera again',               icon: Icons.face,                   arrowAngle: 0),
  _PoseStep(index: 14, type: 'smile_2',      title: 'Smile (Again)',     instruction: 'Give us your best smile!',               icon: Icons.sentiment_very_satisfied, arrowAngle: 0),
  _PoseStep(index: 15, type: 'final_front',  title: 'Final Front',       instruction: 'Final photo — look at camera',           icon: Icons.camera_front,           arrowAngle: 0),
];

// ─── Screen ───────────────────────────────────────────────────
class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen>
    with TickerProviderStateMixin {
  final CameraService _camera = Get.find();
  final AuthController _auth = Get.find();

  // Countdown timer
  Timer? _countdownTimer;
  int _countdown = 3;
  bool _isCountingDown = false;
  bool _isUploading = false;
  String? _lastError;
  bool _poseSuccess = false;

  // Animation controllers
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _successCtrl;
  late Animation<double> _successAnim;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initAnimations();
    _auth.resetPoseRegistration();
  }

  Future<void> _initCamera() async {
    await _camera.initialize();
    setState(() {});
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _successAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  // ─── Current Pose ────────────────────────────────────────
  _PoseStep get _currentPose {
    final idx = _auth.currentPoseIndex.value.clamp(1, 15);
    return _poseSequence[idx - 1];
  }

  // ─── Start Countdown ─────────────────────────────────────
  void _startCountdown() {
    if (_isCountingDown || _isUploading) return;
    setState(() {
      _countdown = 3;
      _isCountingDown = true;
      _lastError = null;
      _poseSuccess = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);

      if (_countdown <= 0) {
        t.cancel();
        await _captureAndUpload();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _countdown = 3;
    });
  }

  // ─── Capture + Upload ────────────────────────────────────
  Future<void> _captureAndUpload() async {
    if (!_camera.isInitialized.value) return;
    if (_isUploading) return;

    setState(() {
      _isCountingDown = false;
      _isUploading = true;
      _lastError = null;
    });

    try {
      final file = await _camera.captureImage();
      final poseIndex = _auth.currentPoseIndex.value;

      final result = await _auth.registerFacePose(
        imagePath: file.path,
        poseIndex: poseIndex,
      );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _lastError = _auth.errorMessage.value.isNotEmpty
              ? _auth.errorMessage.value
              : 'Upload failed. Please try again.';
          _isUploading = false;
        });
        return;
      }

      if (result['success'] == true) {
        setState(() {
          _poseSuccess = true;
          _isUploading = false;
        });
        _successCtrl.forward(from: 0);

        // Check if registration is complete
        if (_auth.poseRegistrationComplete.value) {
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            Get.offAllNamed(AppConstants.routeStudentDashboard);
          }
        } else {
          // Auto-advance to next pose after 1.2s
          await Future.delayed(const Duration(milliseconds: 1200));
          if (mounted) {
            setState(() => _poseSuccess = false);
            _successCtrl.reset();
          }
        }
      } else {
        setState(() {
          _lastError = result['message'] as String? ??
              'Quality check failed. Please adjust your position.';
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastError = 'Capture failed. Please try again.';
          _isUploading = false;
        });
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressBar(),
              Expanded(child: _buildCameraSection()),
              _buildPoseCard(),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textPrimary, size: 22),
            onPressed: () => Get.back(),
          ),
          const Expanded(
            child: Text(
              'Face Registration',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Obx(() => Text(
            '${_auth.currentPoseIndex.value}/15',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          )),
        ],
      ),
    );
  }

  // ─── Progress Bar ─────────────────────────────────────────
  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final progress = (_auth.currentPoseIndex.value - 1) / 15;
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            );
          }),
          const SizedBox(height: 6),
          Obx(() => Text(
            'Step ${_auth.currentPoseIndex.value} of 15 — ${_poseSequence[(_auth.currentPoseIndex.value - 1).clamp(0, 14)].title}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          )),
        ],
      ),
    );
  }

  // ─── Camera Section ───────────────────────────────────────
  Widget _buildCameraSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Obx(() {
        if (!_camera.isInitialized.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _poseSuccess
                  ? AppTheme.success
                  : AppTheme.primary.withValues(alpha: 0.5),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (_poseSuccess ? AppTheme.success : AppTheme.primary)
                    .withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Camera preview
                Positioned.fill(
                  child: CameraPreview(_camera.controller!),
                ),

                // Face oval frame
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FaceOvalPainter(
                      color: _poseSuccess ? AppTheme.success : AppTheme.primary,
                    ),
                  ),
                ),

                // Direction arrow overlay
                Positioned.fill(
                  child: _ArrowOverlay(pose: _currentPose),
                ),

                // Scanning line animation
                if (!_isUploading && !_poseSuccess)
                  Positioned.fill(child: _ScanLineAnimation()),

                // Countdown overlay
                if (_isCountingDown)
                  _buildCountdownOverlay(),

                // Uploading overlay
                if (_isUploading)
                  _buildUploadingOverlay(),

                // Success overlay
                if (_poseSuccess)
                  _buildSuccessOverlay(),

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
                            color: Colors.white,
                            fontSize: 10,
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

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnim.value,
            child: Text(
              '$_countdown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadingOverlay() {
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
                color: AppTheme.primary,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Uploading to AWS...',
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

  Widget _buildSuccessOverlay() {
    return AnimatedBuilder(
      animation: _successAnim,
      builder: (context, child) => Opacity(
        opacity: _successAnim.value.clamp(0.0, 1.0),
        child: Container(
          color: AppTheme.success.withValues(alpha: 0.25),
          child: Center(
            child: Transform.scale(
              scale: _successAnim.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Pose Card ───────────────────────────────────────────
  Widget _buildPoseCard() {
    return Obx(() {
      final pose = _poseSequence[(_auth.currentPoseIndex.value - 1).clamp(0, 14)];
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(pose.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pose.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pose.instruction,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─── Controls ────────────────────────────────────────────
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        children: [
          // Error message
          if (_lastError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lastError!,
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Capture / Cancel buttons
          if (_isCountingDown)
            OutlinedButton.icon(
              icon: const Icon(Icons.close, color: AppTheme.error, size: 18),
              label: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _cancelCountdown,
            )
          else
            Obx(() => GradientButton(
              text: _auth.isLoading.value
                  ? 'Uploading...'
                  : 'Capture Pose ${_auth.currentPoseIndex.value}/15',
              icon: Icons.camera_alt_rounded,
              isLoading: _auth.isLoading.value,
              onPressed: _auth.isLoading.value ? null : _startCountdown,
            )),

          const SizedBox(height: 8),

          // Tips row
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline,
                  color: AppTheme.warning, size: 14),
              SizedBox(width: 6),
              Text(
                'Good lighting • Single face • Stay still',
                style: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Face Oval Painter ────────────────────────────────────────
class _FaceOvalPainter extends CustomPainter {
  final Color color;
  const _FaceOvalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.47),
      width: size.width * 0.55,
      height: size.height * 0.7,
    );
    canvas.drawOval(rect, paint);

    // Corner brackets
    final bPaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 22.0;
    final corners = [
      // Top-left
      [Offset(rect.left, rect.top + len), rect.topLeft, Offset(rect.left + len, rect.top)],
      // Top-right
      [Offset(rect.right - len, rect.top), rect.topRight, Offset(rect.right, rect.top + len)],
      // Bottom-left
      [Offset(rect.left, rect.bottom - len), rect.bottomLeft, Offset(rect.left + len, rect.bottom)],
      // Bottom-right
      [Offset(rect.right - len, rect.bottom), rect.bottomRight, Offset(rect.right, rect.bottom - len)],
    ];

    for (final c in corners) {
      canvas.drawLine(c[0], c[1], bPaint);
      canvas.drawLine(c[1], c[2], bPaint);
    }
  }

  @override
  bool shouldRepaint(_FaceOvalPainter old) => old.color != color;
}

// ─── Direction Arrow Overlay ──────────────────────────────────
class _ArrowOverlay extends StatelessWidget {
  final _PoseStep pose;
  const _ArrowOverlay({required this.pose});

  @override
  Widget build(BuildContext context) {
    // Only show for directional poses
    final showArrow = [
      'left_15', 'left_30', 'right_15', 'right_30',
      'look_up', 'look_down', 'slight_left', 'slight_right',
    ].contains(pose.type);

    if (!showArrow) return const SizedBox.shrink();

    // Determine position + icon
    Alignment alignment;
    IconData arrowIcon;

    switch (pose.type) {
      case 'left_15':
      case 'left_30':
      case 'slight_left':
        alignment = Alignment.centerLeft;
        arrowIcon = Icons.arrow_back_ios_rounded;
        break;
      case 'right_15':
      case 'right_30':
      case 'slight_right':
        alignment = Alignment.centerRight;
        arrowIcon = Icons.arrow_forward_ios_rounded;
        break;
      case 'look_up':
        alignment = Alignment.topCenter;
        arrowIcon = Icons.keyboard_arrow_up_rounded;
        break;
      case 'look_down':
        alignment = Alignment.bottomCenter;
        arrowIcon = Icons.keyboard_arrow_down_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(arrowIcon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ─── Scan Line Animation ──────────────────────────────────────
class _ScanLineAnimation extends StatefulWidget {
  @override
  State<_ScanLineAnimation> createState() => _ScanLineAnimationState();
}

class _ScanLineAnimationState extends State<_ScanLineAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) => CustomPaint(
        painter: _ScanLinePainter(_anim.value),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppTheme.primary.withValues(alpha: 0.6),
          Colors.transparent,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, y - 2, size.width, 4));
    canvas.drawRect(Rect.fromLTWH(0, y - 2, size.width, 4), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

// ─── Outline Button Widget ────────────────────────────────────
class OutlineButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;

  const OutlineButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.close, size: 18),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: BorderSide(color: AppTheme.textHint.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
