// lib/features/core/utils/validators.dart
/// Form validation utilities for the app
class Validators {
  /// Email validation
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Password validation
  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }

    return null;
  }

  /// Strong password validation
  static String? strongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  /// Phone number validation (Philippine format)
  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    // Remove all non-digit characters
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    // Philippine mobile numbers: 09XXXXXXXXX or 639XXXXXXXXX
    if (digitsOnly.startsWith('09') && digitsOnly.length == 11) {
      return null;
    }
    if (digitsOnly.startsWith('639') && digitsOnly.length == 12) {
      return null;
    }
    if (digitsOnly.startsWith('9') && digitsOnly.length == 10) {
      return null;
    }

    return 'Please enter a valid Philippine phone number';
  }

  /// Name validation
  static String? name(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return '$fieldName can only contain letters and spaces';
    }

    return null;
  }

  /// Address validation
  static String? address(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address is required';
    }

    if (value.trim().length < 10) {
      return 'Please enter a complete address';
    }

    return null;
  }

  /// Required field validation
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Minimum length validation
  static String? minLength(String? value, int min,
      {String fieldName = 'This field'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    if (value.length < min) {
      return '$fieldName must be at least $min characters';
    }

    return null;
  }

  /// Maximum length validation
  static String? maxLength(String? value, int max,
      {String fieldName = 'This field'}) {
    if (value != null && value.length > max) {
      return '$fieldName must be at most $max characters';
    }
    return null;
  }

  /// Numeric validation
  static String? numeric(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    if (double.tryParse(value.trim()) == null) {
      return '$fieldName must be a valid number';
    }

    return null;
  }

  /// Positive number validation
  static String? positiveNumber(String? value,
      {String fieldName = 'This field'}) {
    final numericError = numeric(value, fieldName: fieldName);
    if (numericError != null) return numericError;

    if (double.parse(value!) <= 0) {
      return '$fieldName must be greater than zero';
    }

    return null;
  }

  /// Price validation
  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Price is required';
    }

    final price = double.tryParse(value.trim());
    if (price == null) {
      return 'Please enter a valid price';
    }

    if (price < 0) {
      return 'Price cannot be negative';
    }

    // Check if price has more than 2 decimal places
    final parts = value.split('.');
    if (parts.length > 1 && parts[1].length > 2) {
      return 'Price can have at most 2 decimal places';
    }

    return null;
  }

  /// URL validation
  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'URL is required';
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value.trim())) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  /// Postal code validation
  static String? postalCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Postal code is required';
    }

    // Philippine postal codes are 4 digits
    if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
      return 'Please enter a valid 4-digit postal code';
    }

    return null;
  }

  /// Combine multiple validators
  static String? combine(
      List<String? Function(String?)> validators, String? value) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  }

  /// Match validation (e.g., for password confirmation)
  static String? Function(String?) match(String value, String fieldName) {
    return (String? confirmValue) {
      if (confirmValue == null || confirmValue.isEmpty) {
        return 'Please confirm your $fieldName';
      }

      if (confirmValue != value) {
        return '${fieldName}s do not match';
      }

      return null;
    };
  }
}

/// Extension for easy validation in TextFormField
extension ValidatorExtension on String? {
  String? get validateEmail => Validators.email(this);
  String? get validatePassword => Validators.password(this);
  String? get validateStrongPassword => Validators.strongPassword(this);
  String? get validatePhone => Validators.phoneNumber(this);
  String? get validateAddress => Validators.address(this);
  String? get validateRequired => Validators.required(this);
  String? get validatePrice => Validators.price(this);
}
