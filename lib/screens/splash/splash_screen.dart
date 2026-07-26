// ============================================================
// SmartAttend — Splash Screen (Enterprise v2)
// Premium animated splash with particle rings,
// pulsing logo, enterprise branding
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _ringController;
  late AnimationController _textController;
  late AnimationController _particleController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _subtitleOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_textController);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    // Sequence animations
    _logoController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _textController.forward();
      });
    });

    // Auth check after animations
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) Get.find<AuthController>().checkAuthState();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _ringController.dispose();
    _textController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: Stack(
          children: [
            // ── Particle rings background ─────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ringController,
                builder: (context, _) => CustomPaint(
                  painter: _ParticleRingPainter(progress: _ringController.value),
                ),
              ),
            ),

            // ── Main content ──────────────────────────────
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Animated Logo ───────────────────────
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) => Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(scale: _logoScale.value, child: child),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        AnimatedBuilder(
                          animation: _ringController,
                          builder: (context, _) => Container(
                            width: 130 + 10 * math.sin(_ringController.value * 2 * math.pi),
                            height: 130 + 10 * math.sin(_ringController.value * 2 * math.pi),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        // Logo container
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9B7FFF), Color(0xFF7C5CFF), Color(0xFF5A3FCC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: AppTheme.glowShadow(AppTheme.primary, intensity: 0.5, blur: 40),
                          ),
                          child: const Icon(Icons.fingerprint, color: Colors.white, size: 58),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── App Name ────────────────────────────
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppTheme.primaryGradient.createShader(bounds),
                            child: const Text(
                              'SmartAttend',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FadeTransition(
                            opacity: _subtitleOpacity,
                            child: const Text(
                              'Enterprise Attendance Platform',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),

                  // ── Loading dots ─────────────────────────
                  FadeTransition(
                    opacity: _textOpacity,
                    child: _LoadingDots(),
                  ),

                  const SizedBox(height: 24),

                  // ── Version badge ────────────────────────
                  FadeTransition(
                    opacity: _subtitleOpacity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, color: AppTheme.primary, size: 12),
                          SizedBox(width: 6),
                          Text(
                            'AI-Powered • BLE • Face Recognition',
                            style: TextStyle(
                              color: AppTheme.textHint,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
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
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with TickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (i / 3.0);
            final progress = (_ctrl.value - offset).abs() % 1.0;
            final scale = 0.5 + 0.5 * math.sin(progress * math.pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.4 + 0.6 * scale),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ParticleRingPainter extends CustomPainter {
  final double progress;
  const _ParticleRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    const numParticles = 12;
    final radii = [size.height * 0.3, size.height * 0.42, size.height * 0.52];

    for (final radius in radii) {
      for (int i = 0; i < numParticles; i++) {
        final angle = (i / numParticles) * 2 * math.pi + progress * 2 * math.pi * 0.3;
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        final opacity = 0.03 + 0.05 * math.sin(progress * math.pi * 2 + i);

        paint.color = AppTheme.primary.withValues(alpha: opacity.clamp(0.01, 0.1));
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ParticleRingPainter old) => old.progress != progress;
}
