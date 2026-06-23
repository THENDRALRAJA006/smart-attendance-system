// ============================================================
// SmartAttend — Attendance Face Verification Screen (v5)
// Manual Capture → Preview → Verify Attendance
//
// Flow:
//   1. Camera preview (live)
//   2. Student taps "Capture Selfie"
//   3. Image preview shown (Retake / Verify Attendance)
//   4. Student taps "Verify Attendance"
//   5. Optional liveness runs (non-blocking)
//   6. AWS Rekognition CompareFaces
//   7. Navigate to result screen
// ============================================================

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/camera_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

// ─── UI State Machine ─────────────────────────────────────────
enum _VerifyState {
  /// Live camera preview — waiting for student to capture
  cameraReady,

  /// Image captured — showing preview (retake / verify)
  imageCaptured,

  /// Optional liveness challenge running (non-blocking)
  livenessRunning,

  /// Sending to AWS Rekognition + marking attendance
  verifying,
}

class AttendanceVerificationScreen extends StatefulWidget {
  const AttendanceVerificationScreen({super.key});

  @override
  State<AttendanceVerificationScreen> createState() =>
      _AttendanceVerificationScreenState();
}

class _AttendanceVerificationScreenState
    extends State<AttendanceVerificationScreen>
    with SingleTickerProviderStateMixin {
  // ─── Services ──────────────────────────────────────────────
  final CameraService _camera = Get.find();
  final AuthController _auth = Get.find();
  final AttendanceController _attendance = Get.find();

  // ─── State ─────────────────────────────────────────────────
  _VerifyState _state = _VerifyState.cameraReady;
  File? _capturedImage;
  String? _errorMessage;
  String _statusMessage = 'Initializing camera...';

  // ─── Liveness (optional) ───────────────────────────────────
  bool _livenessVerified = false;
  String? _livenessToken;

  // ─── Animation ─────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ─── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCamera();
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    try {
      await _camera.initialize();
      if (!mounted) return;
      setState(() {
        _state = _VerifyState.cameraReady;
        _statusMessage = 'Position your face in the oval and tap Capture';
      });
      dev.log('[CAMERA] Initialized successfully', name: 'VerifyScreen');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
      dev.log('[CAMERA] Init error: $e', name: 'VerifyScreen');
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── Step 1: Capture Selfie ───────────────────────────────
  Future<void> _captureImage() async {
    dev.log('[CAMERA] Capturing selfie...', name: 'VerifyScreen');
    setState(() {
      _errorMessage = null;
      _statusMessage = 'Capturing...';
    });

    try {
      final file = await _camera.captureImage();
      dev.log('[CAMERA] Captured: ${file.path}', name: 'VerifyScreen');

      if (!mounted) return;
      setState(() {
        _capturedImage = file;
        _state = _VerifyState.imageCaptured;
        _statusMessage = 'Review your photo';
      });
    } catch (e) {
      dev.log('[CAMERA] Capture failed: $e', name: 'VerifyScreen');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Capture failed: $e. Please try again.';
      });
    }
  }

  // ─── Step 1b: Retake ──────────────────────────────────────
  void _retake() {
    dev.log('[CAMERA] Retaking photo', name: 'VerifyScreen');
    setState(() {
      _capturedImage = null;
      _state = _VerifyState.cameraReady;
      _errorMessage = null;
      _livenessVerified = false;
      _livenessToken = null;
      _statusMessage = 'Position your face in the oval and tap Capture';
    });
  }

  // ─── Step 2: Optional Liveness ───────────────────────────
  /// Liveness is non-blocking: if it fails, we proceed with liveness_verified=false.
  Future<void> _runOptionalLiveness() async {
    dev.log('[LIVENESS] Fetching challenge...', name: 'VerifyScreen');
    setState(() {
      _state = _VerifyState.livenessRunning;
      _statusMessage = 'Running optional liveness check...';
    });

    try {
      final challengeSuccess = await _auth.fetchLivenessChallenge();
      if (!mounted) return;

      if (!challengeSuccess) {
        dev.log('[LIVENESS] Challenge fetch failed — proceeding without liveness',
            name: 'VerifyScreen');
        _submitVerification();
        return;
      }

      dev.log(
          '[LIVENESS] Challenge: ${_auth.livenessChallenge.value}',
          name: 'VerifyScreen');

      // Capture 3 frames for liveness (uses the already initialized camera)
      final List<String> framePaths = [];
      for (int i = 0; i < 3; i++) {
        if (!mounted) break;
        await Future.delayed(const Duration(milliseconds: 700));
        try {
          final frame = await _camera.captureImage();
          framePaths.add(frame.path);
          dev.log('[LIVENESS] Frame ${i + 1} captured', name: 'VerifyScreen');
        } catch (e) {
          dev.log('[LIVENESS] Frame ${i + 1} capture error: $e',
              name: 'VerifyScreen');
        }
      }

      if (!mounted) return;

      // Verify liveness frames — non-blocking
      if (framePaths.isNotEmpty) {
        final result = await _auth.verifyLiveness(framePaths);
        if (!mounted) return;
        if (result != null && result['passed'] == true) {
          _livenessVerified = true;
          _livenessToken = _auth.liveChallengeToken.value;
          dev.log('[LIVENESS] Passed ✅', name: 'VerifyScreen');
        } else {
          dev.log('[LIVENESS] Failed — proceeding without liveness token',
              name: 'VerifyScreen');
        }
      }
    } catch (e) {
      dev.log('[LIVENESS] Unexpected error: $e — proceeding', name: 'VerifyScreen');
    }

    // Always proceed to face verification regardless of liveness result
    _submitVerification();
  }

  // ─── Step 3: Submit Face Verification ────────────────────
  Future<void> _submitVerification() async {
    final image = _capturedImage;
    if (image == null) {
      setState(() {
        _errorMessage = 'No image captured. Please take a selfie first.';
        _state = _VerifyState.cameraReady;
      });
      return;
    }

    dev.log(
        '[AWS] Sending to Rekognition — image=${image.path}, '
        'session=${_attendance.deepLinkSessionId.value}, '
        'rssi=${_attendance.capturedRssi.value}, '
        'liveness_verified=$_livenessVerified',
        name: 'VerifyScreen');

    if (!mounted) return;
    setState(() {
      _state = _VerifyState.verifying;
      _statusMessage = 'Verifying face & marking attendance...';
    });

    // Delegate to controller — passes the pre-captured image
    await _attendance.captureAndVerify(
      imageFile: image,
      livenessToken: _livenessToken,
    );
    // Controller handles navigation to result screen
  }

  // ─── Triggered by "Verify Attendance" button ─────────────
  Future<void> _onVerifyPressed() async {
    if (_capturedImage == null) return;
    // Run optional liveness then submit
    await _runOptionalLiveness();
  }

  // ─── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildCameraArea()),
              _buildStatusCard(),
              _buildActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary, size: 20),
            onPressed: _state == _VerifyState.verifying
                ? null
                : () => Get.back(),
          ),
          Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Face Verification',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_attendance.deepLinkSessionSubject.value.isNotEmpty)
                    Text(
                      _attendance.deepLinkSessionSubject.value,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              )),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ─── Camera / Preview Area ────────────────────────────────
  Widget _buildCameraArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Obx(() {
        final isCameraReady = _camera.isInitialized.value;

        if (!isCameraReady && _capturedImage == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 16),
                Text(
                  'Starting camera...',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _borderColor,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _borderColor.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Camera or Preview ──────────────────────
                if (_capturedImage != null)
                  Image.file(_capturedImage!, fit: BoxFit.cover)
                else if (_camera.controller != null)
                  CameraPreview(_camera.controller!)
                else
                  Container(color: Colors.black),

                // ── Face oval mask ──────────────────────────
                if (_capturedImage == null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FaceMaskPainter(color: _borderColor),
                    ),
                  ),

                // ── Captured label ─────────────────────────
                if (_capturedImage != null &&
                    _state == _VerifyState.imageCaptured)
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Photo Captured',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Verifying overlay ──────────────────────
                if (_state == _VerifyState.verifying ||
                    _state == _VerifyState.livenessRunning)
                  _buildVerifyingOverlay(),

                // ── AWS badge ─────────────────────────────
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              color: AppTheme.accent, size: 12),
                          SizedBox(width: 5),
                          Text(
                            'AWS REKOGNITION PROTECTED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
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

  Color get _borderColor {
    switch (_state) {
      case _VerifyState.imageCaptured:
        return AppTheme.success;
      case _VerifyState.verifying:
      case _VerifyState.livenessRunning:
        return AppTheme.accent;
      default:
        return AppTheme.primary;
    }
  }

  Widget _buildVerifyingOverlay() {
    final label = _state == _VerifyState.livenessRunning
        ? 'Running liveness check...'
        : 'Verifying with AWS Rekognition...';
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 3),
            const SizedBox(height: 20),
            const Icon(Icons.face_retouching_natural_rounded,
                color: AppTheme.textSecondary, size: 36),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Status Card ─────────────────────────────────────────
  Widget _buildStatusCard() {
    IconData icon;
    Color iconColor;
    String title;
    String body;

    if (_errorMessage != null) {
      icon = Icons.error_outline_rounded;
      iconColor = AppTheme.error;
      title = 'Error';
      body = _errorMessage!;
    } else {
      switch (_state) {
        case _VerifyState.cameraReady:
          icon = Icons.camera_alt_rounded;
          iconColor = AppTheme.primary;
          title = 'Ready to Capture';
          body = 'Centre your face inside the oval. Make sure you have good lighting.';
          break;
        case _VerifyState.imageCaptured:
          icon = Icons.preview_rounded;
          iconColor = AppTheme.success;
          title = 'Review Your Photo';
          body = 'If the photo is clear, tap "Verify Attendance". Otherwise tap Retake.';
          break;
        case _VerifyState.livenessRunning:
          icon = Icons.security_rounded;
          iconColor = AppTheme.accent;
          title = 'Anti-Spoof Check';
          body = 'Running liveness verification. Please look at the camera.';
          break;
        case _VerifyState.verifying:
          icon = Icons.cloud_upload_rounded;
          iconColor = AppTheme.accent;
          title = 'Submitting';
          body = 'Sending to AWS Rekognition for face matching...';
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Container(
          key: ValueKey(_state.name + (_errorMessage ?? '')),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: iconColor.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Action Bar ──────────────────────────────────────────
  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _buildActionContent(),
      ),
    );
  }

  Widget _buildActionContent() {
    // Blocking states — no buttons
    if (_state == _VerifyState.verifying ||
        _state == _VerifyState.livenessRunning) {
      return const SizedBox(
        key: ValueKey('loading'),
        height: 54,
        child: Center(
          child: Text(
            'Please wait...',
            style: TextStyle(color: AppTheme.textHint, fontSize: 13),
          ),
        ),
      );
    }

    // After image captured — show Retake + Verify
    if (_state == _VerifyState.imageCaptured) {
      return Column(
        key: const ValueKey('captured'),
        children: [
          GradientButton(
            text: 'Verify Attendance',
            icon: Icons.verified_user_rounded,
            onPressed: _onVerifyPressed,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _retake,
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: AppTheme.textPrimary),
            label: const Text('Retake Photo',
                style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      );
    }

    // Camera ready — show capture button (or error retry)
    return Column(
      key: const ValueKey('camera'),
      children: [
        if (_errorMessage != null) ...[
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _errorMessage = null);
              _initCamera();
            },
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: AppTheme.textPrimary),
            label: const Text('Retry Camera',
                style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: BorderSide(color: AppTheme.error.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Obx(() => GradientButton(
              text: _camera.isInitialized.value
                  ? 'Capture Selfie'
                  : 'Starting Camera...',
              icon: Icons.camera_alt_rounded,
              isLoading: !_camera.isInitialized.value,
              onPressed:
                  _camera.isInitialized.value ? _captureImage : null,
            )),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                color: AppTheme.warning, size: 13),
            SizedBox(width: 5),
            Text(
              'Ensure good lighting and face the camera directly.',
              style: TextStyle(
                color: AppTheme.textHint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Custom Oval Face Mask Painter ──────────────────────────
class _FaceMaskPainter extends CustomPainter {
  final Color color;
  const _FaceMaskPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.60);

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: size.width * 0.62,
      height: size.height * 0.64,
    );

    final ovalPath = Path()..addOval(ovalRect);
    final fullRect =
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final exterior =
        Path.combine(PathOperation.difference, fullRect, ovalPath);
    canvas.drawPath(exterior, backgroundPaint);

    // Oval border
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    // Corner crop marks
    final cropPaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const l = 22.0;
    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(ovalRect.left, ovalRect.top + l)
        ..lineTo(ovalRect.left, ovalRect.top)
        ..lineTo(ovalRect.left + l, ovalRect.top),
      cropPaint,
    );
    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(ovalRect.right - l, ovalRect.top)
        ..lineTo(ovalRect.right, ovalRect.top)
        ..lineTo(ovalRect.right, ovalRect.top + l),
      cropPaint,
    );
    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(ovalRect.left, ovalRect.bottom - l)
        ..lineTo(ovalRect.left, ovalRect.bottom)
        ..lineTo(ovalRect.left + l, ovalRect.bottom),
      cropPaint,
    );
    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(ovalRect.right - l, ovalRect.bottom)
        ..lineTo(ovalRect.right, ovalRect.bottom)
        ..lineTo(ovalRect.right, ovalRect.bottom - l),
      cropPaint,
    );
  }

  @override
  bool shouldRepaint(_FaceMaskPainter old) => old.color != color;
}
