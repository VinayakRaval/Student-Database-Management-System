import 'package:flutter/material.dart';

class ValidationUtils {
  static const String mandatoryMessage = "This field is mandatory.";
  static final RegExp _phoneRegex = RegExp(r'^\d{10}$');
  static final RegExp _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  /// Checks if value is null or empty/whitespace only
  static String? mandatory(String? value, [String? customMessage]) {
    if (value == null || value.trim().isEmpty) {
      return customMessage ?? mandatoryMessage;
    }
    return null;
  }

  /// Checks if dropdown value is selected
  static String? mandatorySelect<T>(T? value, [String? fieldName]) {
    if (value == null) {
      return mandatoryMessage;
    }
    if (value is String && value.trim().isEmpty) {
      return mandatoryMessage;
    }
    return null;
  }

  /// Checks numeric input (greater than or equal to min, defaults to 0)
  static String? mandatoryNumber(String? value, {int min = 0, String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return mandatoryMessage;
    }
    final n = int.tryParse(value.trim());
    if (n == null) {
      return "Please enter a valid number.";
    }
    if (n < min) {
      return "Value must be greater than or equal to $min.";
    }
    return null;
  }

  /// Shows standard validation SnackBar summarizing mandatory errors
  static void showValidationErrorSnackBar(BuildContext context, [String? message]) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message ?? "Please fill all mandatory fields marked with an asterisk (*).",
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Normalizes a phone string by stripping non-digit characters.
  /// If it has an Indian country code prefix '+91' or '91' with 12 digits, trims to 10 digits.
  static String extractDigits(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    return digits;
  }

  /// Checks phone number: returns null if valid, or a descriptive error message if invalid.
  static String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return mandatoryMessage;
    }
    final digits = extractDigits(phone);
    if (digits.length < 10) {
      return "Phone number must be exactly 10 digits. You entered only ${digits.length} digits.";
    }
    if (digits.length > 10) {
      return "Phone number must be exactly 10 digits. You entered ${digits.length} digits.";
    }
    if (!_phoneRegex.hasMatch(digits)) {
      return "Phone number must contain only numeric digits.";
    }
    return null;
  }

  /// Checks email address: returns null if valid, or an error message if invalid.
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return mandatoryMessage;
    }
    final trimmed = email.trim();
    if (!_emailRegex.hasMatch(trimmed)) {
      return "Invalid email address format. Please enter a valid email address (e.g., example@domain.com).";
    }
    return null;
  }

  /// Shows a modal popup dialog when validation fails
  static Future<void> showValidationPopup(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (!context.mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14.5,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                "OK",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }
}
