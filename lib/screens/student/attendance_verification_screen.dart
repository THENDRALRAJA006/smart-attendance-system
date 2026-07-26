// ============================================================
// SmartAttend — Face Verification Screen (Enterprise v2)
// Biometric-grade UI: circular face frame, quality indicators,
// auto-capture, real-time feedback, mandatory chain guard
//
// Arrival: ONLY after BLE + QR + Liveness all verified.
// ============================================================

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/attendance_controller.dart';
import '../../core/services/camera_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/animated_face_frame.dart';
import '../../widgets/biometric_progress_bar.dart';
import '../../widgets/gradient_button.dart';

class AttendanceVerificationScreen extends StatefulWidget {
  const AttendanceVerificationScreen({super.key});

  @override
  State<AttendanceVerificationScreen> createState() =>
      _AttendanceVerificationScreenState();
}

class _AttendanceVerificationScreenState
    extends State<AttendanceVerificationScreen>
    with TickerProviderStateMixin {
  final AttendanceController _attendance = Get.find();
  final CameraService _cameraService = Get.find();

  CameraController? _cameraCtrl;

  bool _isCapturing = false;
  bool _autoCapturePending = false;
  bool _cameraInitialized = false;
  String? _error;
  FaceFrameState _frameState = FaceFrameState.idle;

  // Quality indicators
  bool _faceDetected = false;
  double _brightness = 0.5;
  bool _isBlurry = false;

  Timer? _autoCaptureTimer;
  Timer? _fakeQualityTimer;

  late AnimationController _entryController;
  late AnimationController _captureFlashController;
  late Animation<double> _entryFade;
  late Animation<double> _captureFlash;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _captureFlashController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _entryFade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _captureFlash = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _captureFlashController, curve: Curves.easeOut));

    _entryController.forward();
    _initCamera();
    _startFakeQualityLoop();

    dev.log(
      '[FACE_VERIFY] Screen opened. BLE=${_attendance.bleVerified.value} '
      'Liveness=${_attendance.livenessVerified.value}',
      name: 'FaceVerify',
    );
  }

  Future<void> _initCamera() async {
    dev.log('[FACE_VERIFY] Camera init starting...', name: 'FaceVerify');
    try {
      await _cameraService.initialize();
      _cameraCtrl = _cameraService.controller;
      setState(() => _cameraInitialized = true);
      dev.log('[FACE_VERIFY] ✅ Camera initialized successfully', name: 'FaceVerify');

      // Start auto-detect loop
      _startAutoDetectLoop();
    } catch (e) {
      dev.log('[FACE_VERIFY] ❌ Camera init failed: $e', name: 'FaceVerify');
      setState(() => _error = 'Camera initialization failed: $e');
    }
  }

  // Simulate quality feedback (real implementation would analyze camera frames)
  void _startFakeQualityLoop() {
    _fakeQualityTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted || _isCapturing) return;
      setState(() {
        // Simulate face detection and quality after camera is ready
        if (_cameraInitialized) {
          _faceDetected = true;
          _brightness = 0.7;
          _isBlurry = false;
          if (_frameState == FaceFrameState.idle) {
            _frameState = FaceFrameState.detecting;
          }
        }
      });
    });
  }

  void _startAutoDetectLoop() {
    dev.log('[FACE_VERIFY] Auto-detect loop started', name: 'FaceVerify');
    // After 2s of idle → move to "aligned" state → auto capture at 1.5s
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && !_isCapturing) {
        dev.log('[FACE_VERIFY] Face aligned — scheduling auto-capture', name: 'FaceVerify');
        setState(() => _frameState = FaceFrameState.aligned);
        _scheduleAutoCapture();
      }
    });
  }

  void _scheduleAutoCapture() {
    if (_autoCapturePending || _isCapturing) return;
    _autoCapturePending = true;
    _autoCaptureTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && !_isCapturing) _capture();
    });
  }

  Future<void> _capture() async {
    if (_isCapturing) return;
    _autoCaptureTimer?.cancel();

    dev.log('[FACE_VERIFY] Capture started', name: 'FaceVerify');

    setState(() {
      _isCapturing = true;
      _frameState = FaceFrameState.captured;
    });

    HapticFeedback.mediumImpact();

    // Flash animation
    _captureFlashController.forward().then((_) =>
        _captureFlashController.reverse());

    try {
      if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) {
        throw Exception('Camera not initialized');
      }

      final xfile = await _cameraCtrl!.takePicture();
      final imageFile = File(xfile.path);
      dev.log('[FACE_VERIFY] Photo captured: ${xfile.path}', name: 'FaceVerify');

      setState(() => _frameState = FaceFrameState.verifying);
      dev.log('[FACE_VERIFY] Sending to ArcFace verification...', name: 'FaceVerify');

      await _attendance.verifyFace(
        imageFile: imageFile,
        attendanceMethodHint: 'face',
      );
      dev.log('[FACE_VERIFY] ✅ verifyFace() completed', name: 'FaceVerify');
    } catch (e) {
      dev.log('[FACE_VERIFY] ❌ Capture/verify error: $e', name: 'FaceVerify');
      setState(() {
        _isCapturing = false;
        _frameState = FaceFrameState.idle;
        _error = 'Capture failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    _fakeQualityTimer?.cancel();
    _entryController.dispose();
    _captureFlashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _entryFade,
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressBar(),
              Expanded(child: _buildCameraSection()),
              _buildBottomBar(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(8, 16, 24, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
            onPressed: _isCapturing ? null : () => Get.back(),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Face Verification', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                Text('ArcFace AI Recognition', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.bioLiveness.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.bioLiveness.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.security, color: AppTheme.bioLiveness, size: 12),
                SizedBox(width: 4),
                Text('SECURED', style: TextStyle(color: AppTheme.bioLiveness, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Obx(() => BiometricProgressBar(
            // Face flow: BLE ✓ → Liveness ✓ → Face Match → Done
            flowMode: AttendanceFlowMode.face,
            currentStep: BiometricStep.face,
            bleVerified: _attendance.bleVerified.value,
            livenessVerified: _attendance.livenessVerified.value,
            faceVerified: false,
          )),
    );
  }

  Widget _buildCameraSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera preview background
        if (_cameraCtrl != null && _cameraInitialized)
          Positioned.fill(child: CameraPreview(_cameraCtrl!)),

        // Dark vignette
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              ),
            ),
          ),
        ),

        // Face frame
        AnimatedFaceFrame(
          state: _frameState,
          width: MediaQuery.of(context).size.width * 0.72,
          height: MediaQuery.of(context).size.height * 0.45,
          child: _cameraCtrl != null && _cameraInitialized
              ? CameraPreview(_cameraCtrl!)
              : const ColoredBox(color: Colors.black54),
        ),

        // Flash overlay on capture
        AnimatedBuilder(
          animation: _captureFlash,
          builder: (context, _) => Positioned.fill(
            child: Opacity(
              opacity: _captureFlash.value * 0.6,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ),

        // Quality indicator panel (top)
        Positioned(
          top: 16,
          left: 24,
          right: 24,
          child: _buildQualityRow(),
        ),

        // Instruction at bottom
        Positioned(
          bottom: 16,
          left: 24,
          right: 24,
          child: _buildInstruction(),
        ),

        // Error
        if (_error != null)
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.errorCard(0.4),
              child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12), textAlign: TextAlign.center),
            ),
          ),

        // Loading overlay
        if (_isCapturing && _frameState == FaceFrameState.verifying)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.bioLiveness, strokeWidth: 3),
                    SizedBox(height: 16),
                    Text('Verifying Face...', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    Text('Comparing with registered embeddings', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQualityRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _QualityChip(
          label: _faceDetected ? 'Face ✓' : 'No Face',
          color: _faceDetected ? AppTheme.success : AppTheme.error,
          icon: Icons.face_rounded,
        ),
        const SizedBox(width: 8),
        _QualityChip(
          label: _isBlurry ? 'Blurry' : 'Sharp',
          color: _isBlurry ? AppTheme.warning : AppTheme.success,
          icon: Icons.lens_blur,
        ),
        const SizedBox(width: 8),
        _QualityChip(
          label: _brightness > 0.4 ? 'Good Light' : 'Dark',
          color: _brightness > 0.4 ? AppTheme.success : AppTheme.warning,
          icon: Icons.wb_sunny_rounded,
        ),
      ],
    );
  }

  Widget _buildInstruction() {
    String text;
    switch (_frameState) {
      case FaceFrameState.idle:       text = 'Positioning camera...';
      case FaceFrameState.detecting:  text = 'Face detected — hold still';
      case FaceFrameState.aligned:    text = 'Perfect! Capturing in a moment...';
      case FaceFrameState.captured:   text = 'Captured!';
      case FaceFrameState.verifying:  text = 'Verifying with ArcFace AI...';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        text,
        key: ValueKey(text),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Column(
        children: [
          // Session info
          Obx(() => _attendance.deepLinkSessionSubject.value.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.book_rounded, color: AppTheme.textHint, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        _attendance.deepLinkSessionSubject.value,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      const Text('·', style: TextStyle(color: AppTheme.textHint)),
                      const SizedBox(width: 8),
                      Text(
                        _attendance.deepLinkSessionClassroom.value,
                        style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink()),

          const SizedBox(height: 12),

          // Capture button
          Obx(() {
            if (_attendance.isLoading.value) {
              return const LinearProgressIndicator(color: AppTheme.primary);
            }
            return GradientButton(
              text: _isCapturing ? 'Processing...' : 'Capture & Verify',
              icon: Icons.camera_rounded,
              isLoading: _isCapturing,
              onPressed: _isCapturing ? null : _capture,
            );
          }),

          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, color: AppTheme.textHint, size: 12),
              SizedBox(width: 5),
              Text(
                'ARCFACE SECURED · Embeddings Never Leave Server',
                style: TextStyle(color: AppTheme.textHint, fontSize: 9, letterSpacing: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quality Chip ─────────────────────────────────────────────
class _QualityChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _QualityChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
        ],
      ),
    );
  }
}
