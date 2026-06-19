// ============================================================
// SmartAttend — Login Screen
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glassmorphism_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedRole = 'student';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final AuthController _auth = Get.find();

  final List<Map<String, dynamic>> _roles = [
    {'label': 'Student', 'value': 'student', 'icon': Icons.school_rounded},
    {'label': 'Faculty', 'value': 'faculty', 'icon': Icons.person_rounded},
    {'label': 'Admin', 'value': 'admin', 'icon': Icons.admin_panel_settings_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    _auth.login(_emailController.text.trim(), _passwordController.text, _selectedRole);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),

                  // ─── Header ──────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.fingerprint,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'SmartAttend',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppTheme.primaryGradient.createShader(bounds),
                    child: const Text(
                      'Welcome\nBack 👋',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to continue tracking attendance',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ─── Role Selector ────────────────────────────
                  Row(
                    children: _roles.map((role) {
                      final isSelected = _selectedRole == role['value'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = role['value']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: isSelected ? AppTheme.primaryGradient : null,
                              color: isSelected ? null : AppTheme.bgCardLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : AppTheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  role['icon'] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  size: 22,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  role['label'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // ─── Login Form ───────────────────────────────
                  GlassmorphismCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: AppTheme.primary,
                              ),
                            ),
                            validator: Validators.email,
                          ),

                          const SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: AppTheme.primary,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppTheme.textHint,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                v?.isEmpty ?? true ? 'Password is required' : null,
                          ),

                          const SizedBox(height: 8),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // ─── Error Message ──────────────────────
                          Obx(() {
                            if (_auth.errorMessage.value.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppTheme.error, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _auth.errorMessage.value,
                                      style: const TextStyle(
                                        color: AppTheme.error,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // ─── Login Button ───────────────────────
                          Obx(() => GradientButton(
                                text: 'Sign In',
                                isLoading: _auth.isLoading.value,
                                onPressed: _handleLogin,
                                icon: Icons.arrow_forward_rounded,
                              )),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── Register Link ────────────────────────────
                  if (_selectedRole == 'student')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Get.toNamed(AppConstants.routeRegister),
                          child: const Text(
                            'Register',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
