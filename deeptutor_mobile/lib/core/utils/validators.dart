/// Form-field validator helpers following Flutter's validator signature.
abstract final class Validators {
  static String? required(String? v, {String? label}) {
    if (v == null || v.trim().isEmpty) {
      return '${label ?? 'This field'} is required';
    }
    return null;
  }

  static String? minLength(String? v, int min, {String? label}) {
    if (v != null && v.trim().length < min) {
      return '${label ?? 'This field'} must be at least $min characters';
    }
    return null;
  }

  static String? maxLength(String? v, int max, {String? label}) {
    if (v != null && v.trim().length > max) {
      return '${label ?? 'This field'} must be at most $max characters';
    }
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? Function(String?) combine(List<String? Function(String?)> fns) {
    return (v) {
      for (final fn in fns) {
        final result = fn(v);
        if (result != null) return result;
      }
      return null;
    };
  }
}
