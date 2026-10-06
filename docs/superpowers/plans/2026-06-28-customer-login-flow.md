# Customer Login: Friendly Errors + Cleanups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace raw Firebase error strings shown to customers with friendly messages, via one pure tested mapper applied across the auth notifier, and stop forcing the Profile tab on failed auth.

**Architecture:** New pure `friendlyAuthError(Object)` in `features/auth/application/auth_error_messages.dart`; apply it at every user-facing error site in `features/auth/application/notifier.dart`; move/remove the `finally { selectedTabProvider = 4 }` navigation. Client-only; no backend/trenda_shared change.

**Tech Stack:** Flutter + Riverpod + firebase_auth. Tests: `flutter test <path>`; analyze: `flutter analyze lib`. From `trenda_frontend`.

**Branch:** `feat/fix-customer-login` (already created; spec committed). Local-only repo.

**Verified facts (2026-06-28):**
- `notifier.dart` already imports `package:firebase_auth/firebase_auth.dart` (L5) and `tab_provider.dart` (L15).
- Raw-error sites: `signInWithEmail` catch (~L602-606), `sendPasswordReset` catch (~L627-630),
  `signInWithGoogle` generic catch (~L562-566, after PlatformException handling), `sendOtp` onError
  (~L664-671) + catch (~L673-679), `resendOtp` onError (~L730-734) + catch (~L736-740), `verifyOtp` catch
  (~L782-789).
- `finally { ref.read(selectedTabProvider.notifier).state = 4; }` in: `signInWithEmail` (~L607-610),
  `signInWithGoogle` (~L567-570), `sendPasswordReset` (~L631-634), `sendOtp` (~L680-683), `verifyOtp`
  (~L790-793). Success branches set `status: AuthStatus.authenticated`.

---

### Task 1: `friendlyAuthError` mapper + unit tests (pure, TDD)

**Files:**
- Create: `lib/features/auth/application/auth_error_messages.dart`
- Test: `test/auth_error_messages_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/auth_error_messages_test.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/auth/application/auth_error_messages.dart';

FirebaseAuthException _e(String code, [String? message]) =>
    FirebaseAuthException(code: code, message: message);

void main() {
  test('credential errors collapse to one friendly message', () {
    const expected = 'Incorrect email or password.';
    expect(friendlyAuthError(_e('invalid-credential')), expected);
    expect(friendlyAuthError(_e('wrong-password')), expected);
    expect(friendlyAuthError(_e('user-not-found')), expected);
  });

  test('common codes map to friendly text', () {
    expect(friendlyAuthError(_e('invalid-email')), 'Please enter a valid email address.');
    expect(friendlyAuthError(_e('too-many-requests')),
        'Too many attempts. Please wait a moment and try again.');
    expect(friendlyAuthError(_e('network-request-failed')),
        'Network error. Check your connection and try again.');
    expect(friendlyAuthError(_e('email-already-in-use')),
        'An account already exists for this email.');
    expect(friendlyAuthError(_e('weak-password')),
        'Password is too weak (use at least 6 characters).');
    expect(friendlyAuthError(_e('invalid-verification-code')),
        'The code you entered is incorrect.');
    expect(friendlyAuthError(_e('session-expired')),
        'The code expired. Please request a new one.');
    expect(friendlyAuthError(_e('invalid-phone-number')),
        'Please enter a valid phone number.');
  });

  test('unknown Firebase code with a message returns the message', () {
    expect(friendlyAuthError(_e('some-new-code', 'Custom backend message')),
        'Custom backend message');
  });

  test('unknown Firebase code without message returns generic Firebase fallback', () {
    expect(friendlyAuthError(_e('some-new-code')),
        'Authentication failed. Please try again.');
  });

  test('non-Firebase error returns generic default (no raw text leak)', () {
    final msg = friendlyAuthError(Exception('boom secret detail'));
    expect(msg, 'Something went wrong. Please try again.');
    expect(msg.contains('boom'), isFalse);
  });
}
```

- [ ] **Step 2: Run it, confirm it fails**

Run: `flutter test test/auth_error_messages_test.dart`
Expected: FAIL (`auth_error_messages.dart` not found).

- [ ] **Step 3: Implement the mapper**

```dart
// lib/features/auth/application/auth_error_messages.dart
import 'package:firebase_auth/firebase_auth.dart';

/// Maps an auth error (usually a FirebaseAuthException) to a short, user-friendly
/// message. Never returns a raw `[plugin/code]` string for known cases; falls back
/// to the exception's own message, then a generic line.
String friendlyAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Password is too weak (use at least 6 characters).';
      case 'invalid-verification-code':
        return 'The code you entered is incorrect.';
      case 'invalid-verification-id':
      case 'session-expired':
      case 'code-expired':
        return 'The code expired. Please request a new one.';
      case 'invalid-phone-number':
      case 'missing-phone-number':
        return 'Please enter a valid phone number.';
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return 'This account is linked to a different sign-in method.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please try another.';
      default:
        final m = error.message;
        if (m != null && m.trim().isNotEmpty) return m;
        return 'Authentication failed. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
```

- [ ] **Step 4: Run it, confirm PASS (5 tests). Then `flutter analyze lib/features/auth/application/auth_error_messages.dart` → 0 errors.**

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/application/auth_error_messages.dart test/auth_error_messages_test.dart
git commit -m "feat(auth): friendlyAuthError code->message mapper (P4)"
```

---

### Task 2: Apply the mapper + navigation cleanup in `notifier.dart`

**Files:**
- Modify: `lib/features/auth/application/notifier.dart`

- [ ] **Step 1: Import the mapper**

Add near the other local imports (after L13 `import 'state.dart';`):
```dart
import 'auth_error_messages.dart';
```

- [ ] **Step 2: `signInWithEmail` — friendly error + success-only nav**

In `signInWithEmail`, change the catch's `errorMsg: e.toString(),` to `errorMsg: friendlyAuthError(e),`.
Then move navigation out of `finally` into success: in the `if (user != null)` success branch (where
`status: AuthStatus.authenticated` is set) add at the end of that branch:
```dart
        ref.read(selectedTabProvider.notifier).state = 4; // Profile tab
```
and DELETE the trailing `finally { ref.read(selectedTabProvider.notifier).state = 4; }` block (keep the
`try`/`catch`). The method body becomes `try { ... } catch (e, st) { ... }` with no `finally`.

- [ ] **Step 3: `signInWithGoogle` — friendly fallback + success-only nav**

Keep the `PlatformException` block (SHA-1 / `network_error` / else) unchanged. In the FINAL generic
`catch (e, st)` change `errorMsg: "Error: $e",` to `errorMsg: friendlyAuthError(e),`. Move navigation to
success: in the `if (user != null)` branch (after `loadingGoogle: false`) add
`ref.read(selectedTabProvider.notifier).state = 4; // Profile tab`, and DELETE the trailing
`finally { ... = 4; }` block.

- [ ] **Step 4: `sendPasswordReset` — friendly error + remove nav**

Change the catch `errorMsg: e.toString(),` to `errorMsg: friendlyAuthError(e),`. DELETE its
`finally { ref.read(selectedTabProvider.notifier).state = 4; }` block entirely (password reset should not
navigate to Profile).

- [ ] **Step 5: `sendOtp` — friendly errors + remove nav**

In the `onError: (error) { ... }` callback change `errorMsg: error.toString(),` to
`errorMsg: friendlyAuthError(error),`. In the outer `catch (e) { ... }` change `errorMsg: e.toString(),`
to `errorMsg: friendlyAuthError(e),`. DELETE the `finally { ... = 4; }` block (sending an OTP should not
navigate; the UI reacts to `OtpStatus.codeSent`).

- [ ] **Step 6: `resendOtp` — friendly errors**

In its `onError: (error)` change `errorMsg: error.toString()` to `errorMsg: friendlyAuthError(error)`.
In its outer `catch (e)` change `errorMsg: e.toString()` to `errorMsg: friendlyAuthError(e)`. (Leave the
`onAutoVerified` tab-set — it's a success path. `resendOtp` has no `finally`.)

- [ ] **Step 7: `verifyOtp` — friendly error + success-only nav**

In the catch change `errorMsg: e.toString(),` to `errorMsg: friendlyAuthError(e),`. Move navigation to
success: in the `if (user != null)` branch (after `successMsg: "Phone verified ✅"`) add
`ref.read(selectedTabProvider.notifier).state = 4; // Profile tab`, and DELETE the trailing
`finally { ... = 4; }` block.

- [ ] **Step 8: Verify no raw-error sites remain on the login path**

Run:
```
grep -nE "errorMsg: e.toString\(\)|errorMsg: error.toString\(\)|errorMsg: \"Error: \$e\"" lib/features/auth/application/notifier.dart
```
Expected: only `signOut`'s `errorMsg: e.toString()` may remain (intentionally out of scope); none in
signInWithEmail/signInWithGoogle/sendPasswordReset/sendOtp/resendOtp/verifyOtp.
Run: `grep -n "finally" lib/features/auth/application/notifier.dart` → no `finally` remaining in the five
cleaned methods (other methods unaffected).

- [ ] **Step 9: Analyze + commit**

Run: `flutter analyze lib/features/auth` → 0 errors.
```bash
git add lib/features/auth/application/notifier.dart
git commit -m "feat(auth): friendly auth errors + success-only navigation (P4)"
```

---

### Task 3: Full verification + finish

**Files:** none (verification).

- [ ] **Step 1: Full analyze + suite**

Run:
```
flutter analyze lib
flutter test
```
Expected: `flutter analyze lib` 0 errors. Suite: the new `auth_error_messages_test.dart` passes; only the
documented pre-existing failure remains (`widget_test.dart` "Counter increments smoke test"); no NEW fails.

- [ ] **Step 2: Sanity grep**

Run: `grep -n "friendlyAuthError" lib/features/auth/application/notifier.dart`
Expected: friendlyAuthError used in signInWithEmail, signInWithGoogle, sendPasswordReset, sendOtp,
resendOtp, verifyOtp (≥6 usages).

- [ ] **Step 3: Finish the branch**

Invoke `superpowers:finishing-a-development-branch`. trenda_frontend is local-only → merge `--no-ff` into
local `main` + delete `feat/fix-customer-login` (P1/P2/P3/P5 pattern). Then update CLAUDE.md §17 with a
concise P4-done entry, noting deferred items: email sign-up/registration; OTP flow redesign;
`device_session_helper` Firestore-rules (P1 F5).

---

## Self-review checklist (controller, before executing)
- Spec coverage: mapper + tests (T1); applied at all 6 error sites + nav cleanup across 5 methods (T2);
  verify + finish (T3). ✓
- Names consistent: `friendlyAuthError` (single signature) used everywhere. ✓
- Navigation: success-only for login methods (signInWithEmail/Google/verifyOtp); removed for
  sendPasswordReset/sendOtp; resendOtp onAutoVerified untouched. ✓
- No backend/shared change → rule #7 N/A. ✓
