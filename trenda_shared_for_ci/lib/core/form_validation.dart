// trenda_shared/lib/core/form_validation.dart
// ============================================================================
// FORM VALIDATION - Enterprise-grade validation utilities
// ============================================================================

import 'dart:async';
import 'timezone.dart';

/// Result of a validation operation
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? fieldName;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.fieldName,
  });

  factory ValidationResult.valid() => const ValidationResult(isValid: true);

  factory ValidationResult.invalid(String message, [String? field]) =>
      ValidationResult(isValid: false, errorMessage: message, fieldName: field);
}

/// Validator function type
typedef ValidatorFn<T> = ValidationResult Function(T? value);

/// Async validator function type
typedef AsyncValidatorFn<T> = Future<ValidationResult> Function(T? value);

// ============================================================================
// PHONE NUMBER VALIDATION
// ============================================================================

/// Phone number validator with international support
class PhoneValidator {
  static const Map<String, PhoneFormat> _formats = {
    'PH': PhoneFormat(
      pattern: r'^(09|\+639)\d{9}$',
      minLength: 11,
      maxLength: 13,
      example: '09171234567',
    ),
    'US': PhoneFormat(
      pattern: r'^\+?1?\d{10}$',
      minLength: 10,
      maxLength: 12,
      example: '2025551234',
    ),
  };

  /// Validate phone number for a specific country
  static ValidationResult validate(String? phone, {String country = 'PH'}) {
    if (phone == null || phone.isEmpty) {
      return ValidationResult.invalid('Phone number is required');
    }

    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final format = _formats[country];

    if (format == null) {
      // Generic validation
      if (cleaned.length < 10) {
        return ValidationResult.invalid('Phone number is too short');
      }
      return ValidationResult.valid();
    }

    if (cleaned.length < format.minLength ||
        cleaned.length > format.maxLength) {
      return ValidationResult.invalid(
        'Phone number must be ${format.minLength}-${format.maxLength} digits',
      );
    }

    if (!RegExp(format.pattern).hasMatch(cleaned)) {
      return ValidationResult.invalid(
        'Invalid phone format. Example: ${format.example}',
      );
    }

    return ValidationResult.valid();
  }

  /// Format phone number to standard format
  static String format(String phone, {String country = 'PH'}) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (country == 'PH' && cleaned.startsWith('09')) {
      return '+63${cleaned.substring(1)}';
    }

    return cleaned;
  }
}

class PhoneFormat {
  final String pattern;
  final int minLength;
  final int maxLength;
  final String example;

  const PhoneFormat({
    required this.pattern,
    required this.minLength,
    required this.maxLength,
    required this.example,
  });
}

// ============================================================================
// ADDRESS VALIDATION
// ============================================================================

/// Address validator for Philippines
class AddressValidator {
  /// Validate a complete address
  static ValidationResult validateAddress({
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? postalCode,
  }) {
    final errors = <String>[];

    if (street == null || street.trim().length < 5) {
      errors.add('Street address must be at least 5 characters');
    }

    if (barangay == null || barangay.trim().isEmpty) {
      errors.add('Barangay is required');
    }

    if (city == null || city.trim().isEmpty) {
      errors.add('City/Municipality is required');
    }

    if (province == null || province.trim().isEmpty) {
      errors.add('Province is required');
    }

    if (postalCode != null && postalCode.isNotEmpty) {
      if (!RegExp(r'^\d{4}$').hasMatch(postalCode)) {
        errors.add('Postal code must be 4 digits');
      }
    }

    if (errors.isNotEmpty) {
      return ValidationResult.invalid(errors.join('. '));
    }

    return ValidationResult.valid();
  }

  /// Validate Philippine postal code
  static ValidationResult validatePostalCode(String? code) {
    if (code == null || code.isEmpty) {
      return ValidationResult.valid(); // Optional
    }

    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      return ValidationResult.invalid('Postal code must be 4 digits');
    }

    // Valid range for PH postal codes
    final codeNum = int.tryParse(code);
    if (codeNum == null || codeNum < 400 || codeNum > 9899) {
      return ValidationResult.invalid('Invalid postal code');
    }

    return ValidationResult.valid();
  }
}

// ============================================================================
// PAYMENT VALIDATION
// ============================================================================

/// Payment method validator
class PaymentValidator {
  /// Validate credit/debit card number using Luhn algorithm
  static ValidationResult validateCardNumber(String? number) {
    if (number == null || number.isEmpty) {
      return ValidationResult.invalid('Card number is required');
    }

    final cleaned = number.replaceAll(RegExp(r'\s'), '');

    if (cleaned.length < 13 || cleaned.length > 19) {
      return ValidationResult.invalid('Invalid card number length');
    }

    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return ValidationResult.invalid('Card number must contain only digits');
    }

    // Luhn algorithm
    int sum = 0;
    bool alternate = false;
    for (int i = cleaned.length - 1; i >= 0; i--) {
      int n = int.parse(cleaned[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }

    if (sum % 10 != 0) {
      return ValidationResult.invalid('Invalid card number');
    }

    return ValidationResult.valid();
  }

  /// Get card type from number
  static String? getCardType(String number) {
    final cleaned = number.replaceAll(RegExp(r'\s'), '');

    if (cleaned.startsWith('4')) return 'Visa';
    if (cleaned.startsWith('5') || cleaned.startsWith('2')) return 'Mastercard';
    if (cleaned.startsWith('3')) return 'Amex';
    if (cleaned.startsWith('6')) return 'Discover';

    return null;
  }

  /// Validate expiry date (MM/YY)
  static ValidationResult validateExpiry(String? expiry) {
    if (expiry == null || expiry.isEmpty) {
      return ValidationResult.invalid('Expiry date is required');
    }

    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(expiry);
    if (match == null) {
      return ValidationResult.invalid('Use MM/YY format');
    }

    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);

    if (month < 1 || month > 12) {
      return ValidationResult.invalid('Invalid month');
    }

    final now = DateTime.now();
    final expiryDate = DateTime(year, month + 1, 0); // Last day of month

    if (expiryDate.isBefore(now)) {
      return ValidationResult.invalid('Card has expired');
    }

    return ValidationResult.valid();
  }

  /// Validate CVV
  static ValidationResult validateCvv(String? cvv, {bool isAmex = false}) {
    if (cvv == null || cvv.isEmpty) {
      return ValidationResult.invalid('CVV is required');
    }

    final expectedLength = isAmex ? 4 : 3;
    if (cvv.length != expectedLength) {
      return ValidationResult.invalid('CVV must be $expectedLength digits');
    }

    if (!RegExp(r'^\d+$').hasMatch(cvv)) {
      return ValidationResult.invalid('CVV must contain only digits');
    }

    return ValidationResult.valid();
  }

  /// Validate GCash/Maya number (Philippines)
  static ValidationResult validateEwallet(String? number) {
    return PhoneValidator.validate(number, country: 'PH');
  }
}

// ============================================================================
// ORDER VALIDATION
// ============================================================================

/// Order data validator
class OrderValidator {
  /// Validate cart items
  static ValidationResult validateCartItems(List<dynamic>? items) {
    if (items == null || items.isEmpty) {
      return ValidationResult.invalid('Cart is empty');
    }

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      if (item['productId'] == null) {
        return ValidationResult.invalid('Product ID missing for item ${i + 1}');
      }

      final quantity = item['quantity'];
      if (quantity == null || quantity < 1) {
        return ValidationResult.invalid('Invalid quantity for item ${i + 1}');
      }

      if (quantity > 100) {
        return ValidationResult.invalid('Maximum quantity is 100 per item');
      }
    }

    return ValidationResult.valid();
  }

  /// Validate order amount
  static ValidationResult validateOrderAmount(
    double? amount, {
    double? minAmount,
    double? maxAmount,
  }) {
    if (amount == null || amount <= 0) {
      return ValidationResult.invalid('Invalid order amount');
    }

    if (minAmount != null && amount < minAmount) {
      return ValidationResult.invalid(
        'Minimum order amount is ₱${minAmount.toStringAsFixed(2)}',
      );
    }

    if (maxAmount != null && amount > maxAmount) {
      return ValidationResult.invalid(
        'Maximum order amount is ₱${maxAmount.toStringAsFixed(2)}',
      );
    }

    return ValidationResult.valid();
  }
}

// ============================================================================
// DATE/TIME VALIDATION
// ============================================================================

/// Date and time validators
class DateTimeValidator {
  /// Validate date is not in the past
  static ValidationResult validateFutureDate(DateTime? date) {
    if (date == null) {
      return ValidationResult.invalid('Date is required');
    }

    // [date] is a picked calendar day; "today" is the Philippine one.
    final today = TrendaTimezone.today();

    if (date.isBefore(today)) {
      return ValidationResult.invalid('Date cannot be in the past');
    }

    return ValidationResult.valid();
  }

  /// Validate date range
  static ValidationResult validateDateRange(
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null || endDate == null) {
      return ValidationResult.invalid('Both dates are required');
    }

    if (endDate.isBefore(startDate)) {
      return ValidationResult.invalid('End date must be after start date');
    }

    // Check maximum range (e.g., 30 days)
    final daysDifference = endDate.difference(startDate).inDays;
    if (daysDifference > 365) {
      return ValidationResult.invalid('Date range cannot exceed 1 year');
    }

    return ValidationResult.valid();
  }

  /// Validate business hours time
  static ValidationResult validateBusinessHours(
    DateTime time, {
    int openHour = 8,
    int closeHour = 22,
  }) {
    final hour = time.hour;

    if (hour < openHour || hour >= closeHour) {
      return ValidationResult.invalid(
        'Time must be between $openHour:00 and $closeHour:00',
      );
    }

    return ValidationResult.valid();
  }
}

// ============================================================================
// COMPOSITE VALIDATOR
// ============================================================================

/// Combine multiple validators
class CompositeValidator<T> {
  final List<ValidatorFn<T>> _validators = [];

  CompositeValidator<T> add(ValidatorFn<T> validator) {
    _validators.add(validator);
    return this;
  }

  ValidationResult validate(T? value) {
    for (final validator in _validators) {
      final result = validator(value);
      if (!result.isValid) {
        return result;
      }
    }
    return ValidationResult.valid();
  }

  /// For use with Flutter TextFormField
  String? call(T? value) {
    final result = validate(value);
    return result.isValid ? null : result.errorMessage;
  }
}

/// Create a validator chain
CompositeValidator<String> stringValidator() => CompositeValidator<String>();
