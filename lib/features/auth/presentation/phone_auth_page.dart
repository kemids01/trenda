// lib/features/auth/presentation/phone_auth_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trenda_frontend/features/core/utils/auth_utils.dart';
import '../../auth/data/providers.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class PhoneAuthPage extends ConsumerStatefulWidget {
  final User? user;
  final bool isLinking;

  const PhoneAuthPage({super.key, this.user, this.isLinking = false});

  @override
  ConsumerState<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends ConsumerState<PhoneAuthPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendOrVerifyOtp() async {
    final repo = ref.read(authRepositoryProvider);

    if (_verificationId == null) {
      await repo.sendOtp(
        _phoneController.text.trim(),
        onCodeSent: (verId, _) {
          setState(() => _verificationId = verId);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("OTP sent!")));
        },
        onAutoVerified: (user) {
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Phone linked successfully!")),
            );
          }
        },
        onError: (e) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
        },
        linkMode: widget.isLinking,
      );
    } else {
      await repo.verifyOtp(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
        linkMode: widget.isLinking,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number linked successfully!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isLinking ? "Link Phone Number" : "Sign in with Phone"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "Phone Number"),
              keyboardType: TextInputType.phone,
            ),
            if (_verificationId != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                decoration:
                    const InputDecoration(labelText: "Verification Code"),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                const SizedBox(width: 16),
                Consumer(
                  builder: (context, ref, _) {
                    return ElevatedButton(
                      onPressed: () => TapGuard.run('phone_auth.sendOrVerify', () async {
                        await performSensitiveAction(
                          context,
                          _sendOrVerifyOtp,
                          ref.read(authNotifierProvider.notifier),
                          widget.user?.email, // <-- this is the 4th argument
                        );
                      }),
                      child:
                          Text(_verificationId == null ? "Send OTP" : "Verify"),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
