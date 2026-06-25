// ============================================================
// SmartAttend AI — Face Registration Screen (v5)
// Automatic Multi-Frame Capture → ArcFace Batch Registration
//
// Flow:
//   1. Camera starts automatically
//   2. Animated guide walks student through 8 movements:
//      Front → Smile → Blink → Left → Right → Up → Down → Head Rotation
//   3. Frames captured automatically (~5 fps) during each movement
//   4. Target: 100–150 total frames across all movements
//   5. Student taps "Start Registration" to begin
//   6. All frames sent as batch to POST /auth/face-register-auto
//   7. Backend: blur filter → de-duplicate → store 30–50 unique embeddings
//   8. No images stored permanently — only embeddings
//   9. Navigate to Student Dashboard on success
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/services/camera_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

// ─── Movement Step Metadata ───────────────────────────────────
class _MovementStep {
  final String name;
  final String instruction;
  final IconData icon;
  final int durationMs; // milliseconds to hold this movement

  const _MovementStep({
    required this.name,
    required this.instruction,
    required this.icon,
    this.durationMs = 2500,
  });
}

const List<_MovementStep> _movements = [
  _MovementStep(
    name: 'Front',
    instruction: 'Look directly at the camera',
    icon: Icons.face_rounded,
    durationMs: 2500,
  ),
  _MovementStep(
    name: 'Smile',
    instruction: 'Smile naturally',
    icon: Icons.sentiment_very_satisfied_rounded,
    durationMs: 2000,
  ),
  _MovementStep(
    name: 'Blink',
    instruction: 'Blink slowly once or twice',
    icon: Icons.remove_red_eye_rounded,
    durationMs: 2000,
  ),
  _MovementStep(
    name: 'Turn Left',
    instruction: 'Turn your head to the LEFT',
    icon: Icons.arrow_back_rounded,
    durationMs: 2500,
  ),
  _MovementStep(
    name: 'Turn Right',
    instruction: 'Turn your head to the RIGHT',
    icon: Icons.arrow_forward_rounded,
    durationMs: 2500,
  ),
  _MovementStep(
    name: 'Look Up',
    instruction: 'Tilt your head UP slightly',
    icon: Icons.keyboard_arrow_up_rounded,
    durationMs: 2000,
  ),
  _MovementStep(
    name: 'Look Down',
    instruction: 'Tilt your head DOWN slightly',
    icon: Icons.keyboard_arrow_down_rounded,
    durationMs: 2000,
  ),
  _MovementStep(
    name: 'Head Rotation',
    instruction: 'Slowly rotate your head in a small circle',
    icon: Icons.rotate_right_rounded,
    durationMs: 3000,
  ),
];

// ─── Screen States ────────────────────────────────────────────
enum _RegState { ready, capturing, uploading, success, failed }

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

  // ─── State ─────────────────────────────────────────────────
  _RegState _state = _RegState.ready;
  int _currentMovementIndex = 0;
  int _capturedFrameCount = 0;
  final int _targetFrames = 120;
  String? _errorMessage;
  String _statusMessage = 'Tap "Start Registration" to begin.';

  // Captured image paths (cleared after upload)
  final List<String> _capturedPaths = [];

  // Timers
  Timer? _captureTimer;
  Timer? _movementTimer;

  // ─── Animations ────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _successCtrl;
  late Animation<double> _successAnim;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

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
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _movementTimer?.cancel();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    _progressCtrl.dispose();
    _cleanupTempFiles();
    super.dispose();
  }

  void _cleanupTempFiles() {
    for (final path in _capturedPaths) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    _capturedPaths.clear();
  }

  // ─── Start Auto-Capture ──────────────────────────────────────
  void _startCapture() {
    if (!_camera.isInitialized.value) return;
    setState(() {
      _state = _RegState.capturing;
      _currentMovementIndex = 0;
      _capturedFrameCount = 0;
      _capturedPaths.clear();
      _errorMessage = null;
      _statusMessage = 'Follow the guide...';
    });
    _scheduleMovement();
  }

  void _scheduleMovement() {
    if (!mounted || _state != _RegState.capturing) return;

    final movement = _movements[_currentMovementIndex];
    setState(() {
      _statusMessage = movement.instruction;
    });

    // Capture frames at ~5 fps during this movement window
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (!mounted || _state != _RegState.capturing) return;
      await _captureOneFrame();
    });

    // Advance to next movement after duration
    _movementTimer?.cancel();
    _movementTimer = Timer(Duration(milliseconds: movement.durationMs), () {
      _captureTimer?.cancel();
      if (!mounted || _state != _RegState.capturing) return;

      final nextIndex = _currentMovementIndex + 1;
      if (nextIndex < _movements.length) {
        setState(() => _currentMovementIndex = nextIndex);
        _scheduleMovement();
      } else {
        // All movements done — upload batch
        _uploadBatch();
      }
    });
  }

  Future<void> _captureOneFrame() async {
    if (!_camera.isInitialized.value) return;
    if (_capturedFrameCount >= _targetFrames + 30) return; // safety cap
    try {
      final file = await _camera.captureImage(compress: false);
      if (!mounted) return;
      _capturedPaths.add(file.path);
      setState(() {
        _capturedFrameCount = _capturedPaths.length;
      });
    } catch (_) {
      // Silent — missed frame is fine
    }
  }

  // ─── Upload Batch ────────────────────────────────────────────
  Future<void> _uploadBatch() async {
    _captureTimer?.cancel();
    _movementTimer?.cancel();

    if (_capturedPaths.isEmpty) {
      setState(() {
        _state = _RegState.failed;
        _errorMessage = 'No frames captured. Please try again.';
      });
      return;
    }

    setState(() {
      _state = _RegState.uploading;
      _statusMessage = 'Processing ${_capturedPaths.length} frames...';
    });

    try {
      final api = ApiClient.to;

      // Build multipart FormData with one entry per frame
      final List<dio.MultipartFile> frameFiles = [];
      for (final path in _capturedPaths) {
        frameFiles.add(
          await dio.MultipartFile.fromFile(
            path,
            filename: 'frame.jpg',
          ),
        );
      }

      final formData = dio.FormData();
      for (final frame in frameFiles) {
        formData.files.add(MapEntry('files', frame));
      }

      final response = await api.postMultipart(
        AppConstants.endpointFaceRegisterAuto,
        formData,
      );

      final data = response.data as Map<String, dynamic>;

      if (!mounted) return;

      if (data['success'] == true) {
        // Update auth controller's face registration state
        _auth.markFaceRegistered();

        setState(() {
          _state = _RegState.success;
          _statusMessage =
              'Registered! ${data['stored']} unique samples stored.';
        });
        _successCtrl.forward(from: 0);
        _cleanupTempFiles();

        // Navigate to student dashboard after brief success display
        await Future.delayed(const Duration(milliseconds: 2200));
        if (mounted) {
          Get.offAllNamed(AppConstants.routeStudentDashboard);
        }
      } else {
        setState(() {
          _state = _RegState.failed;
          _errorMessage = data['message'] as String? ??
              'Registration failed. Please try again.';
        });
        _cleanupTempFiles();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _RegState.failed;
        _errorMessage = 'Upload failed: ${e.toString()}';
      });
      _cleanupTempFiles();
    }
  }

  void _retry() {
    _captureTimer?.cancel();
    _movementTimer?.cancel();
    _cleanupTempFiles();
    setState(() {
      _state = _RegState.ready;
      _currentMovementIndex = 0;
      _capturedFrameCount = 0;
      _errorMessage = null;
      _statusMessage = 'Tap "Start Registration" to begin.';
    });
    _successCtrl.reset();
  }

  // ─── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressSection(),
              Expanded(child: _buildCameraSection()),
              _buildMovementCard(),
              _buildActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textPrimary, size: 22),
            onPressed: _state == _RegState.uploading
                ? null
                : () => Get.back(),
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
          // ArcFace badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.face_retouching_natural_rounded,
                    color: AppTheme.primary, size: 12),
                SizedBox(width: 4),
                Text(
                  'ArcFace AI',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progress Section ─────────────────────────────────────────
  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Frame capture progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _state == _RegState.success
                  ? 1.0
                  : (_capturedFrameCount / _targetFrames).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                _state == _RegState.success
                    ? AppTheme.success
                    : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _state == _RegState.capturing
                    ? 'Movement ${_currentMovementIndex + 1} / ${_movements.length}: '
                        '${_movements[_currentMovementIndex].name}'
                    : _state == _RegState.uploading
                        ? 'Analyzing frames...'
                        : _state == _RegState.success
                            ? 'Registration complete ✅'
                            : 'Auto-capture (${_movements.length} movements)',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '$_capturedFrameCount / $_targetFrames frames',
                style: const TextStyle(
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

  // ─── Camera Section ───────────────────────────────────────────
  Widget _buildCameraSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Obx(() {
        if (!_camera.isInitialized.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final borderColor = _state == _RegState.success
            ? AppTheme.success
            : _state == _RegState.failed
                ? AppTheme.error
                : _state == _RegState.capturing
                    ? AppTheme.accent
                    : AppTheme.primary;

        return AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: _state == _RegState.capturing ? _pulseAnim.value : 1.0,
            child: child,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.25),
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
                  Positioned.fill(child: CameraPreview(_camera.controller!)),

                  // Face oval guide
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FaceOvalPainter(color: borderColor),
                    ),
                  ),

                  // Movement direction arrow overlay
                  if (_state == _RegState.capturing)
                    _MovementArrowOverlay(
                      movement: _movements[_currentMovementIndex],
                    ),

                  // Capturing indicator (pulsing dot)
                  if (_state == _RegState.capturing)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.error.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Uploading overlay
                  if (_state == _RegState.uploading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.7),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                color: AppTheme.accent,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _statusMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Detecting faces · Filtering blur · Deduplicating',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Success overlay
                  if (_state == _RegState.success)
                    AnimatedBuilder(
                      animation: _successAnim,
                      builder: (_, __) => Opacity(
                        opacity: _successAnim.value.clamp(0.0, 1.0),
                        child: Container(
                          color: AppTheme.success.withValues(alpha: 0.25),
                          child: Center(
                            child: Transform.scale(
                              scale: _successAnim.value,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  color: AppTheme.success,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ArcFace AI badge (bottom left)
                  Positioned(
                    bottom: 14,
                    left: 14,
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
                          Icon(Icons.security_rounded,
                              color: AppTheme.accent, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'InsightFace',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
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
    );
  }

  // ─── Movement Card ────────────────────────────────────────────
  Widget _buildMovementCard() {
    if (_state == _RegState.success) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Face Registered Successfully!',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_state == _RegState.failed && _errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.error, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final movement = (_state == _RegState.capturing ||
            _state == _RegState.uploading)
        ? _movements[_currentMovementIndex.clamp(0, _movements.length - 1)]
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: movement != null
            ? Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(movement.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movement.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          movement.instruction,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppTheme.primary, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Position your face in the oval. '
                      'The camera will automatically capture frames as you follow each movement.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── Action Bar ───────────────────────────────────────────────
  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        children: [
          if (_state == _RegState.ready)
            Obx(() => GradientButton(
                  text: _camera.isInitialized.value
                      ? 'Start Registration'
                      : 'Starting Camera...',
                  icon: Icons.play_arrow_rounded,
                  isLoading: !_camera.isInitialized.value,
                  onPressed:
                      _camera.isInitialized.value ? _startCapture : null,
                )),

          if (_state == _RegState.capturing)
            OutlinedButton.icon(
              icon: const Icon(Icons.stop_circle_outlined,
                  color: AppTheme.error, size: 18),
              label: const Text(
                'Cancel',
                style: TextStyle(
                    color: AppTheme.error, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _retry,
            ),

          if (_state == _RegState.uploading)
            const SizedBox(
              height: 50,
              child: Center(
                child: Text(
                  'Uploading frames to ArcFace engine...',
                  style: TextStyle(
                      color: AppTheme.textHint, fontSize: 13),
                ),
              ),
            ),

          if (_state == _RegState.failed)
            GradientButton(
              text: 'Try Again',
              icon: Icons.refresh_rounded,
              onPressed: _retry,
            ),

          if (_state == _RegState.success) const SizedBox(height: 50),

          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: AppTheme.warning, size: 14),
              SizedBox(width: 6),
              Text(
                'Good lighting · Single face · No glasses',
                style:
                    TextStyle(color: AppTheme.textHint, fontSize: 11),
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
      [Offset(rect.left, rect.top + len), rect.topLeft, Offset(rect.left + len, rect.top)],
      [Offset(rect.right - len, rect.top), rect.topRight, Offset(rect.right, rect.top + len)],
      [Offset(rect.left, rect.bottom - len), rect.bottomLeft, Offset(rect.left + len, rect.bottom)],
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

// ─── Movement Arrow Overlay ───────────────────────────────────
class _MovementArrowOverlay extends StatelessWidget {
  final _MovementStep movement;
  const _MovementArrowOverlay({required this.movement});

  @override
  Widget build(BuildContext context) {
    Alignment? alignment;
    IconData? arrowIcon;

    switch (movement.name) {
      case 'Turn Left':
        alignment = Alignment.centerLeft;
        arrowIcon = Icons.arrow_back_ios_rounded;
        break;
      case 'Turn Right':
        alignment = Alignment.centerRight;
        arrowIcon = Icons.arrow_forward_ios_rounded;
        break;
      case 'Look Up':
        alignment = Alignment.topCenter;
        arrowIcon = Icons.keyboard_arrow_up_rounded;
        break;
      case 'Look Down':
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
            color: AppTheme.accent.withValues(alpha: 0.75),
            shape: BoxShape.circle,
          ),
          child: Icon(arrowIcon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
