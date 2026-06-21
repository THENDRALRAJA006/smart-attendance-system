// ============================================================
// SmartAttend — Student Registration Screen
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../widgets/gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _regNoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _selectedDept = 'Computer Science';
  int _selectedYear = 1;
  String _selectedSection = 'A';

  final AuthController _auth = Get.find();

  final List<String> _departments = [
    'Computer Science', 'Electronics', 'Mechanical',
    'Civil', 'Electrical', 'Information Technology',
  ];
  final List<String> _sections = ['A', 'B', 'C', 'D'];

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await _auth.registerStudent(
      name:         _nameCtrl.text.trim(),
      regNo:        _regNoCtrl.text.trim(),
      department:   _selectedDept,
      year:         _selectedYear,
      section:      _selectedSection,
      email:        _emailCtrl.text.trim(),
      password:     _passwordCtrl.text,
      phoneNumber:  _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
    );
    if (success) Get.offNamed(AppConstants.routeFaceRegister);
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) itemLabel,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: AppTheme.bgCard,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.bgCardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ─── AppBar ──────────────────────────────────
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: AppTheme.textPrimary, size: 20),
                        onPressed: () => Get.back(),
                      ),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: const Text(
                      'Fill in your details to register',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── Progress Steps ──────────────────────────
                  Row(
                    children: [
                      _stepDot(1, 'Details', true),
                      _stepLine(true),
                      _stepDot(2, 'Face ID', false),
                      _stepLine(false),
                      _stepDot(3, 'Done', false),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ─── Form Fields ─────────────────────────────
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    validator: Validators.name,
                  ),

                  const SizedBox(height: 14),

                  _buildField(
                    controller: _regNoCtrl,
                    label: 'Register Number',
                    icon: Icons.badge_outlined,
                    validator: Validators.registerNumber,
                  ),

                  const SizedBox(height: 14),

                  _buildDropdown<String>(
                    label: 'Department',
                    value: _selectedDept,
                    items: _departments,
                    onChanged: (v) => setState(() => _selectedDept = v!),
                    itemLabel: (v) => v,
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown<int>(
                          label: 'Year',
                          value: _selectedYear,
                          items: [1, 2, 3, 4],
                          onChanged: (v) => setState(() => _selectedYear = v!),
                          itemLabel: (v) => 'Year $v',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildDropdown<String>(
                          label: 'Section',
                          value: _selectedSection,
                          items: _sections,
                          onChanged: (v) => setState(() => _selectedSection = v!),
                          itemLabel: (v) => 'Section $v',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _buildField(
                    controller: _emailCtrl,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),

                  const SizedBox(height: 14),

                  _buildField(
                    controller: _phoneCtrl,
                    label: 'Phone Number (Optional)',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: null, // optional field
                  ),

                  const SizedBox(height: 14),

                  _buildField(
                    controller: _passwordCtrl,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textHint,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: Validators.password,
                  ),

                  const SizedBox(height: 14),

                  _buildField(
                    controller: _confirmPasswordCtrl,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textHint,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: Validators.confirmPassword(_passwordCtrl.text),
                  ),

                  const SizedBox(height: 8),

                  // ─── Error Message ────────────────────────────
                  Obx(() {
                    if (_auth.errorMessage.value.isEmpty) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _auth.errorMessage.value,
                        style: const TextStyle(color: AppTheme.error, fontSize: 13),
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  Obx(() => GradientButton(
                        text: 'Continue to Face ID',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: _auth.isLoading.value,
                        onPressed: _handleRegister,
                      )),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: const Text(
                          'Sign In',
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }

  Widget _stepDot(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.primaryGradient : null,
            color: isActive ? null : AppTheme.bgCardLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? Colors.transparent
                  : AppTheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.textHint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primary : AppTheme.textHint,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.only(bottom: 16),
        color: isActive
            ? AppTheme.primary.withValues(alpha: 0.5)
            : AppTheme.primary.withValues(alpha: 0.15),
      ),
    );
  }
}
