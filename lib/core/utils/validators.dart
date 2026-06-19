// ============================================================
// SmartAttend — Form Validators
// ============================================================

class Validators {
  /// Email validation
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  /// Password validation (min 8 chars, 1 upper, 1 digit)
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must contain an uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Must contain a number';
    return null;
  }

  /// Confirm password
  static String? Function(String?) confirmPassword(String original) {
    return (String? value) {
      if (value == null || value.isEmpty) return 'Please confirm your password';
      if (value != original) return 'Passwords do not match';
      return null;
    };
  }

  /// Required field
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  /// Register number (alphanumeric, 8-15 chars)
  static String? registerNumber(String? value) {
    if (value == null || value.isEmpty) return 'Register number is required';
    if (value.length < 6 || value.length > 15) {
      return 'Register number must be 6–15 characters';
    }
    return null;
  }

  /// Name (letters and spaces only)
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Name must contain only letters';
    }
    return null;
  }

  /// 6-digit attendance code
  static String? attendanceCode(String? value) {
    if (value == null || value.isEmpty) return 'Code is required';
    if (value.length != 6) return 'Code must be exactly 6 digits';
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'Code must be numeric';
    return null;
  }
}
