// ============================================================
// SmartAttend — Login Screen (v12 Premium Light)
// Modern university ERP login with Poppins, white card,
// animated header wave, role selector, gradient button.
// All auth logic untouched.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../widgets/sa_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedRole = 'student';

  final AuthController _auth = Get.find();

  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final FocusNode _emailFocus    = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  final List<Map<String, dynamic>> _roles = [
    {'label': 'Student',  'value': 'student', 'icon': Icons.school_rounded,               'color': AppTheme.primary},
    {'label': 'Faculty',  'value': 'faculty', 'icon': Icons.person_rounded,               'color': AppTheme.secondary},
    {'label': 'Admin',    'value': 'admin',   'icon': Icons.admin_panel_settings_rounded,  'color': AppTheme.warning},
  ];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _auth.errorMessage.value = '';
    await _auth.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _selectedRole,
    );
    // Show error if login failed
    if (_auth.errorMessage.value.isNotEmpty) {
      Get.snackbar(
        'Login Failed',
        _auth.errorMessage.value,
        backgroundColor: AppTheme.error.withValues(alpha: 0.92),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // ── Purple header wave ──────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: size.height * 0.38,
                decoration: const BoxDecoration(
                  gradient: AppTheme.headerGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(48),
                    bottomRight: Radius.circular(48),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      // Logo icon
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.how_to_reg_rounded,
                            color: Colors.white, size: 34),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'SmartAttend',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI-Powered University Attendance',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Scrollable form ─────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: size.height * 0.32,
                  bottom: 24,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // ── White card ─────────────────────
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: AppTheme.elevatedShadow,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back! 👋',
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sign in to your account',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Role selector ──────────
                                  _RoleSelector(
                                    roles: _roles,
                                    selected: _selectedRole,
                                    onSelect: (v) =>
                                        setState(() => _selectedRole = v),
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Email ──────────────────
                                  _label('Email Address'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _emailController,
                                    focusNode: _emailFocus,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                                    validator: Validators.email,
                                    style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
                                    decoration: _inputDecoration(
                                      hint: 'you@university.edu',
                                      icon: Icons.email_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // ── Password ───────────────
                                  _label('Password'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocus,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    validator: Validators.loginPassword,
                                    style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
                                    decoration: _inputDecoration(
                                      hint: '••••••••',
                                      icon: Icons.lock_outline_rounded,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 20,
                                          color: AppTheme.textHint,
                                        ),
                                        onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // ── Forgot password ─────────
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => Get.toNamed(AppConstants.routeForgotPassword),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.primary,
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Sign In Button ──────────
                                  Obx(() => SAButton(
                                    label: 'Sign In',
                                    icon: Icons.login_rounded,
                                    isLoading: _auth.isLoading.value,
                                    onPressed: _submit,
                                  )),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Register link ───────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary),
                              ),
                              GestureDetector(
                                onTap: () => Get.toNamed(AppConstants.routeRegister),
                                child: Text(
                                  'Register',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.textHint, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.bgMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.error, width: 2),
        ),
        hintStyle:
            GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 14),
        errorStyle:
            GoogleFonts.poppins(color: AppTheme.error, fontSize: 11),
      );
}

Widget _label(String text) => Text(
  text,
  style: GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimary,
  ),
);

// ─── Role Selector ────────────────────────────────────────
class _RoleSelector extends StatelessWidget {
  final List<Map<String, dynamic>> roles;
  final String selected;
  final ValueChanged<String> onSelect;

  const _RoleSelector({
    required this.roles,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sign in as',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: roles.map((r) {
            final isSelected = r['value'] == selected;
            final color = r['color'] as Color;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(r['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                      right: r == roles.last ? 0 : 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.1)
                        : AppTheme.bgMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : AppTheme.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        r['icon'] as IconData,
                        color: isSelected ? color : AppTheme.textHint,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
