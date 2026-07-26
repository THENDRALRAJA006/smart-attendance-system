// ============================================================
// SmartAttend — QR Scanner Overlay Widget (Enterprise)
// Animated scan line, corner brackets, scan frame
// ============================================================

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class QrScannerOverlay extends StatefulWidget {
  final bool isScanning;
  final bool isSuccess;
  final bool isError;
  final double size;

  const QrScannerOverlay({
    super.key,
    this.isScanning = true,
    this.isSuccess = false,
    this.isError = false,
    this.size = 260,
  });

  @override
  State<QrScannerOverlay> createState() => _QrScannerOverlayState();
}

class _QrScannerOverlayState extends State<QrScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanLineAnim = Tween<double>(begin: 0.05, end: 0.95)
        .animate(CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  Color get _frameColor {
    if (widget.isSuccess) return AppTheme.success;
    if (widget.isError) return AppTheme.error;
    return AppTheme.bioQr;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scanLineController,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              // ── Semi-transparent outer mask ───────────────
              Positioned.fill(
                child: CustomPaint(
                  painter: _QrMaskPainter(
                    frameSize: widget.size,
                    frameColor: _frameColor,
                  ),
                ),
              ),

              // ── Corner brackets ───────────────────────────
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _QrCornerPainter(color: _frameColor),
              ),

              // ── Animated scan line (only when scanning) ───
              if (widget.isScanning && !widget.isSuccess && !widget.isError)
                Positioned(
                  left: 16,
                  right: 16,
                  top: widget.size * _scanLineAnim.value,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _frameColor.withValues(alpha: 0),
                          _frameColor,
                          _frameColor.withValues(alpha: 0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(color: _frameColor.withValues(alpha: 0.6), blurRadius: 8),
                      ],
                    ),
                  ),
                ),

              // ── Success check overlay ─────────────────────
              if (widget.isSuccess)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 72),
                    ),
                  ),
                ),

              // ── Error X overlay ───────────────────────────
              if (widget.isError)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.cancel_rounded, color: AppTheme.error, size: 72),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QrMaskPainter extends CustomPainter {
  final double frameSize;
  final Color frameColor;

  const _QrMaskPainter({required this.frameSize, required this.frameColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = frameColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromLTRBR(0, 0, size.width, size.height, const Radius.circular(16));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_QrMaskPainter old) => old.frameColor != frameColor;
}

class _QrCornerPainter extends CustomPainter {
  final Color color;
  const _QrCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const corner = 24.0;
    const r = 16.0;

    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(const Offset(r, 0), const Offset(r + corner, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, r + corner), paint);
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2), -3.14, 1.57, false, paint);

    // Top-right
    canvas.drawLine(Offset(w - r - corner, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(w, r), Offset(w, r + corner), paint);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2), -1.57, 1.57, false, paint);

    // Bottom-left
    canvas.drawLine(const Offset(0, 0) + Offset(0, h - r - corner), Offset(0, h - r), paint);
    canvas.drawLine(const Offset(r, 0) + Offset(0, h), Offset(r + corner, h), paint);
    canvas.drawArc(Rect.fromLTWH(0, h - r * 2, r * 2, r * 2), 1.57, 1.57, false, paint);

    // Bottom-right
    canvas.drawLine(Offset(w - r - corner, h), Offset(w - r, h), paint);
    canvas.drawLine(Offset(w, h - r - corner), Offset(w, h - r), paint);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2), 0, 1.57, false, paint);
  }

  @override
  bool shouldRepaint(_QrCornerPainter old) => old.color != color;
}
