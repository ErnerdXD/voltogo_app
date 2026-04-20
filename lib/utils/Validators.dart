class Validators {
  /// Checks if a password meets standard security requirements:
  /// - Minimum 8 characters
  /// - At least 1 uppercase letter
  /// - At least 1 lowercase letter
  /// - At least 1 number
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  static const String passwordRequirements =
      'Password must be at least 8 characters long and include an uppercase letter, a lowercase letter, and a number.';
}