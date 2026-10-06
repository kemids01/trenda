// lib/features/auth/presentation/widgets/facebook_sign_in_button.dart
import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// The Facebook sign-in call-to-action button.
/// Shared by the login page and guest state UI.
class FacebookSignInButton extends StatelessWidget {
  const FacebookSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continue with Facebook',
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  static const Color _facebookBlue = Color(0xFF1877F2);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _facebookBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _facebookBlue.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: loading
                  ? const CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    )
                  : const _FacebookMark(),
            ),
            AppSpacing.horizontalSM,
            Text(
              loading ? 'Signing in…' : label,
              style: AppTypography.withWeight(
                AppTypography.labelLarge,
                FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Facebook's lowercase 'f' logo mark drawn cleanly.
class _FacebookMark extends StatelessWidget {
  const _FacebookMark();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'f',
        style: TextStyle(
          fontSize: 22,
          height: 1.0,
          fontWeight: FontWeight.w900,
          fontFamily: 'sans-serif',
          color: Colors.white,
        ),
      ),
    );
  }
}
