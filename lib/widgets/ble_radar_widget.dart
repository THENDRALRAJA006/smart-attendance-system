// ============================================================
// SmartAttend — BLE Radar Widget (Production v3)
// Animated radar: rotating sweep, pulsing rings, device blips
// v3: Classroom name labels on blips, RSSI strength color,
//     green glow when in-range device found, signal bars
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/services/ble_service.dart';
import '../core/theme/app_theme.dart';

class BleRadarWidget extends StatefulWidget {
  final bool isScanning;
  final int deviceCount;
  final bool hasInRangeDevice;
  final List<DetectedClassroom> devices;

  const BleRadarWidget({
    super.key,
    required this.isScanning,
    this.deviceCount = 0,
    this.hasInRangeDevice = false,
    this.devices = const [],
  });

  @override
  State<BleRadarWidget> createState() => _BleRadarWidgetState();
}

class _BleRadarWidgetState extends State<BleRadarWidget>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.hasInRangeDevice
        ? AppTheme.success
        : widget.isScanning
            ? AppTheme.primary
            : AppTheme.textHint;

    return AnimatedBuilder(
      animation: Listenable.merge([_radarController, _pulseController, _glowController]),
      builder: (context, _) {
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Outer glow when device in range ─────────────
              if (widget.hasInRangeDevice)
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.success.withValues(
                            alpha: 0.08 + _glowController.value * 0.08),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),

              // ── Radar rings (animated phase per ring) ────────
              ...[0.30, 0.50, 0.70, 0.90].map((scale) {
                final phase = (_radarController.value + (1.0 - scale) * 0.6) % 1.0;
                final opacity = widget.isScanning ? (1.0 - phase) * 0.45 : 0.07;
                return Container(
                  width: 240 * scale,
                  height: 240 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: opacity.clamp(0.02, 0.5)),
                      width: 1.5,
                    ),
                  ),
                );
              }),

              // ── Rotating sweep arc ───────────────────────────
              if (widget.isScanning)
                Transform.rotate(
                  angle: _radarController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(240, 240),
                    painter: _SweepPainter(color: color),
                  ),
                ),

              // ── Device blips with labels ─────────────────────
              ..._buildDeviceBlips(color),

              // ── Center icon ──────────────────────────────────
              Transform.scale(
                scale: 0.96 + _pulseController.value * 0.04,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: widget.isScanning || widget.hasInRangeDevice
                        ? (widget.hasInRangeDevice
                            ? AppTheme.successGradient
                            : AppTheme.primaryGradient)
                        : LinearGradient(
                            colors: [AppTheme.bgCardLight, AppTheme.bgCard]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(
                            alpha: 0.3 + _pulseController.value * 0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.hasInRangeDevice
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_searching_rounded,
                    color: widget.isScanning || widget.hasInRangeDevice
                        ? Colors.white
                        : AppTheme.textHint,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDeviceBlips(Color baseColor) {
    final blips = <Widget>[];
    final angles = [0.3, 1.2, 2.1, 3.6, 4.9];
    final radii  = [60.0, 78.0, 52.0, 70.0, 62.0];

    final count = widget.devices.isNotEmpty
        ? widget.devices.length
        : widget.deviceCount;

    for (int i = 0; i < count.clamp(0, 5); i++) {
      final angle  = angles[i % angles.length];
      final radius = radii[i % radii.length];
      final cx = 120 + radius * math.cos(angle);
      final cy = 120 + radius * math.sin(angle);

      // Determine color from RSSI or in-range state
      final Color blipColor;
      String? label;
      String? rssiLabel;

      if (i < widget.devices.length) {
        final dev = widget.devices[i];
        blipColor = dev.isInRange ? AppTheme.success : AppTheme.warning;
        // Shorten classroom name to first 10 chars
        final name = dev.name;
        label = name.length > 10 ? '${name.substring(0, 9)}…' : name;
        rssiLabel = '${dev.rssi} dBm';
      } else {
        blipColor = baseColor;
      }

      blips.add(
        Positioned(
          left: cx - 8,
          top: cy - 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blip dot with pulse glow
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: blipColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: blipColor.withValues(
                          alpha: 0.5 + _glowController.value * 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Label below
              if (label != null) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: blipColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (rssiLabel != null)
                  Text(
                    rssiLabel,
                    style: const TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 7,
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    }
    return blips;
  }
}

// ─── Sweep Painter ───────────────────────────────────────────
class _SweepPainter extends CustomPainter {
  final Color color;
  const _SweepPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.35)],
        stops: const [0.0, 1.0],
        startAngle: 0,
        endAngle: 0.55,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.color != color;
}
