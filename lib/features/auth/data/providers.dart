// lib/features/auth/data/providers.dart
// ------------------------------------------------------------
// Riverpod providers for FirebaseAuth, GoogleSignIn (v7.2.0) and AuthRepository
// ------------------------------------------------------------

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../application/state.dart';
import '../application/notifier.dart';
import 'repository.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// GoogleSignIn provider for google_sign_in: ^7.2.0
/// Use the static instance here (avoids constructor issues).
/// If you need to configure server/client IDs, call initialize(...) before authenticate().
final googleSignInProvider =
    Provider<GoogleSignIn>((ref) => GoogleSignIn.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final gsi = ref.watch(googleSignInProvider);
  return AuthRepository(auth, gsi);
});

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo, ref);
});

/// The signed-in account's uid, or null for a guest.
///
/// ⚠️ EVERY provider that holds one account's data (cart, orders, wishlist, follows,
/// notifications) must `ref.watch` this. Those providers live for the whole app, so
/// without it they were built once and never reset: on a shared phone the next person
/// to sign in saw the last person's cart and orders, and a cart first built while
/// signed out stayed empty after signing in. Watching the uid rebuilds them on every
/// account change — sign-out, sign-in, or a switch between the two.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authNotifierProvider.select((s) => s.user?.uid)),
);
