// ============================================================
// SmartAttend — Animated Face Frame Widget (Enterprise)
// Circular/oval face frame with animated corner brackets,
// live quality indicators, and state-based color transitions
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum FaceFrameState {
  idle,       // Waiting for face
  detecting,  // Face partially visible
  aligned,    // Face well-positioned
  captured,   // Photo taken
  verifying,  // Sending to ArcFace
}

class AnimatedFaceFrame extends StatefulWidget {
  final FaceFrameState state;
  final Widget? child;
  final double width;
  final double height;

  const AnimatedFaceFrame({
    super.key,
    required this.state,
    this.child,
    this.width = 260,
    this.height = 320,
  });

  @override
  State<AnimatedFaceFrame> createState() => _AnimatedFaceFrameState();
}

class _AnimatedFaceFrameState extends State<AnimatedFaceFrame>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _stateController;
  late Animation<double> _pulseAnim;
  late Animation<double> _rotateAnim;

  Color _frameColor = AppTheme.primary;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _stateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _rotateAnim = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));

    _updateColor();
  }

  @override
  void didUpdateWidget(AnimatedFaceFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateColor();
      if (widget.state == FaceFrameState.aligned || widget.state == FaceFrameState.captured) {
        _stateController.forward(from: 0);
      }
      if (widget.state == FaceFrameState.verifying) {
        _rotateController.repeat();
      }
    }
  }

  void _updateColor() {
    setState(() {
      switch (widget.state) {
        case FaceFrameState.idle:
          _frameColor = AppTheme.primary;
        case FaceFrameState.detecting:
          _frameColor = AppTheme.bioQr;
        case FaceFrameState.aligned:
          _frameColor = AppTheme.bioAligned;
        case FaceFrameState.captured:
          _frameColor = AppTheme.success;
        case FaceFrameState.verifying:
          _frameColor = AppTheme.bioLiveness;
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _rotateController]),
      builder: (context, _) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Outer glow ring ───────────────────────────
              Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.width / 2),
                  boxShadow: AppTheme.glowShadow(_frameColor, intensity: 0.25, blur: 30),
                ),
              ),

              // ── Main oval clip ────────────────────────────
              Transform.scale(
                scale: widget.state == FaceFrameState.idle
                    ? _pulseAnim.value
                    : 1.0,
                child: ClipOval(
                  child: SizedBox(
                    width: widget.width,
                    height: widget.height,
                    child: widget.child ?? const ColoredBox(color: Colors.black),
                  ),
                ),
              ),

              // ── Oval border ───────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.width / 2),
                  border: Border.all(
                    color: _frameColor,
                    width: widget.state == FaceFrameState.aligned ? 3.5 : 2.5,
                  ),
                ),
              ),

              // ── Rotating corner brackets ──────────────────
              if (widget.state == FaceFrameState.verifying)
                Transform.rotate(
                  angle: _rotateAnim.value,
                  child: _CornerBrackets(
                    width: widget.width + 10,
                    height: widget.height + 10,
                    color: _frameColor,
                  ),
                )
              else
                _CornerBrackets(
                  width: widget.width - 10,
                  height: widget.height - 10,
                  color: _frameColor,
                ),

              // ── State badge ───────────────────────────────
              Positioned(
                bottom: 20,
                child: _StateBadge(state: widget.state, color: _frameColor),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CornerBrackets extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _CornerBrackets({required this.width, required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _CornerBracketPainter(color: color),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  const _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 26.0;
    final w = size.width;
    final h = size.height;
    final rx = w / 2;
    final ry = h / 2;

    // Draw 4 corner brackets along oval perimeter
    final angles = [
      -math.pi * 0.75, // top-left
      -math.pi * 0.25, // top-right
      math.pi * 0.25,  // bottom-right
      math.pi * 0.75,  // bottom-left
    ];

    for (final angle in angles) {
      final cx = rx + rx * math.cos(angle);
      final cy = ry + ry * math.sin(angle);

      // Tangent direction for bracket
      final tx = -math.sin(angle);
      final ty = math.cos(angle);

      final p1 = Offset(cx - tx * len / 2, cy - ty * len / 2);
      final p2 = Offset(cx + tx * len / 2, cy + ty * len / 2);
      canvas.drawLine(p1, p2, paint);

      // Inward tick
      final nx = math.cos(angle);
      final ny = math.sin(angle);
      final center = Offset(cx, cy);
      canvas.drawLine(center, Offset(cx - nx * 10, cy - ny * 10), paint);
    }
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) => old.color != color;
}

class _StateBadge extends StatelessWidget {
  final FaceFrameState state;
  final Color color;

  const _StateBadge({required this.state, required this.color});

  String get _label {
    switch (state) {
      case FaceFrameState.idle:       return 'Position Your Face';
      case FaceFrameState.detecting:  return 'Face Detected';
      case FaceFrameState.aligned:    return 'Hold Steady';
      case FaceFrameState.captured:   return 'Captured ✓';
      case FaceFrameState.verifying:  return 'Verifying...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == FaceFrameState.verifying)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(color: color, strokeWidth: 1.5),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 8),
          Text(
            _label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}
