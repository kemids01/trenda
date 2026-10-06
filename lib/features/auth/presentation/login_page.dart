// lib/features/auth/presentation/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_frontend/features/auth/presentation/forgot_password_page.dart';
import 'package:trenda_frontend/features/core/widgets/loading_listener.dart';
import 'package:trenda_frontend/features/core/widgets/auth_button.dart';
import '../auth_methods.dart';
import '../application/state.dart';
import '../data/providers.dart';
import '../../core/providers/tab_provider.dart';
import 'phone_auth_page.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/facebook_sign_in_button.dart';
import '../../../design_system/design_system.dart';

/// LoginPage — Google is the only sign-in method offered today. The email and
/// phone sections below stay in this file and are gated by the flags in
/// `auth_methods.dart`; flip one back to `true` to show it again.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Submit email/password login
  void _submitEmail() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final notifier = ref.read(authNotifierProvider.notifier);

    if (email.isEmpty || password.isEmpty) {
      notifier.setEmailError("Email and password required.");
      return;
    }

    // ✅ Allow any valid email address (not just Gmail)
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(email)) {
      notifier.setEmailError("Please enter a valid email address.");
      return;
    }

    notifier.setEmailError(null);
    notifier.signInWithEmail(email, password);
  }

  void _signInWithGoogle() =>
      ref.read(authNotifierProvider.notifier).signInWithGoogle();

  void _signInWithFacebook() =>
      ref.read(authNotifierProvider.notifier).signInWithFacebook();

  void _navigateToPhoneLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PhoneAuthPage(), // Full-page
      ),
    );
  }

  // Builds section header
  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(title, style: AppTypography.titleMedium),
      );

  // Email login form
  Widget _buildEmailSection(AuthState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionTitle("Sign in with Email"),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            enabled: !state.loadingEmail,
            decoration: const InputDecoration(
              labelText: "Email",
              border: OutlineInputBorder(),
            ),
          ),
          AppSpacing.verticalSM,
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !state.loadingEmail,
            decoration: const InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(),
            ),
          ),
          if (state.emailError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                state.emailError!,
                style: AppTypography.withColor(
                    AppTypography.bodySmall, AppColors.error),
              ),
            ),
          AppSpacing.verticalMD,
          AuthButton(
            icon: Icons.email,
            label: "Sign In",
            loading: state.loadingEmail,
            onPressed: state.loadingEmail ? null : _submitEmail,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTypography.labelMedium,
              ),
              child: const Text("Forgot Password?"),
            ),
          ),
          AppSpacing.verticalSM,
        ],
      );

  // Social sign-in buttons (Google & Facebook).
  Widget _buildSocialSection(AuthState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kEmailPasswordLoginEnabled) ...[
            AppSpacing.verticalLG,
            const Divider(),
            AppSpacing.verticalMD,
            _buildSectionTitle("Sign in with Social Account"),
          ],
          GoogleSignInButton(
            loading: state.loadingGoogle,
            onPressed: state.loadingFacebook ? null : _signInWithGoogle,
          ),
          AppSpacing.verticalSM,
          FacebookSignInButton(
            loading: state.loadingFacebook,
            onPressed: state.loadingGoogle ? null : _signInWithFacebook,
          ),
        ],
      );

  // The branded header card.
  Widget _buildBrandedHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Image.asset(
                'assets/images/trenda_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.storefront_rounded,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          AppSpacing.verticalLG,
          Text(
            'Welcome to Trenda',
            textAlign: TextAlign.center,
            style: AppTypography.headlineSmall,
          ),
          AppSpacing.verticalXS,
          Text(
            'Sign in to place orders, track deliveries and message the shops you buy from.',
            textAlign: TextAlign.center,
            style: AppTypography.withColor(
                AppTypography.bodySmall, AppColors.textSecondary),
          ),
          AppSpacing.verticalXL,
        ],
      );

  // Navigate to Phone login page
  Widget _buildPhoneButton() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.verticalLG,
          const Divider(),
          AppSpacing.verticalMD,
          AuthButton(
            icon: Icons.phone,
            label: "Sign in with Phone",
            loading: false,
            onPressed: _navigateToPhoneLogin,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);

    // Listen to auth state changes for snackbars and navigation
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (next.user != null) {
          if (Navigator.canPop(context)) Navigator.pop(context);
          ref.read(profileOpenRequestProvider.notifier).state++; // open the Profile page
        }
        if (next.successMsg != null && next.successMsg != prev?.successMsg) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(next.successMsg!)));
        }
        if (next.errorMsg != null && next.errorMsg != prev?.errorMsg) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(next.errorMsg!), backgroundColor: Colors.red));
        }
      });
    });

    return Scaffold(
      body: LoadingListener(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusXL),
              margin: AppSpacing.paddingLG,
              shadowColor: AppColors.overlayMedium,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!kEmailPasswordLoginEnabled) _buildBrandedHeader(),
                        if (kEmailPasswordLoginEnabled)
                          _buildEmailSection(state),
                        _buildSocialSection(state),
                        if (kPhoneLoginEnabled) _buildPhoneButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
