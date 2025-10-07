// lib/utils/validators.dart

/// Validates that password meets security requirements:
/// - At least 6 characters
/// - At least 1 uppercase letter
/// - At least 1 digit
/// - At least 1 special character
bool isValidPassword(String password) {
  if (password.length < 6) return false;

  final hasUppercase = password.contains(RegExp(r'[A-Z]'));
  final hasDigit = password.contains(RegExp(r'\d'));
  final hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  return hasUppercase && hasDigit && hasSpecialChar;
}