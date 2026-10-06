// lib/features/core/utils/auth_utils.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/application/notifier.dart';

/// ----------------------
/// FRIENDLY FIREBASE ERROR MAPPER
/// ----------------------
String mapFirebaseError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'network-request-failed':
        return "No internet connection. Please try again.";
      case 'user-disabled':
        return "This account has been disabled. Contact support.";
      case 'invalid-credential':
      case 'session-expired':
      case 'expired-action-code':
        return "Your credentials have expired. Please try again.";
      case 'credential-already-in-use':
        return "This credential is already linked to another account.";
      case 'invalid-verification-code':
        return "Invalid verification code entered.";
      case 'code-expired':
        return "OTP expired. Please request a new one.";
      case 'wrong-password':
        return "Incorrect password. Try again.";
      case 'requires-recent-login':
        return "Please reauthenticate before proceeding.";
      default:
        return e.message ?? "Authentication error occurred.";
    }
  }
  return "An unexpected error occurred.";
}

/// ----------------------
/// REAUTHENTICATION DIALOG
/// ----------------------
Future<Map<String, String>?> showReauthDialog(
    BuildContext context, String email) async {
  final emailController = TextEditingController(text: email);
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text("Reauthenticate"),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || v.isEmpty) ? "Enter your email" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
              validator: (v) =>
                  (v == null || v.isEmpty) ? "Enter your password" : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              "email": emailController.text.trim(),
              "password": passwordController.text.trim(),
            });
          },
          child: const Text("Continue"),
        ),
      ],
    ),
  );
}

/// ----------------------
/// SENSITIVE ACTION WRAPPER
/// ----------------------
/// Wrap any action that may require reauthentication.
Future<bool> performSensitiveAction(
  BuildContext context,
  Future<void> Function() action,
  AuthNotifier authNotifier,
  String? s, {
  String? userEmail, // <-- named parameter
}) async {
  try {
    if (userEmail == null || userEmail.isEmpty) {
      await action();
      return true;
    }

    final credentials = await showReauthDialog(context, userEmail);
    if (credentials == null) return false;

    final reauthSuccess = await authNotifier.reauthenticateUser(
      email: credentials["email"]!,
      password: credentials["password"]!,
    );

    if (!reauthSuccess) {
      showSnack(context, "Reauthentication failed");
      return false;
    }

    await action();
    return true;
  } catch (e) {
    showSnack(context, mapFirebaseError(e));
    return false;
  }
}

/// ----------------------
/// SHOW SNACKBAR HELPER
/// ----------------------
void showSnack(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
