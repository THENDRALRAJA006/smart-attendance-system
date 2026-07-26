// ============================================================
// SmartAttend — Quality Indicator Bar Widget (Enterprise)
// Real-time face quality indicators for the face verification
// screen: brightness, blur, distance, and pose feedback
// ============================================================

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum QualityLevel { good, warning, bad }

class QualityIndicatorBar extends StatelessWidget {
  final bool faceDetected;
  final double brightness; // 0.0 - 1.0
  final bool isBlurry;
  final bool isTooClose;
  final bool isTooFar;
  final double? poseYaw;    // head left/right angle
  final double? posePitch;  // head up/down angle

  const QualityIndicatorBar({
    super.key,
    required this.faceDetected,
    this.brightness = 0.5,
    this.isBlurry = false,
    this.isTooClose = false,
    this.isTooFar = false,
    this.poseYaw,
    this.posePitch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IndicatorDot(
            label: faceDetected ? 'Face ✓' : 'No Face',
            level: faceDetected ? QualityLevel.good : QualityLevel.bad,
            icon: Icons.face_rounded,
          ),
          const SizedBox(width: 8),
          _IndicatorDot(
            label: isBlurry ? 'Blurry' : 'Sharp',
            level: isBlurry ? QualityLevel.warning : QualityLevel.good,
            icon: Icons.lens_blur_rounded,
          ),
          const SizedBox(width: 8),
          _IndicatorDot(
            label: _brightnessLabel(brightness),
            level: _brightnessLevel(brightness),
            icon: Icons.wb_sunny_rounded,
          ),
          if (isTooClose || isTooFar) ...[
            const SizedBox(width: 8),
            _IndicatorDot(
              label: isTooClose ? 'Too Close' : 'Too Far',
              level: QualityLevel.warning,
              icon: isTooClose ? Icons.zoom_in_rounded : Icons.zoom_out_rounded,
            ),
          ],
          if (poseYaw != null && poseYaw!.abs() > 20) ...[
            const SizedBox(width: 8),
            _IndicatorDot(
              label: poseYaw! < 0 ? '← Center' : 'Center →',
              level: QualityLevel.warning,
              icon: poseYaw! < 0
                  ? Icons.arrow_back_rounded
                  : Icons.arrow_forward_rounded,
            ),
          ],
        ],
      ),
    );
  }

  String _brightnessLabel(double b) {
    if (b >= 0.6) return 'Bright';
    if (b >= 0.35) return 'Good Light';
    return 'Dark';
  }

  QualityLevel _brightnessLevel(double b) {
    if (b >= 0.35) return QualityLevel.good;
    if (b >= 0.2) return QualityLevel.warning;
    return QualityLevel.bad;
  }
}

// ─── Single Indicator Dot ─────────────────────────────────────
class _IndicatorDot extends StatelessWidget {
  final String label;
  final QualityLevel level;
  final IconData icon;

  const _IndicatorDot({
    required this.label,
    required this.level,
    required this.icon,
  });

  Color get _color {
    switch (level) {
      case QualityLevel.good:    return AppTheme.success;
      case QualityLevel.warning: return AppTheme.warning;
      case QualityLevel.bad:     return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _color, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: _color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Brightness Bar ──────────────────────────────────────────
class BrightnessIndicatorBar extends StatelessWidget {
  final double brightness; // 0.0 - 1.0

  const BrightnessIndicatorBar({super.key, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final Color barColor = brightness >= 0.35
        ? AppTheme.success
        : brightness >= 0.2
            ? AppTheme.warning
            : AppTheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.brightness_6_rounded, color: barColor, size: 12),
            const SizedBox(width: 4),
            Text(
              'Light',
              style: TextStyle(color: barColor, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 60,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(color: AppTheme.bgCardLight),
                FractionallySizedBox(
                  widthFactor: brightness.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.warning, barColor],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
