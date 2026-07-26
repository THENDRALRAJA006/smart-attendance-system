// ============================================================
// SmartAttend — QR Scanner Screen (Production v3)
// Premium camera scanner with:
//  - Animated laser line sweep
//  - Haptic feedback on scan
//  - Torch toggle with icon state
//  - Success flash animation
//  - Better error handling with retry
// ============================================================

import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../controllers/attendance_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _scanCtrl = MobileScannerController();
  final AttendanceController _attendance = Get.find<AttendanceController>();
  bool _processing = false;
  bool _torchOn = false;
  String? _error;

  // Laser animation
  late AnimationController _laserController;
  late Animation<double> _laserAnim;

  // Success flash
  late AnimationController _flashController;
  late Animation<double> _flashAnim;

  @override
  void initState() {
    super.initState();

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnim = CurvedAnimation(
      parent: _laserController,
      curve: Curves.easeInOut,
    );

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _flashController.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    // Haptic + flash
    HapticFeedback.mediumImpact();
    _flashController.forward(from: 0.0);

    setState(() {
      _processing = true;
      _error = null;
    });

    await _scanCtrl.stop();

    final qrToken = barcode!.rawValue!;
    int? sessionId;

    try {
      final parts = qrToken.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decodedStr = utf8.decode(base64Url.decode(normalized));
        final payloadMap = json.decode(decodedStr) as Map<String, dynamic>;
        if (payloadMap['type'] == 'qr_attendance') {
          sessionId = payloadMap['session_id'] as int?;
        }
      }
    } catch (e) {
      dev.log('[QR_SCAN] JWT decoding failed: $e');
    }

    if (sessionId == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Invalid QR code. Please scan a valid SmartAttend attendance QR.';
        _processing = false;
      });
      await _scanCtrl.start();
      return;
    }

    // Set attendance context
    _attendance.setDeepLinkContext(sessionId: sessionId);
    await _attendance.fetchSessionInfo(sessionId);

    if (!mounted) return;

    if (_attendance.errorMessage.value.isNotEmpty) {
      setState(() {
        _error = _attendance.errorMessage.value;
        _processing = false;
      });
      await _scanCtrl.start();
      return;
    }

    // Success — navigate to verification method screen
    _attendance.capturedRssi.value = 0;
    _attendance.step.value = AttendanceStep.bleDone;

    Get.offNamed(AppConstants.routeVerificationMethod);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const frameSize = 260.0;
    final frameTop = screenSize.height / 2 - frameSize / 2 - 40;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Camera ────────────────────────────────────────
          MobileScanner(
            controller: _scanCtrl,
            onDetect: _onDetect,
          ),

          // ─── Scanner overlay (dim + corners) ────────────────
          AnimatedBuilder(
            animation: _laserAnim,
            builder: (_, __) => CustomPaint(
              size: screenSize,
              painter: _ScannerOverlayPainter(
                laserProgress: _laserAnim.value,
                showLaser: !_processing,
                isSuccess: _processing && _error == null,
              ),
            ),
          ),

          // ─── Success flash ───────────────────────────────────
          AnimatedBuilder(
            animation: _flashAnim,
            builder: (_, __) => Opacity(
              opacity: _flashAnim.value * 0.3,
              child: Container(color: AppTheme.success),
            ),
          ),

          // ─── UI Overlays ─────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 26),
                        onPressed: () => Get.back(),
                      ),
                      const Expanded(
                        child: Text(
                          'Scan Attendance QR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _torchOn ? Icons.flash_on : Icons.flash_off,
                          color: _torchOn ? Colors.amber : Colors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          setState(() => _torchOn = !_torchOn);
                          _scanCtrl.toggleTorch();
                        },
                      ),
                    ],
                  ),
                ),

                // ── Position label ──────────────────────────
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, color: Colors.white70, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Point at faculty\'s screen',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: frameTop - 80),

                // ── Spacer: scan frame area ─────────────────
                const SizedBox(height: frameSize + 20),

                const Spacer(),

                // ── Status area ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      if (_processing && _error == null)
                        _StatusCard(
                          color: AppTheme.primary,
                          icon: Icons.radar_rounded,
                          text: 'Processing QR code...',
                          isLoading: true,
                        ),
                      if (_error != null && !_processing)
                        _StatusCard(
                          color: AppTheme.error,
                          icon: Icons.error_outline_rounded,
                          text: _error!,
                          isLoading: false,
                          onRetry: () async {
                            setState(() => _error = null);
                            await _scanCtrl.start();
                          },
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Card ─────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final bool isLoading;
  final VoidCallback? onRetry;

  const _StatusCard({
    required this.color,
    required this.icon,
    required this.text,
    required this.isLoading,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Scanner Overlay Painter ──────────────────────────────────
class _ScannerOverlayPainter extends CustomPainter {
  final double laserProgress;
  final bool showLaser;
  final bool isSuccess;

  const _ScannerOverlayPainter({
    required this.laserProgress,
    required this.showLaser,
    required this.isSuccess,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cornerSize = 30.0;
    const frameSize = 260.0;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final left = centerX - frameSize / 2;
    final top = centerY - frameSize / 2 - 40;
    final right = centerX + frameSize / 2;
    final bottom = centerY + frameSize / 2 - 40;

    // Dim overlay
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromLTRBR(
              left, top, right, bottom, const Radius.circular(16))),
      ),
      dimPaint,
    );

    // Corner brackets
    final cornerColor = isSuccess ? AppTheme.success : AppTheme.primary;
    final p = Paint()
      ..color = cornerColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // TL
    canvas.drawLine(Offset(left, top + cornerSize), Offset(left, top), p);
    canvas.drawLine(Offset(left, top), Offset(left + cornerSize, top), p);
    // TR
    canvas.drawLine(Offset(right - cornerSize, top), Offset(right, top), p);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerSize), p);
    // BL
    canvas.drawLine(Offset(left, bottom - cornerSize), Offset(left, bottom), p);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerSize, bottom), p);
    // BR
    canvas.drawLine(Offset(right - cornerSize, bottom), Offset(right, bottom), p);
    canvas.drawLine(Offset(right, bottom - cornerSize), Offset(right, bottom), p);

    // Animated laser line
    if (showLaser) {
      final laserY = top + (bottom - top) * laserProgress;
      final laserPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppTheme.primary.withValues(alpha: 0.8),
            AppTheme.primary,
            AppTheme.primary.withValues(alpha: 0.8),
            Colors.transparent,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTRB(left, laserY, right, laserY + 2))
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(left + 8, laserY), Offset(right - 8, laserY), laserPaint);

      // Laser glow
      final glowPaint = Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRect(Rect.fromLTRB(left + 8, laserY - 4, right - 8, laserY + 4), glowPaint);
    }
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter old) =>
      old.laserProgress != laserProgress ||
      old.showLaser != showLaser ||
      old.isSuccess != isSuccess;
}
