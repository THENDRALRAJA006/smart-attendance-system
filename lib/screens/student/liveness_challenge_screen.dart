// ============================================================
// SmartAttend — Liveness Challenge Screen (Enterprise v1)
// Mandatory step between QR and Face Verification
//
// Flow:
//   1. App requests challenge from backend (BLINK/SMILE/TURN_LEFT/TURN_RIGHT)
//   2. User performs challenge within 12 seconds
//   3. Camera captures challenge frame
//   4. Backend verifies → if pass → navigate to Face Verification
//   5. Max 3 attempts, then show failure UI
// ============================================================

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/services/camera_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/biometric_progress_bar.dart';
import '../../widgets/gradient_button.dart';
import 'package:dio/dio.dart' as dio;

// ─── Challenge Metadata ───────────────────────────────────────
// Updated for Enterprise v2: 9 challenge types
class _ChallengeData {
  final String type;
  final String instruction;
  final String emoji;
  final IconData icon;

  const _ChallengeData({
    required this.type,
    required this.instruction,
    required this.emoji,
    required this.icon,
  });
}

const Map<String, _ChallengeData> _challengeMeta = {
  'BLINK': _ChallengeData(
    type: 'BLINK',
    instruction: 'Blink once slowly',
    emoji: '😉',
    icon: Icons.remove_red_eye_rounded,
  ),
  'SMILE': _ChallengeData(
    type: 'SMILE',
    instruction: 'Smile naturally',
    emoji: '😊',
    icon: Icons.sentiment_satisfied_rounded,
  ),
  'TURN_LEFT': _ChallengeData(
    type: 'TURN_LEFT',
    instruction: 'Turn your head to the LEFT',
    emoji: '⬅️',
    icon: Icons.arrow_back_rounded,
  ),
  'TURN_RIGHT': _ChallengeData(
    type: 'TURN_RIGHT',
    instruction: 'Turn your head to the RIGHT',
    emoji: '➡️',
    icon: Icons.arrow_forward_rounded,
  ),
  'LOOK_UP': _ChallengeData(
    type: 'LOOK_UP',
    instruction: 'Look UP slightly',
    emoji: '⬆️',
    icon: Icons.keyboard_arrow_up_rounded,
  ),
  'LOOK_DOWN': _ChallengeData(
    type: 'LOOK_DOWN',
    instruction: 'Look DOWN slightly',
    emoji: '⬇️',
    icon: Icons.keyboard_arrow_down_rounded,
  ),
  'BLINK_TWICE': _ChallengeData(
    type: 'BLINK_TWICE',
    instruction: 'Blink twice slowly',
    emoji: '👁️',
    icon: Icons.visibility_rounded,
  ),
  'NOD': _ChallengeData(
    type: 'NOD',
    instruction: 'Nod your head once (up + down)',
    emoji: '🙇',
    icon: Icons.swap_vert_rounded,
  ),
  'KEEP_STEADY': _ChallengeData(
    type: 'KEEP_STEADY',
    instruction: 'Look straight at the camera — hold still',
    emoji: '🎯',
    icon: Icons.center_focus_strong_rounded,
  ),
};

class LivenessChallengeScreen extends StatefulWidget {
  const LivenessChallengeScreen({super.key});

  @override
  State<LivenessChallengeScreen> createState() => _LivenessChallengeScreenState();
}

class _LivenessChallengeScreenState extends State<LivenessChallengeScreen>
    with TickerProviderStateMixin {
  final AttendanceController _attendance = Get.find();
  final AuthController _auth = Get.find();
  final ApiClient _api = ApiClient.to;

  CameraController? _cameraCtrl;
  late AnimationController _entryController;
  late AnimationController _timerController;
  late AnimationController _pulseController;
  late AnimationController _emojiController;

  late Animation<double> _entryFade;
  late Animation<double> _timerAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _emojiScale;

  String? _challengeType;
  String? _challengeToken;
  _ChallengeData? _challenge;

  int _attemptsLeft = AppConstants.maxLivenessAttempts;
  bool _isLoading = false;
  bool _isCapturing = false;
  String? _error;
  bool _passed = false;

  Timer? _captureTimer;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _timerController = AnimationController(vsync: this, duration: Duration(seconds: AppConstants.livenessTimeoutSec))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onTimeout();
      });
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _emojiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _entryFade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _timerAnim = CurvedAnimation(parent: _timerController, curve: Curves.linear);
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _emojiScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _emojiController, curve: Curves.elasticOut));

    _entryController.forward();
    _initCamera();
    _fetchChallenge();
  }

  // ─── Camera Setup ─────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final service = Get.find<CameraService>();
      await service.initialize();
      _cameraCtrl = service.controller;
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _error = 'Camera unavailable: $e');
    }
  }

  // ─── Fetch Challenge from Backend ─────────────────────────
  Future<void> _fetchChallenge() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      // GET endpoint — student identity from JWT token, not body
      final response = await _api.get('/auth/liveness-challenge');

      final data = response.data as Map<String, dynamic>;
      final type  = data['challenge_type'] as String;
      final token = data['token'] as String;

      _challengeToken = token;
      _challengeType  = type;
      _challenge = _challengeMeta[type] ?? _ChallengeData(
        type: type,
        instruction: data['instruction'] as String? ?? 'Perform the challenge',
        emoji: '🎯',
        icon: Icons.face_rounded,
      );

      _emojiController.forward(from: 0);
      _timerController.forward(from: 0);

      // Auto-capture after 6s — gives user enough time to perform the challenge
      // (was 3s which was too fast — user hadn't finished the action yet)
      _captureTimer = Timer(const Duration(seconds: 6), _captureAndVerify);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Could not load liveness challenge: $e';
      });
    }
  }

  // ─── Timeout Handler ──────────────────────────────────────
  void _onTimeout() {
    if (_isCapturing || _passed) return;
    _captureAndVerify();
  }

  // ─── Capture & Verify ─────────────────────────────────────
  Future<void> _captureAndVerify() async {
    if (_isCapturing || _passed) return;
    _captureTimer?.cancel();
    _timerController.stop();

    setState(() { _isCapturing = true; _error = null; });
    HapticFeedback.mediumImpact();

    try {
      if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) {
        throw Exception('Camera not ready');
      }

      final xfile = await _cameraCtrl!.takePicture();
      final imageFile = File(xfile.path);
      final studentId = _auth.currentStudent.value?.id;

      if (studentId == null) throw Exception('Student not logged in');

      // Backend expects 'files' as a list (List[UploadFile])
      final multipart = await dio.MultipartFile.fromFile(imageFile.path, filename: 'liveness.jpg');
      final formData = dio.FormData();
      formData.files.add(MapEntry('files', multipart));
      formData.fields.add(MapEntry('challenge_token', _challengeToken ?? ''));

      final response = await _api.postMultipart('/auth/liveness-verify', formData);
      final data = response.data as Map<String, dynamic>;

      // Backend returns {passed, challenge_type, frames_analyzed, message, details}
      if (data['passed'] == true) {
        _onPassed(_challengeToken ?? '');
      } else {
        _onFailed(data['message'] as String? ?? 'Liveness check failed. Please try again.');
      }
    } catch (e) {
      _onFailed('Verification error: $e');
    }
  }

  void _onPassed(String token) {
    setState(() { _passed = true; _isCapturing = false; });
    HapticFeedback.heavyImpact();
    _attendance.markLivenessVerified(token: token);

    // Safety guard: liveness is ONLY used in face verification flow.
    // QR flow should NEVER reach this screen, but if it does, go back.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_attendance.verificationMethod.value == VerificationMethod.face) {
        Get.toNamed(AppConstants.routeAttendanceVerification);
      } else {
        // Should never happen — QR path bypasses liveness
        dev.log('[LIVENESS] ⚠️ Non-face method reached liveness! Going back.', name: 'Liveness');
        Get.back();
      }
    });
  }

  void _onFailed(String message) {
    _attemptsLeft--;
    setState(() {
      _isCapturing = false;
      _error = message;
    });
    HapticFeedback.heavyImpact();

    if (_attemptsLeft <= 0) {
      _showBlockedDialog();
    } else {
      // Auto-retry with a new challenge after 2 seconds — no user tap required
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _attemptsLeft > 0) _retryChallenge();
      });
    }
  }

  void _retryChallenge() {
    if (_attemptsLeft <= 0) return;
    _timerController.reset();
    _fetchChallenge();
  }

  void _showBlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block, color: AppTheme.error),
            SizedBox(width: 10),
            Text('Liveness Failed', style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: const Text(
          'You have exceeded the maximum number of liveness attempts. '
          'Please contact your faculty for manual attendance.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () { Get.back(); Get.back(); },
            child: const Text('Go Back', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _entryController.dispose();
    _timerController.dispose();
    _pulseController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _entryFade,
            child: Column(
              children: [
                _buildHeader(),
                _buildProgressBar(),
                const SizedBox(height: 12),
                if (_isLoading) const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
                else if (_passed) Expanded(child: _buildPassedState())
                else Expanded(child: _buildChallengeBody()),
                if (!_isLoading && !_passed) _buildFooter(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 24, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
            onPressed: () => Get.back(),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Liveness Check', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                Text('Prove you are physically present', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
              ],
            ),
          ),
          // Attempts badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: AppTheme.statusBadge(_attemptsLeft > 1 ? AppTheme.bioLiveness : AppTheme.error),
            child: Text(
              '$_attemptsLeft left',
              style: TextStyle(
                color: _attemptsLeft > 1 ? AppTheme.bioLiveness : AppTheme.error,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Obx(() => BiometricProgressBar(
            // Liveness is always in the face flow
            flowMode: AttendanceFlowMode.face,
            currentStep: _passed ? BiometricStep.face : BiometricStep.liveness,
            bleVerified: _attendance.bleVerified.value,
            livenessVerified: _passed,
          )),
    );
  }

  Widget _buildChallengeBody() {
    final screenW = MediaQuery.of(context).size.width;
    final cameraSize = screenW * 0.72; // 72% width — large and centered

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          // ── BLE verified badge ─────────────────────────
          Obx(() => _attendance.bleVerified.value
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bluetooth_connected_rounded, color: AppTheme.success, size: 14),
                      SizedBox(width: 6),
                      Text('BLE Verified ✓', style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : const SizedBox.shrink()),

          const SizedBox(height: 14),

          // ── Countdown ring ─────────────────────────────
          AnimatedBuilder(
            animation: _timerAnim,
            builder: (context, child) {
              final remaining = ((1.0 - _timerAnim.value) * AppConstants.livenessTimeoutSec).ceil();
              final timerColor = _timerAnim.value > 0.7 ? AppTheme.error : AppTheme.bioLiveness;

              return SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: 1.0 - _timerAnim.value,
                        strokeWidth: 5,
                        backgroundColor: AppTheme.bgCardLight,
                        valueColor: AlwaysStoppedAnimation(timerColor),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$remaining',
                          style: TextStyle(color: timerColor, fontWeight: FontWeight.w800, fontSize: 26),
                        ),
                        const Text('sec', style: TextStyle(color: AppTheme.textHint, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // ── LARGE camera preview — centered, 72% width ─
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: cameraSize,
              height: cameraSize,
              color: AppTheme.bgCard,
              child: _cameraCtrl != null && _cameraCtrl!.value.isInitialized
                  ? CameraPreview(_cameraCtrl!)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_front_rounded, color: AppTheme.textHint, size: 64),
                        const SizedBox(height: 8),
                        Text(
                          _error != null && _error!.contains('Camera') ? _error! : 'Initializing camera...',
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Challenge emoji + instruction (BELOW camera) ─
          ScaleTransition(
            scale: _emojiScale,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, _) => Transform.scale(
                scale: _challenge != null ? _pulseAnim.value : 1.0,
                child: Text(
                  _challenge?.emoji ?? '🎯',
                  style: const TextStyle(fontSize: 56),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Challenge instruction
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _challenge?.instruction ?? 'Getting challenge...',
              key: ValueKey(_challengeType),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 6),
          const Text(
            'Perform this action while looking at the camera',
            style: TextStyle(color: AppTheme.textHint, fontSize: 12),
            textAlign: TextAlign.center,
          ),

          // Error message
          if (_error != null && !_error!.contains('Camera')) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.errorCard(0.4),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPassedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.success, width: 2),
            boxShadow: AppTheme.glowShadow(AppTheme.success),
          ),
          child: const Icon(Icons.verified_user_rounded, color: AppTheme.success, size: 54),
        ),
        const SizedBox(height: 24),
        const Text('Liveness Verified!', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 24)),
        const SizedBox(height: 8),
        const Text('Proceeding to face recognition...', style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
        const SizedBox(height: 24),
        const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: AppTheme.success, strokeWidth: 2.5)),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          if (_isCapturing)
            const LinearProgressIndicator(color: AppTheme.bioLiveness)
          else
            GradientButton(
              text: _error != null ? 'Retry Challenge ($_attemptsLeft left)' : 'Capture Now',
              icon: _error != null ? Icons.refresh_rounded : Icons.camera_rounded,
              onPressed: _error != null ? _retryChallenge : _captureAndVerify,
              isLoading: _isCapturing,
            ),
          if (_error != null && _attemptsLeft > 0) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _retryChallenge,
              icon: const Icon(Icons.shuffle_rounded, size: 16, color: AppTheme.textHint),
              label: const Text('Get New Challenge', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}
