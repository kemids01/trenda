// lib/features/home/presentation/password_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trenda_frontend/features/auth/application/notifier.dart';
import 'package:trenda_frontend/features/core/utils/auth_utils.dart';
import '../../auth/data/providers.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class PasswordPage extends ConsumerStatefulWidget {
  final User user;
  final bool isLinking;

  const PasswordPage({
    super.key,
    required this.user,
    required this.isLinking,
  });

  @override
  ConsumerState<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends ConsumerState<PasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  String _passwordStrength = "";
  double _strengthPercent = 0.0;
  Color _strengthColor = Colors.red;

  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _newPassController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _newPassController.removeListener(_checkPasswordStrength);
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _safeShowSnack(String msg) {
    if (mounted) showSnack(context, msg);
  }

  void _checkPasswordStrength() {
    final password = _newPassController.text;
    int score = 0;

    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    final percent = (score / 5).clamp(0.0, 1.0);

    Color color;
    if (percent <= 0.4)
      color = Colors.red;
    else if (percent <= 0.6)
      color = Colors.orange;
    else if (percent <= 0.8)
      color = Colors.yellow[700] ?? Colors.yellow;
    else
      color = Colors.green;

    setState(() {
      _strengthPercent = percent;
      _strengthColor = color;

      if (score <= 2)
        _passwordStrength = "Weak";
      else if (score <= 4)
        _passwordStrength = "Medium";
      else
        _passwordStrength = "Strong";
    });
  }

  String? _validatePassword(String? password) {
    if (password == null || password.isEmpty) return "Enter password";

    final regex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$');

    if (!regex.hasMatch(password)) {
      return "Must be 8+ chars, include uppercase, number & symbol";
    }

    return null;
  }

  Future<void> _linkOrUpdatePassword(AuthNotifier authNotifier) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final newPass = _newPassController.text.trim();

    try {
      if (widget.isLinking) {
        final alreadyLinked =
            widget.user.providerData.any((p) => p.providerId == 'password');
        if (alreadyLinked) {
          _safeShowSnack("Password already linked to this account ❌");
          return;
        }

        if (widget.user.email == null) {
          _safeShowSnack("User email is missing ❌");
          return;
        }

        await authNotifier.linkWithPassword(widget.user.email!, newPass);
        _safeShowSnack("Password linked successfully ✅");
      } else {
        if (widget.user.email == null) {
          _safeShowSnack("User email is missing ❌");
          return;
        }

        await performSensitiveAction(
          context,
          () async {
            await widget.user.updatePassword(newPass);
            _safeShowSnack("Password updated successfully ✅");
          },
          authNotifier,
          widget.user.email,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _safeShowSnack(mapFirebaseError(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPasswordHelperText() {
    final password = _newPassController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final req in [
          ["At least 8 characters", password.length >= 8],
          ["Include uppercase letter", RegExp(r'[A-Z]').hasMatch(password)],
          ["Include lowercase letter", RegExp(r'[a-z]').hasMatch(password)],
          ["Include number", RegExp(r'\d').hasMatch(password)],
          [
            "Include symbol (!@#\$%^&* etc.)",
            RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)
          ],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              children: [
                Icon(
                  req[1] as bool
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: req[1] as bool ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    req[0] as String,
                    style: TextStyle(
                        fontSize: 14,
                        color: req[1] as bool ? Colors.green : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(widget.isLinking ? "Link Password" : "Change Password"),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // New Password
                  TextFormField(
                    controller: _newPassController,
                    obscureText: _obscureNew,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: "New Password",
                      labelStyle: const TextStyle(fontSize: 16),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 12),

                  // Strength indicator pill (no pulse)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _strengthColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _strengthColor.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      _passwordStrength,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _strengthColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Password helper text
                  _buildPasswordHelperText(),
                  const SizedBox(height: 14),

                  // Strength bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 14,
                              width: constraints.maxWidth,
                              color: Colors.grey[300],
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              height: 14,
                              width: constraints.maxWidth * _strengthPercent,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _strengthColor.withValues(alpha: 0.8),
                                    _strengthColor
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  "${(_strengthPercent * 100).toInt()}%",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm Password
                  TextFormField(
                    controller: _confirmPassController,
                    obscureText: _obscureConfirm,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      labelStyle: const TextStyle(fontSize: 16),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) => v != _newPassController.text
                        ? "Passwords do not match"
                        : null,
                  ),
                  const SizedBox(height: 28),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 18),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => TapGuard.run('password.linkOrUpdatePassword', () async {
                                if (!_formKey.currentState!.validate()) return;
                                final authNotifier =
                                    ref.read(authNotifierProvider.notifier);
                                await _linkOrUpdatePassword(authNotifier);
                              }),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isLinking ? "Link" : "Update",
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Loading overlay with blur
        if (_isLoading)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
