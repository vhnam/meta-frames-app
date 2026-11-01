/// Form rules for the auth screens. They match the server's rules and the
/// dashboard's messages. Each returns an error message, or null when valid.
abstract final class AuthValidators {
  static const passwordHint =
      'At least 8 characters with upper and lower case, a digit and a symbol.';

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    if (email.length > 254) return 'Email is too long.';
    if (!_email.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  /// The password of an existing account. Older rules may have allowed it, so
  /// only its presence is checked.
  static String? currentPassword(String? value) =>
      value == null || value.isEmpty ? 'Password is required.' : null;

  static String? newPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required.';
    if (password.length < 8) return 'Use at least 8 characters.';
    if (password.length > 72) return 'Use at most 72 characters.';
    if (!password.contains(RegExp('[A-Z]'))) {
      return 'Add an upper-case letter.';
    }
    if (!password.contains(RegExp('[a-z]'))) {
      return 'Add a lower-case letter.';
    }
    if (!password.contains(RegExp(r'\d'))) return 'Add a digit.';
    if (!password.contains(RegExp('[^A-Za-z0-9]'))) return 'Add a symbol.';
    return null;
  }

  static String? name(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Full name is required.';
    if (name.length > 100) return 'Use at most 100 characters.';
    return null;
  }
}
