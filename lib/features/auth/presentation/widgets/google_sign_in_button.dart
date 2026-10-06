// lib/features/auth/presentation/widgets/google_sign_in_button.dart
import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// The single Google sign-in call-to-action.
///
/// Shared by the login page and the Profile tab's guest state so the one
/// sign-in route the app offers looks and behaves identically wherever a
/// signed-out customer meets it.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  static const Color _googleBlue = Color(0xFF4285F4);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.textSecondary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
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
                      valueColor: AlwaysStoppedAnimation(_googleBlue),
                    )
                  : const _GoogleMark(),
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

/// Google's wordmark initial. Drawn rather than shipped as an asset so the
/// button carries no bundled brand image.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'G',
        style: TextStyle(
          fontSize: 19,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: GoogleSignInButton._googleBlue,
        ),
      ),
    );
  }
}
