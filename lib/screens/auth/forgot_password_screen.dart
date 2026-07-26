// ============================================================
// SmartAttend — Forgot Password Screen
// Step 1 of 2: Verify identity via Roll Number + Mobile Number
// POST /auth/forgot-password → navigate to reset-password
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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey    = GlobalKey<FormState>();
  final _rollCtrl   = TextEditingController();
  final _mobileCtrl = TextEditingController();

  final _rollFocus   = FocusNode();
  final _mobileFocus = FocusNode();

  bool    _isLoading    = false;
  String? _errorMessage;

  late AnimationController _bgController;
  late AnimationController _entryController;
  late Animation<double>   _bgAnim;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _bgAnim     = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
    _entryFade  = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    _entryController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _rollCtrl.dispose();
    _mobileCtrl.dispose();
    _rollFocus.dispose();
    _mobileFocus.dispose();
    super.dispose();
  }

  // ─── Submit ────────────────────────────────────────────────
  Future<void> _verify() async {
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
        AppConstants.endpointForgotPassword,
        data: {
          'roll_number':   _rollCtrl.text.trim(),
          'mobile_number': _mobileCtrl.text.trim().replaceAll(' ', ''),
        },
      );

      dev.log('[FORGOT_PW] Identity verified for ${_rollCtrl.text.trim()}',
          name: 'ForgotPassword');

      if (!mounted) return;
      Get.toNamed(
        AppConstants.routeResetPassword,
        arguments: {'roll_number': _rollCtrl.text.trim()},
      );
    } on DioException catch (e) {
      final detail = e.response?.data;
      String msg = 'Verification failed. Please try again.';
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
      dev.log('[FORGOT_PW] Error: $msg', name: 'ForgotPassword');
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
          // ── Light theme background ─────────────────────────
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

          // ── Accent glow bottom-left ───────────────────────
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

          // ── Main content ──────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
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
                              color: AppTheme.bgCard.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.textHint.withValues(alpha: 0.2)),
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
                                    colors: [Color(0xFF9B7FFF), Color(0xFF5A3FCC)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: AppTheme.glowShadow(AppTheme.primary,
                                      intensity: 0.35, blur: 28),
                                ),
                                child: const Icon(Icons.lock_reset_rounded,
                                    color: Colors.white, size: 40),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Forgot Password',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Enter your roll number and registered\nmobile number to verify your identity',
                                style: TextStyle(
                                    color: AppTheme.textHint, fontSize: 13, height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: size.height * 0.045),

                  // Form Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: AppTheme.border),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step indicator
                              Row(
                                children: [
                                  _StepDot(active: true, label: '1'),
                                  _StepLine(),
                                  _StepDot(active: false, label: '2'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Step 1 of 2 — Verify Identity',
                                style: TextStyle(
                                    color: AppTheme.textHint,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                              ),

                              const SizedBox(height: 22),

                              // Roll Number
                              _FpTextField(
                                controller:      _rollCtrl,
                                focusNode:       _rollFocus,
                                label:           'Roll Number',
                                hint:            'e.g. 2117240030177',
                                icon:            Icons.badge_rounded,
                                keyboardType:    TextInputType.text,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) =>
                                    FocusScope.of(context).requestFocus(_mobileFocus),
                                validator: Validators.rollNumber,
                              ),

                              const SizedBox(height: 18),

                              // Mobile Number
                              _FpTextField(
                                controller:      _mobileCtrl,
                                focusNode:       _mobileFocus,
                                label:           'Registered Mobile Number',
                                hint:            '10-digit number',
                                icon:            Icons.phone_rounded,
                                keyboardType:    TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                onSubmitted:     (_) => _verify(),
                                validator:       Validators.mobileNumber,
                                maxLength:       10,
                              ),

                              const SizedBox(height: 10),

                              // Hint
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      color: AppTheme.textHint.withValues(alpha: 0.5),
                                      size: 13),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'Enter the mobile number you registered with',
                                      style: TextStyle(
                                          color: AppTheme.textHint,
                                          fontSize: 11,
                                          height: 1.4),
                                    ),
                                  ),
                                ],
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

                              // Continue button
                              GradientButton(
                                text: 'Continue',
                                icon: Icons.arrow_forward_rounded,
                                isLoading: _isLoading,
                                onPressed: _isLoading ? null : _verify,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Back to login
                        Center(
                          child: GestureDetector(
                            onTap: () => Get.offNamed(AppConstants.routeLogin),
                            child: RichText(
                              text: const TextSpan(
                                text: 'Remember your password? ',
                                style: TextStyle(color: AppTheme.textHint, fontSize: 13),
                                children: [
                                  TextSpan(
                                    text: 'Sign In',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step indicator widgets ────────────────────────────────────
class _StepDot extends StatelessWidget {
  final bool   active;
  final String label;
  const _StepDot({required this.active, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: active ? AppTheme.primaryGradient : null,
          color:    active ? null : AppTheme.bgCardLight,
          border:   active ? null : Border.all(color: AppTheme.textHint.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppTheme.textHint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

class _StepLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppTheme.textHint.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
}

// ─── Reusable text field for forgot/reset screens ──────────────
class _FpTextField extends StatefulWidget {
  final TextEditingController      controller;
  final FocusNode?                 focusNode;
  final String                     label;
  final String                     hint;
  final IconData                   icon;
  final TextInputType?             keyboardType;
  final TextInputAction?           textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)?     onSubmitted;
  final int?                       maxLength;

  const _FpTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.maxLength,
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
            keyboardType:     widget.keyboardType,
            textInputAction:  widget.textInputAction,
            onFieldSubmitted: widget.onSubmitted,
            validator:        widget.validator,
            maxLength:        widget.maxLength,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            buildCounter: widget.maxLength != null
                ? (_, {required currentLength, required isFocused, maxLength}) =>
                    const SizedBox.shrink()
                : null,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: AppTheme.textHint.withValues(alpha: 0.5), fontSize: 14),
              prefixIcon: Icon(widget.icon,
                  color: _isFocused ? AppTheme.primary : AppTheme.textHint, size: 20),
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
