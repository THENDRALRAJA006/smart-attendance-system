// ============================================================
// SmartAttend — Reset Password Screen
// Step 2 of 2: Set new password after identity is verified
// POST /auth/reset-password → animated success → Login
// ============================================================

import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../widgets/gradient_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey        = GlobalKey<FormState>();
  final _passwordCtrl   = TextEditingController();
  final _confirmCtrl    = TextEditingController();

  final _passwordFocus  = FocusNode();
  final _confirmFocus   = FocusNode();

  bool    _obscurePassword = true;
  bool    _obscureConfirm  = true;
  bool    _isLoading       = false;
  bool    _isSuccess       = false;
  String? _errorMessage;

  // Roll number passed from forgot-password screen
  String  _rollNumber = '';

  late AnimationController _bgController;
  late AnimationController _entryController;
  late AnimationController _successController;
  late Animation<double>   _bgAnim;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;
  late Animation<double>   _successScale;
  late Animation<double>   _successFade;

  // Live password strength
  int _strengthScore = 0;

  @override
  void initState() {
    super.initState();

    // Read roll_number from navigation arguments
    final args = Get.arguments;
    if (args is Map && args['roll_number'] != null) {
      _rollNumber = args['roll_number'] as String;
    }

    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _successController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _bgAnim      = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
    _entryFade   = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _entrySlide  = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _successScale = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _successController, curve: Curves.elasticOut));
    _successFade  = CurvedAnimation(parent: _successController, curve: Curves.easeOut);

    _entryController.forward();
    _passwordCtrl.addListener(_updateStrength);
  }

  void _updateStrength() {
    final v = _passwordCtrl.text;
    int score = 0;
    if (v.length >= 8)                      score++;
    if (RegExp(r'[A-Z]').hasMatch(v))       score++;
    if (RegExp(r'[a-z]').hasMatch(v))       score++;
    if (RegExp(r'[0-9]').hasMatch(v))       score++;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(v)) score++;
    setState(() => _strengthScore = score);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _successController.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ─── Submit ────────────────────────────────────────────────
  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final api = ApiClient.to;
      await api.post(
        AppConstants.endpointResetPassword,
        data: {
          'roll_number':  _rollNumber,
          'new_password': _passwordCtrl.text,
        },
      );

      dev.log('[RESET_PW] Password reset for roll=$_rollNumber', name: 'ResetPassword');

      if (!mounted) return;
      setState(() => _isSuccess = true);
      _successController.forward();
      HapticFeedback.mediumImpact();
    } on DioException catch (e) {
      final detail = e.response?.data;
      String msg = 'Password reset failed. Please try again.';
      if (detail is Map) {
        final d = detail['detail'];
        if (d is Map) {
          msg = d['message'] as String? ?? msg;
        } else if (d is String) {
          msg = d;
        } else if (detail['message'] is String) {
          msg = detail['message'] as String;
        }
      }
      dev.log('[RESET_PW] Error: $msg', name: 'ResetPassword');
      setState(() => _errorMessage = msg);
      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Light theme background ────────────────────────
          Positioned.fill(
            child: Container(
              color: AppTheme.bgPage,
            ),
          ),

          // ── Purple glow top-right ─────────────────────────
          Positioned(
            top: -80, right: -60,
            child: AnimatedBuilder(
              animation: _bgAnim,
              builder: (_, __) => Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppTheme.primary.withValues(alpha: 0.08 + _bgAnim.value * 0.04),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.3, left: -70,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.accent.withValues(alpha: 0.05),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Main / Success switcher ───────────────────────
          SafeArea(
            child: _isSuccess ? _buildSuccess(size) : _buildForm(size),
          ),
        ],
      ),
    );
  }

  // ─── Form ──────────────────────────────────────────────────
  Widget _buildForm(Size size) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(28, size.height * 0.04, 28, 32),
      child: FadeTransition(
        opacity: _entryFade,
        child: SlideTransition(
          position: _entrySlide,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.border),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.textPrimary, size: 18),
                  ),
                ),

                SizedBox(height: size.height * 0.04),

                // Icon + Title
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.glowShadow(AppTheme.success,
                              intensity: 0.30, blur: 28),
                        ),
                        child: const Icon(Icons.lock_open_rounded,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Create New Password',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose a strong password to\nprotect your account',
                        style: TextStyle(
                            color: AppTheme.textHint, fontSize: 13, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: size.height * 0.04),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.15)),
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
                      // Step indicator
                      Row(
                        children: [
                          _StepDot(active: false, done: true, label: '✓'),
                          _StepLine(filled: true),
                          _StepDot(active: true, done: false, label: '2'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Step 2 of 2 — Set New Password',
                        style: TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),

                      const SizedBox(height: 22),

                      // New password field
                      _FpTextField(
                        controller:      _passwordCtrl,
                        focusNode:       _passwordFocus,
                        label:           'New Password',
                        hint:            '••••••••',
                        icon:            Icons.lock_rounded,
                        obscureText:     _obscurePassword,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_confirmFocus),
                        validator:       Validators.strongPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppTheme.textHint, size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Password strength bar
                      _StrengthBar(score: _strengthScore),

                      const SizedBox(height: 4),
                      _StrengthRules(password: _passwordCtrl.text),

                      const SizedBox(height: 18),

                      // Confirm password field
                      _FpTextField(
                        controller:      _confirmCtrl,
                        focusNode:       _confirmFocus,
                        label:           'Confirm Password',
                        hint:            '••••••••',
                        icon:            Icons.lock_outline_rounded,
                        obscureText:     _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onSubmitted:     (_) => _reset(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm your password';
                          if (v != _passwordCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppTheme.textHint, size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Error
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: AppTheme.errorCard(0.4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppTheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_errorMessage!,
                                    style: const TextStyle(
                                        color: AppTheme.error, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Reset button
                      GradientButton(
                        text: 'Reset Password',
                        icon: Icons.check_circle_rounded,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _reset,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Success ───────────────────────────────────────────────
  Widget _buildSuccess(Size size) {
    return FadeTransition(
      opacity: _successFade,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated success icon
              ScaleTransition(
                scale: _successScale,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: AppTheme.glowShadow(AppTheme.success,
                        intensity: 0.45, blur: 40),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 60),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Password Changed!',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              const Text(
                'Your password has been updated successfully.\nYou can now sign in with your new password.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Security info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: AppTheme.success, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'For security, all active sessions have been invalidated. Please sign in again.',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Go to login button
              GradientButton(
                text: 'Go to Login',
                icon: Icons.login_rounded,
                onPressed: () => Get.offAllNamed(AppConstants.routeLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Password strength bar ─────────────────────────────────────
class _StrengthBar extends StatelessWidget {
  final int score; // 0–5
  const _StrengthBar({required this.score});

  Color get _color {
    if (score <= 1) return AppTheme.error;
    if (score == 2) return AppTheme.warning;
    if (score == 3) return AppTheme.bioLiveness;
    return AppTheme.success;
  }

  String get _label {
    if (score <= 1) return 'Weak';
    if (score == 2) return 'Fair';
    if (score == 3) return 'Good';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    if (score == 0) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 5,
              minHeight: 4,
              backgroundColor: AppTheme.bgCardLight,
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _label,
          style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ─── Password rules checklist ──────────────────────────────────
class _StrengthRules extends StatelessWidget {
  final String password;
  const _StrengthRules({required this.password});

  @override
  Widget build(BuildContext context) {
    final rules = [
      _Rule('Minimum 8 characters',       password.length >= 8),
      _Rule('Uppercase letter (A-Z)',      RegExp(r'[A-Z]').hasMatch(password)),
      _Rule('Lowercase letter (a-z)',      RegExp(r'[a-z]').hasMatch(password)),
      _Rule('Number (0-9)',                RegExp(r'[0-9]').hasMatch(password)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rules.map((r) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(
              r.met ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 13,
              color: r.met ? AppTheme.success : AppTheme.textHint,
            ),
            const SizedBox(width: 6),
            Text(
              r.label,
              style: TextStyle(
                color: r.met ? AppTheme.success : AppTheme.textHint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

class _Rule {
  final String label;
  final bool   met;
  const _Rule(this.label, this.met);
}

// ─── Step indicator widgets ────────────────────────────────────
class _StepDot extends StatelessWidget {
  final bool   active;
  final bool   done;
  final String label;
  const _StepDot({required this.active, required this.done, required this.label});

  @override
  Widget build(BuildContext context) {
    Color? bg;
    Gradient? grad;
    Color textColor;
    Border? border;

    if (done) {
      grad      = const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00BFA5)]);
      textColor = Colors.white;
    } else if (active) {
      grad      = AppTheme.primaryGradient;
      textColor = Colors.white;
    } else {
      bg        = AppTheme.bgCardLight;
      textColor = AppTheme.textHint;
      border    = Border.all(color: AppTheme.textHint.withValues(alpha: 0.3));
    }

    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: grad,
        color: bg,
        border: border,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: done ? 13 : 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool filled;
  const _StepLine({this.filled = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: filled
                ? const LinearGradient(
                    colors: [Color(0xFF00E676), Color(0xFF7C5CFF)])
                : null,
            color: filled ? null : AppTheme.textHint.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
}

// ─── Reusable text field (same as forgot screen) ───────────────
class _FpTextField extends StatefulWidget {
  final TextEditingController      controller;
  final FocusNode?                 focusNode;
  final String                     label;
  final String                     hint;
  final IconData                   icon;
  final bool                       obscureText;
  final TextInputAction?           textInputAction;
  final Widget?                    suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)?     onSubmitted;

  const _FpTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.obscureText      = false,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  @override
  State<_FpTextField> createState() => _FpTextFieldState();
}

class _FpTextFieldState extends State<_FpTextField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(() {
      if (mounted) setState(() => _isFocused = widget.focusNode!.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isFocused ? AppTheme.subtleGlow(AppTheme.primary) : [],
          ),
          child: TextFormField(
            controller:       widget.controller,
            focusNode:        widget.focusNode,
            obscureText:      widget.obscureText,
            textInputAction:  widget.textInputAction,
            onFieldSubmitted: widget.onSubmitted,
            validator:        widget.validator,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                  color: AppTheme.textHint.withValues(alpha: 0.5), fontSize: 14),
              prefixIcon: Icon(widget.icon,
                  color: _isFocused ? AppTheme.primary : AppTheme.textHint, size: 20),
              suffixIcon: widget.suffixIcon,
              filled:    true,
              fillColor: AppTheme.bgCardLight.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: AppTheme.textHint.withValues(alpha: 0.15), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.error, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              errorStyle: const TextStyle(color: AppTheme.error, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}
