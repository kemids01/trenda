//lib/features/core/widgets/otp_form_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_frontend/features/auth/application/state.dart';
import 'package:trenda_frontend/features/auth/data/providers.dart';
import 'package:trenda_frontend/features/core/utils/auth_utils.dart';
import '../../core/widgets/auth_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class OtpFormWidget extends ConsumerStatefulWidget {
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool linkModeDefault;
  final int otpCountdownSeconds;
  final bool showLinkCheckbox;
  final bool isLinking;
  final User user;
  final VoidCallback? onVerified;
  final void Function(Object error)? onError;

  const OtpFormWidget({
    super.key,
    required this.phoneController,
    required this.codeController,
    required this.user,
    required this.isLinking,
    this.linkModeDefault = false,
    this.otpCountdownSeconds = 60,
    this.showLinkCheckbox = true,
    this.onVerified,
    this.onError,
  });

  @override
  ConsumerState<OtpFormWidget> createState() => _OtpFormWidgetState();
}

class _OtpFormWidgetState extends ConsumerState<OtpFormWidget> {
  late bool _linkMode;
  String? _phoneError;
  Timer? _resendTimer;
  int _countdown = 0;
  late final FocusNode _codeFocusNode;
  late final FocusNode _phoneFocusNode;

  @override
  void initState() {
    super.initState();
    _linkMode = widget.linkModeDefault;
    _codeFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeFocusNode.dispose();
    _phoneFocusNode.dispose();
    widget.phoneController.dispose();
    widget.codeController.dispose();
    super.dispose();
  }

  // ---------------- PHONE VALIDATION ----------------
  bool _validatePhone(String phone) {
    final regex = RegExp(r'^\+63\d{10}$');
    final isValid = regex.hasMatch(phone);
    setState(() =>
        _phoneError = isValid ? null : 'Invalid format. Use +63XXXXXXXXXX');
    return isValid;
  }

  // ---------------- MAP FIREBASE ERRORS ----------------
  String _mapFirebaseError(Object e, [String fallback = "Operation failed ❌"]) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'credential-already-in-use':
          return "Phone already linked to another account.";
        case 'invalid-verification-code':
          return "Invalid SMS code.";
        case 'session-expired':
          return "Session expired. Please resend the code.";
        case 'code-expired':
          return "OTP has expired. Request a new one.";
        case 'network-request-failed':
          return "No internet connection. Please try again.";
        case 'user-disabled':
          return "This account has been disabled. Contact support.";
        case 'invalid-phone-number':
          return "Invalid phone number format.";
        default:
          return e.message ?? fallback;
      }
    }
    return fallback;
  }

  // ---------------- COUNTDOWN ----------------
  void _startCountdown() {
    setState(() => _countdown = widget.otpCountdownSeconds);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  // ---------------- SEND OTP ----------------
  Future<void> _sendOtp() async {
    final phone = widget.phoneController.text.trim();
    if (phone.isEmpty || !_validatePhone(phone)) return;

    if (widget.isLinking &&
        widget.user.providerData
            .any((p) => p.providerId == PhoneAuthProvider.PROVIDER_ID)) {
      _showError("You already have a phone linked to this account.");
      return;
    }

    try {
      await ref.read(authNotifierProvider.notifier).sendOtp(phone);
      _startCountdown();
      _codeFocusNode.requestFocus(); // auto-focus OTP field
    } catch (e) {
      _showError(e);
    }
  }

  // ---------------- VERIFY OTP ----------------
  Future<void> _verifyOtp() async {
    final code = widget.codeController.text.trim();
    final verificationId = ref.read(authNotifierProvider).verificationId;
    if (code.isEmpty || verificationId == null) return;

    Future<void> doVerify() async {
      try {
        await ref.read(authNotifierProvider.notifier).verifyOtp(
              verificationId: verificationId,
              smsCode: code,
              linkMode: _linkMode,
            );

        widget.onVerified?.call();

        widget.phoneController.clear();
        widget.codeController.clear();
        _codeFocusNode.unfocus();
        _phoneFocusNode.requestFocus();
      } catch (e) {
        _showError(e);
      }
    }

    if (widget.isLinking) {
      await doVerify();
    } else {
      await performSensitiveAction(
        context,
        doVerify,
        ref.read(authNotifierProvider.notifier),
        widget.user.email, // positional argument
      );
    }
  }

  // ---------------- RESEND OTP ----------------
  Future<void> _resendOtp() async {
    final phone = widget.phoneController.text.trim();
    if (phone.isEmpty || _countdown > 0 || !_validatePhone(phone)) return;

    try {
      await ref.read(authNotifierProvider.notifier).resendOtp(phone);
      _startCountdown();
      _codeFocusNode.requestFocus();
    } catch (e) {
      _showError(e);
    }
  }

  // ---------------- ERROR HANDLER ----------------
  void _showError(Object e) {
    final msg = e is String ? e : _mapFirebaseError(e);
    ref.read(authNotifierProvider.notifier).setOtpFailed(msg);
    widget.onError?.call(e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ---------------- RESEND TIMER COLOR ----------------
  Color _getProgressColor(double fraction) {
    if (fraction > 0.66) return Colors.green;
    if (fraction > 0.33) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final phoneEnabled = state.otpStatus == OtpStatus.idle ||
        state.otpStatus == OtpStatus.failed;
    final codeEnabled = !state.verifyingOtp;
    final canResend = _countdown == 0 && !state.sendingOtp;
    final canSendOrVerify = !state.sendingOtp && !state.verifyingOtp;
    final fraction =
        _countdown > 0 ? _countdown / widget.otpCountdownSeconds : 0.0;
    final alreadyLinked = widget.user.providerData
        .any((p) => p.providerId == PhoneAuthProvider.PROVIDER_ID);

    return Column(
      children: [
        _PhoneInput(
            enabled: phoneEnabled,
            controller: widget.phoneController,
            focusNode: _phoneFocusNode,
            errorText: _phoneError),
        if (state.otpStatus != OtpStatus.idle)
          _CodeInputSection(
            codeController: widget.codeController,
            codeEnabled: codeEnabled,
            linkMode: _linkMode,
            showLinkCheckbox: widget.showLinkCheckbox,
            alreadyLinked: alreadyLinked,
            canSendOrVerify: canSendOrVerify,
            focusNode: _codeFocusNode,
            autofocus: state.otpStatus == OtpStatus.codeSent,
            onLinkModeChanged: (v) => setState(() => _linkMode = v),
          ),
        if (_countdown > 0)
          _CountdownProgress(
              countdown: _countdown,
              fraction: fraction,
              getColor: _getProgressColor),
        const SizedBox(height: 8),
        _OtpStatusMessage(state: state),
        const SizedBox(height: 16),
        _ActionButtons(
          state: state,
          canResend: canResend,
          canSendOrVerify: canSendOrVerify,
          phoneEnabled: phoneEnabled,
          codeEnabled: codeEnabled,
          sendOtp: () => TapGuard.run('otp.send', _sendOtp),
          verifyOtp: () => TapGuard.run('otp.verify', _verifyOtp),
          resendOtp: _resendOtp,
        ),
      ],
    );
  }
}

// -------------------- PRIVATE WIDGETS --------------------
class _PhoneInput extends StatelessWidget {
  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;

  const _PhoneInput(
      {required this.enabled,
      required this.controller,
      required this.focusNode,
      this.errorText});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        enabled: enabled,
        decoration: InputDecoration(
            labelText: "Phone Number",
            hintText: "+63XXXXXXXXXX",
            errorText: errorText),
      );
}

class _CodeInputSection extends StatelessWidget {
  final TextEditingController codeController;
  final bool codeEnabled;
  final bool linkMode;
  final bool showLinkCheckbox;
  final bool alreadyLinked;
  final bool canSendOrVerify;
  final FocusNode focusNode;
  final bool autofocus;
  final void Function(bool) onLinkModeChanged;

  const _CodeInputSection({
    required this.codeController,
    required this.codeEnabled,
    required this.linkMode,
    required this.showLinkCheckbox,
    required this.alreadyLinked,
    required this.canSendOrVerify,
    required this.focusNode,
    required this.autofocus,
    required this.onLinkModeChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const SizedBox(height: 12),
          TextField(
            controller: codeController,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            enabled: codeEnabled,
            autofocus: autofocus,
            decoration: const InputDecoration(labelText: "SMS Code"),
          ),
          const SizedBox(height: 8),
          if (showLinkCheckbox)
            Row(
              children: [
                Checkbox(
                  value: linkMode,
                  onChanged: (!alreadyLinked && canSendOrVerify)
                      ? (v) => onLinkModeChanged(v ?? false)
                      : null,
                ),
                Text(alreadyLinked
                    ? "Phone already linked"
                    : "Link this phone to account"),
              ],
            ),
        ],
      );
}

class _CountdownProgress extends StatelessWidget {
  final int countdown;
  final double fraction;
  final Color Function(double) getColor;

  const _CountdownProgress(
      {required this.countdown,
      required this.fraction,
      required this.getColor});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          LinearProgressIndicator(
            value: 1 - fraction,
            color: getColor(fraction),
            backgroundColor: Colors.grey.shade300,
          ),
          const SizedBox(height: 4),
          Text("Resend in $countdown s",
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );
}

class _OtpStatusMessage extends StatelessWidget {
  final AuthState state;
  const _OtpStatusMessage({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state.otpStatus) {
      case OtpStatus.idle:
      case OtpStatus.verifying:
        return const SizedBox.shrink();
      case OtpStatus.codeSent:
        return const Text("Code sent! 📲",
            style: TextStyle(color: Colors.blue));
      case OtpStatus.verified:
        return const Text("Phone verified ✅",
            style: TextStyle(color: Colors.green));
      case OtpStatus.failed:
        return Text(state.errorMsg ?? "OTP failed ❌",
            style: const TextStyle(color: Colors.red));
      case OtpStatus.resending:
        return const Text("Resending OTP...",
            style: TextStyle(color: Colors.orange));
    }
  }
}

class _ActionButtons extends StatelessWidget {
  final AuthState state;
  final bool canResend;
  final bool canSendOrVerify;
  final bool phoneEnabled;
  final bool codeEnabled;
  final VoidCallback sendOtp;
  final VoidCallback verifyOtp;
  final VoidCallback resendOtp;

  const _ActionButtons({
    required this.state,
    required this.canResend,
    required this.canSendOrVerify,
    required this.phoneEnabled,
    required this.codeEnabled,
    required this.sendOtp,
    required this.verifyOtp,
    required this.resendOtp,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.otpStatus == OtpStatus.idle)
            AuthButton(
              icon: Icons.send,
              label: "Send OTP",
              loading: state.sendingOtp,
              onPressed: (!state.sendingOtp && phoneEnabled) ? sendOtp : null,
            )
          else ...[
            AuthButton(
              icon: Icons.verified_user,
              label: "Verify Code",
              loading: state.verifyingOtp,
              onPressed:
                  (!state.verifyingOtp && codeEnabled) ? verifyOtp : null,
            ),
            const SizedBox(width: 8),
            AuthButton(
              icon: Icons.refresh,
              label: canResend ? "Resend OTP" : "Resend",
              loading: state.otpStatus == OtpStatus.resending,
              onPressed: canResend ? resendOtp : null,
            ),
          ],
        ],
      );
}
