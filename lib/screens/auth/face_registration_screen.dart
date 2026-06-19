// ============================================================
// SmartAttend — Face Registration Screen
// ============================================================

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/camera_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  final CameraService _camera = Get.find();
  final AuthController _auth = Get.find();
  bool _isCaptured = false;
  String? _capturedPath;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _camera.initialize();
    setState(() {});
  }

  Future<void> _captureAndRegister() async {
    if (!_camera.isInitialized.value) return;

    final file = await _camera.captureImage();
    setState(() {
      _capturedPath = file.path;
      _isCaptured = true;
    });

    final success = await _auth.registerFace(file.path);
    if (success) {
      Get.offAllNamed(AppConstants.routeStudentDashboard);
    } else {
      setState(() => _isCaptured = false);
    }
  }

  void _retake() {
    setState(() {
      _isCaptured = false;
      _capturedPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // ─── Header ──────────────────────────────────
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: AppTheme.textPrimary, size: 20),
                      onPressed: () => Get.back(),
                    ),
                    const Expanded(
                      child: Text(
                        'Register Face ID',
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

                const SizedBox(height: 8),

                const Text(
                  'Position your face clearly in the frame',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // ─── Camera Preview ───────────────────────────
                Expanded(
                  child: Obx(() {
                    if (!_camera.isInitialized.value) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          children: [
                            // Camera or captured preview
                            Positioned.fill(
                              child: _capturedPath != null
                                  ? Image.file(
                                      Uri.file(_capturedPath!).toFilePath() as dynamic,
                                      fit: BoxFit.cover,
                                    )
                                  : CameraPreview(_camera.controller!),
                            ),

                            // ─── Face Overlay Frame ───────────
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _FaceFramePainter(),
                              ),
                            ),

                            // ─── AI Scanning Animation ────────
                            if (!_isCaptured)
                              Positioned.fill(
                                child: _ScanningOverlay(),
                              ),

                            // ─── Captured Badge ───────────────
                            if (_isCaptured)
                              Positioned(
                                top: 20,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Captured',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
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
                ),

                const SizedBox(height: 24),

                // ─── Tips ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: AppTheme.warning, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ensure good lighting • Look directly at camera • Remove glasses',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Action Buttons ───────────────────────────
                Obx(() {
                  if (_auth.isLoading.value) {
                    return const GradientButton(
                      text: 'Uploading to AWS Rekognition...',
                      isLoading: true,
                    );
                  }

                  if (_isCaptured) {
                    return Row(
                      children: [
                        Expanded(
                          child: OutlineButton(
                            text: 'Retake',
                            icon: Icons.refresh_rounded,
                            onPressed: _retake,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GradientButton(
                            text: 'Register',
                            icon: Icons.done_rounded,
                            onPressed: () =>
                                _auth.registerFace(_capturedPath!),
                          ),
                        ),
                      ],
                    );
                  }

                  return GradientButton(
                    text: 'Capture Face',
                    icon: Icons.camera_alt_outlined,
                    onPressed: _captureAndRegister,
                  );
                }),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () =>
                      Get.offAllNamed(AppConstants.routeStudentDashboard),
                  child: const Text(
                    'Skip for now (Not Recommended)',
                    style: TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Face Frame Overlay Painter ──────────────────────────────
class _FaceFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const ovalW = 180.0;
    const ovalH = 240.0;
    final rect =
        Rect.fromCenter(center: Offset(cx, cy), width: ovalW, height: ovalH);

    // Dashed oval
    final path = Path()..addOval(rect);
    canvas.drawPath(path, paint..color = AppTheme.primary.withOpacity(0.4));

    // Corner accents
    const len = 30.0;
    final corners = [
      [Offset(cx - ovalW / 2, cy - ovalH / 2 + len), Offset(cx - ovalW / 2, cy - ovalH / 2), Offset(cx - ovalW / 2 + len, cy - ovalH / 2)],
    ];
    paint.color = AppTheme.primary;
    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], paint);
      canvas.drawLine(corner[1], corner[2], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Scanning Overlay Animation ──────────────────────────────
class _ScanningOverlay extends StatefulWidget {
  @override
  State<_ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<_ScanningOverlay>
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
    _anim = Tween<double>(begin: 0.0, end: 1.0).animate(_ctrl);
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
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanLinePainter(_anim.value),
        );
      },
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
          AppTheme.primary.withOpacity(0.7),
          Colors.transparent,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, y - 2, size.width, 4));

    canvas.drawRect(
      Rect.fromLTWH(0, y - 2, size.width, 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
