// ============================================================
// SmartAttend — Attendance Result Screen (Production v3)
// Premium success/failure page with:
//  - Animated circular checkmark
//  - Student photo / avatar
//  - Subject, Faculty, Room, Time
//  - Verification method badge
//  - BLE connected indicator
//  - Auto-close after 3 seconds (success only) with countdown ring
//  - Staggered info rows with slide animation
// ============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class AttendanceResultScreen extends StatefulWidget {
  const AttendanceResultScreen({super.key});

  @override
  State<AttendanceResultScreen> createState() => _AttendanceResultScreenState();
}

class _AttendanceResultScreenState extends State<AttendanceResultScreen>
    with TickerProviderStateMixin {
  // ─── Animation Controllers ───────────────────────────────
  late AnimationController _entryCtrl;
  late AnimationController _iconCtrl;
  late AnimationController _rippleCtrl;
  late AnimationController _rowsCtrl;
  late AnimationController _countdownCtrl;

  // ─── Animations ──────────────────────────────────────────
  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<double> _ripple;
  late Animation<double> _rowsFade;
  late Animation<Offset>  _rowsSlide;

  // ─── Auto-close timer (success only) ─────────────────────
  Timer? _autoCloseTimer;
  int _countdown = 3;

  @override
  void initState() {
    super.initState();

    _entryCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _iconCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _rippleCtrl   = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _rowsCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _countdownCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
    _iconFade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _ripple    = Tween<double>(begin: 0.0, end: 1.0).animate(_rippleCtrl);
    _rowsFade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _rowsCtrl, curve: Curves.easeOut));
    _rowsSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
        CurvedAnimation(parent: _rowsCtrl, curve: Curves.easeOutCubic));

    _entryCtrl.forward();
    _iconCtrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _rowsCtrl.forward();
      });
    });

    // Start auto-close on success
    final ctrl = Get.find<AttendanceController>();
    if (ctrl.result.value == AttendanceResult.success) {
      HapticFeedback.heavyImpact();
      _startAutoClose();
    }
  }

  void _startAutoClose() {
    _countdownCtrl.forward();
    _autoCloseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _navigateToDashboard();
      }
    });
  }

  void _navigateToDashboard() {
    final ctrl = Get.find<AttendanceController>();
    ctrl.clearDeepLinkContext();
    Get.offAllNamed(AppConstants.routeStudentDashboard);
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _entryCtrl.dispose();
    _iconCtrl.dispose();
    _rippleCtrl.dispose();
    _rowsCtrl.dispose();
    _countdownCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl    = Get.find<AttendanceController>();
    final auth    = Get.find<AuthController>();
    final result  = ctrl.result.value;
    final isSuccess       = result == AttendanceResult.success;
    final isOutOfRange    = result == AttendanceResult.outOfRange;
    final isAlreadyMarked = result == AttendanceResult.alreadyMarked;

    final Color mainColor = isSuccess
        ? AppTheme.success
        : isOutOfRange
            ? AppTheme.warning
            : AppTheme.error;

    final details = ctrl.attendanceDetails.value;
    final student = auth.currentStudent.value;

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: SafeArea(
        child: FadeTransition(
          opacity: _entryCtrl.drive(CurveTween(curve: Curves.easeOut)),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 20),

                  // ── Animated Icon + Ripple ────────────────
                  _buildAnimatedIcon(isSuccess, isOutOfRange, isAlreadyMarked, mainColor),

                  const SizedBox(height: 20),

                  // ── Title ─────────────────────────────────
                  FadeTransition(
                    opacity: _iconFade,
                    child: Column(
                      children: [
                        Text(
                          _title(isSuccess, isOutOfRange, isAlreadyMarked),
                          style: TextStyle(
                            color: mainColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _subtitle(isSuccess, isOutOfRange, isAlreadyMarked,
                              ctrl.errorMessage.value),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // ── Auto-close countdown (success only) ───
                  if (isSuccess) ...[
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _rowsFade,
                      child: _buildCountdownRing(mainColor),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Details Card ──────────────────────────
                  if (isSuccess || isAlreadyMarked)
                    SlideTransition(
                      position: _rowsSlide,
                      child: FadeTransition(
                        opacity: _rowsFade,
                        child: _buildDetailsCard(details, student, ctrl, mainColor),
                      ),
                    ),

                  // ── Error Card ────────────────────────────
                  if (!isSuccess && !isAlreadyMarked)
                    SlideTransition(
                      position: _rowsSlide,
                      child: FadeTransition(
                        opacity: _rowsFade,
                        child: _buildErrorCard(ctrl.errorMessage.value, mainColor),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ── Action Buttons ────────────────────────
                  FadeTransition(
                    opacity: _rowsFade,
                    child: Column(
                      children: [
                        GradientButton(
                          text: isSuccess ? 'Back to Dashboard' : 'Back to Dashboard',
                          icon: Icons.home_rounded,
                          onPressed: _navigateToDashboard,
                        ),
                        if (!isSuccess) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              ctrl.reset();
                              Get.offAllNamed(AppConstants.routeClassroomDetection);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Try Again'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: const BorderSide(color: AppTheme.textHint),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Animated Icon ─────────────────────────────────────────
  Widget _buildAnimatedIcon(bool isSuccess, bool isOutOfRange, bool isAlreadyMarked, Color color) {
    return AnimatedBuilder(
      animation: Listenable.merge([_iconCtrl, _rippleCtrl]),
      builder: (_, __) {
        return SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ripple rings (success only)
              if (isSuccess)
                ...[0.0, 0.33, 0.66].map((offset) {
                  final phase = (_ripple.value + offset) % 1.0;
                  return Transform.scale(
                    scale: 0.4 + 0.6 * phase,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: (1.0 - phase) * 0.35),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),

              // Main icon circle
              ScaleTransition(
                scale: _iconScale,
                child: FadeTransition(
                  opacity: _iconFade,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2.5),
                      boxShadow: AppTheme.glowShadow(color, intensity: 0.4, blur: 40),
                    ),
                    child: isSuccess
                        ? _AnimatedCheckmark(color: color)
                        : Icon(
                            isOutOfRange
                                ? Icons.signal_wifi_off_rounded
                                : isAlreadyMarked
                                    ? Icons.event_available_rounded
                                    : Icons.cancel_rounded,
                            color: color,
                            size: 60,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Countdown Ring ────────────────────────────────────────
  Widget _buildCountdownRing(Color color) {
    return AnimatedBuilder(
      animation: _countdownCtrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                value: 1.0 - _countdownCtrl.value,
                strokeWidth: 2.5,
                color: color,
                backgroundColor: color.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Closing in $_countdown s',
              style: TextStyle(
                color: AppTheme.textHint,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Details Card ──────────────────────────────────────────
  Widget _buildDetailsCard(dynamic details, dynamic student, AttendanceController ctrl, Color mainColor) {
    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm a').format(now);
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(now);

    final subjectName   = details?.subjectName   ?? ctrl.deepLinkSessionSubject.value;
    final classroomName = details?.classroomName  ?? ctrl.deepLinkSessionClassroom.value;
    final facultyName   = details?.facultyName    ?? '—';
    final confidence    = ctrl.confidenceScore.value;
    final method        = ctrl.verificationMethod.value;

    final studentName = details?.studentName ?? student?.name ?? '—';
    final regNo       = details?.registerNo  ?? student?.regNo ?? '—';
    final department  = details?.department  ?? student?.department ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: mainColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [mainColor.withValues(alpha: 0.08), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                // Student avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.glowShadow(AppTheme.primary, intensity: 0.3, blur: 12),
                  ),
                  child: Center(
                    child: Text(
                      (studentName.isNotEmpty ? studentName[0] : 'S').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$dateStr · $timeStr',
                        style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Verification method badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (method == VerificationMethod.face
                            ? AppTheme.primary
                            : AppTheme.accent)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (method == VerificationMethod.face
                              ? AppTheme.primary
                              : AppTheme.accent)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        method == VerificationMethod.face
                            ? Icons.face_retouching_natural_rounded
                            : Icons.qr_code_rounded,
                        size: 12,
                        color: method == VerificationMethod.face
                            ? AppTheme.primary
                            : AppTheme.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        method == VerificationMethod.face ? 'Face' : 'QR',
                        style: TextStyle(
                          color: method == VerificationMethod.face
                              ? AppTheme.primary
                              : AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.bgCardLight),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _DetailRow(icon: Icons.badge_rounded,          label: 'Reg. No.',   value: regNo),
                _DetailRow(icon: Icons.school_rounded,         label: 'Department', value: department),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppTheme.bgCardLight, height: 1),
                ),
                _DetailRow(icon: Icons.book_rounded,           label: 'Subject',    value: subjectName.isNotEmpty ? subjectName : '—', color: AppTheme.primary),
                _DetailRow(icon: Icons.meeting_room_rounded,   label: 'Classroom',  value: classroomName.isNotEmpty ? classroomName : '—'),
                if (facultyName.isNotEmpty && facultyName != '—')
                  _DetailRow(icon: Icons.person_4_rounded,     label: 'Faculty',    value: facultyName),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppTheme.bgCardLight, height: 1),
                ),
                // Verification chain
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _VerifiedBadge(label: 'BLE',  icon: Icons.bluetooth_rounded,          verified: true),
                    _VerifiedBadge(
                      label: 'Face',
                      icon: Icons.face_retouching_natural,
                      verified: method == VerificationMethod.face,
                    ),
                    _VerifiedBadge(
                      label: 'QR',
                      icon: Icons.qr_code_rounded,
                      verified: method == VerificationMethod.qr,
                    ),
                  ],
                ),
                if (confidence > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_graph_rounded,
                            color: AppTheme.textHint, size: 14),
                        const SizedBox(width: 6),
                        const Text('Match Confidence',
                            style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                        const Spacer(),
                        Text(
                          '${confidence.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: confidence >= 80.0 ? AppTheme.success : AppTheme.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error Card ────────────────────────────────────────────
  Widget _buildErrorCard(String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 36),
          const SizedBox(height: 12),
          Text(
            message.isNotEmpty ? message : 'Attendance could not be marked.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _title(bool isSuccess, bool isOutOfRange, bool isAlreadyMarked) {
    if (isSuccess) return 'Attendance Marked! 🎉';
    if (isAlreadyMarked) return 'Already Marked ✅';
    if (isOutOfRange) return 'Out of Range';
    return 'Verification Failed';
  }

  String _subtitle(bool isSuccess, bool isOutOfRange, bool isAlreadyMarked, String error) {
    if (isSuccess) return 'Your attendance has been recorded successfully.';
    if (isAlreadyMarked) return 'You have already marked attendance for this session.';
    if (isOutOfRange) return 'You are not within classroom BLE range.\nMove closer and try again.';
    return error.isNotEmpty ? error : 'Verification did not succeed. Please try again.';
  }
}

// ─── Animated Checkmark ───────────────────────────────────────
class _AnimatedCheckmark extends StatefulWidget {
  final Color color;
  const _AnimatedCheckmark({required this.color});

  @override
  State<_AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<_AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
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
      builder: (_, __) {
        return CustomPaint(
          painter: _CheckmarkPainter(progress: _anim.value, color: widget.color),
          child: const SizedBox(width: 120, height: 120),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Checkmark path: from (0.25, 0.5) → (0.45, 0.7) → (0.75, 0.35)
    final p1 = Offset(cx - 22, cy + 2);
    final p2 = Offset(cx - 6,  cy + 18);
    final p3 = Offset(cx + 22, cy - 16);

    final totalLength = _distance(p1, p2) + _distance(p2, p3);
    final drawn = totalLength * progress;

    final seg1 = _distance(p1, p2);
    if (drawn <= seg1) {
      final t = drawn / seg1;
      canvas.drawLine(p1, Offset.lerp(p1, p2, t)!, paint);
    } else {
      canvas.drawLine(p1, p2, paint);
      final t2 = (drawn - seg1) / _distance(p2, p3);
      canvas.drawLine(p2, Offset.lerp(p2, p3, t2.clamp(0, 1))!, paint);
    }
  }

  double _distance(Offset a, Offset b) =>
      math.sqrt(math.pow(b.dx - a.dx, 2) + math.pow(b.dy - a.dy, 2));

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.progress != progress;
}

// ─── Detail Row ───────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _DetailRow({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(icon, color: color ?? AppTheme.textHint, size: 16),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              '$label:',
              style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Verified Badge ───────────────────────────────────────────
class _VerifiedBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool verified;

  const _VerifiedBadge({required this.label, required this.icon, required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppTheme.success : AppTheme.textHint.withValues(alpha: 0.4);
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        Icon(
          verified ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: color,
          size: 11,
        ),
      ],
    );
  }
}
