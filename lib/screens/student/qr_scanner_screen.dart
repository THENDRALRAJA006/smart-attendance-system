// ============================================================
// SmartAttend — QR Scanner Screen (Student)
// Fallback attendance via QR code when BLE unavailable
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../controllers/attendance_controller.dart';
import '../../core/theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scanCtrl = MobileScannerController();
  final AttendanceController _attendance = Get.find<AttendanceController>();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    await _scanCtrl.stop();

    final qrToken = barcode!.rawValue!;
    final success = await _attendance.markAttendanceViaQr(qrToken);

    if (!mounted) return;

    if (success) {
      Get.back();
      Get.snackbar(
        'Attendance Marked',
        'QR attendance recorded successfully!',
        backgroundColor: AppTheme.success.withValues(alpha: 0.9),
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        snackPosition: SnackPosition.TOP,
      );
    } else {
      final msg = _attendance.error.value;
      setState(() {
        _error = msg.isNotEmpty ? msg : 'Invalid or expired QR code';
        _processing = false;
      });
      await _scanCtrl.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Camera ──────────────────────────────────────
          MobileScanner(
            controller: _scanCtrl,
            onDetect: _onDetect,
          ),

          // ─── Overlay ─────────────────────────────────────
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ScannerOverlayPainter(),
          ),

          // ─── UI Overlays ─────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Get.back(),
                      ),
                      const Expanded(
                        child: Text(
                          'Scan Attendance QR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.flash_on, color: Colors.white, size: 28),
                        onPressed: () => _scanCtrl.toggleTorch(),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Center label
                const Text(
                  'Point camera at the QR code\ndisplayed by your faculty',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 60),

                // Error or processing
                if (_processing)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Marking attendance...',
                            style: TextStyle(color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),

                if (_error != null && !_processing)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppTheme.error, fontSize: 13),
                          ),
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

// ─── Scanner Overlay Painter ──────────────────────────────
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cornerSize = 32.0;
    const frameSize = 260.0;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final left = centerX - frameSize / 2;
    final top = centerY - frameSize / 2 - 40;
    final right = centerX + frameSize / 2;
    final bottom = centerY + frameSize / 2 - 40;

    // Dim overlay
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
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
    // Corners only — no full frame border needed

    final p = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 4
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
    canvas.drawLine(
        Offset(right - cornerSize, bottom), Offset(right, bottom), p);
    canvas.drawLine(Offset(right, bottom - cornerSize), Offset(right, bottom), p);
  }

  @override
  bool shouldRepaint(_) => false;
}
