# Design — Customer Login: Friendly Errors + Cleanups [P4]

**Date:** 2026-06-28
**Repo:** trenda_frontend (customer app; client-only — no backend change)
**Scope:** P4 of the multi-app roadmap. Stops raw Firebase error strings from reaching customers and
tidies the post-auth navigation. Email sign-up is explicitly deferred.

## Problem
Investigation of `features/auth/` (2026-06-28) found the login flow is otherwise mature (email / Google /
phone-OTP sign-in, password reset; no fail-open) but has two concrete issues:

1. **Raw Firebase errors leak to users.** The repository (`data/repository.dart`) `rethrow`s the raw
   `FirebaseAuthException`, and the notifier (`application/notifier.dart`) sets the user-facing
   `errorMsg` to `e.toString()` / `"Error: $e"` / `error.toString()`. So a wrong password shows
   `[firebase_auth/invalid-credential] The supplied auth credential is incorrect, malformed or has
   expired.` instead of "Incorrect email or password."
   Sites: `signInWithEmail` catch (~L604), `sendPasswordReset` catch (~L629), `signInWithGoogle` generic
   catch (~L564), `sendOtp` onError+catch (~L668/677), `resendOtp` onError+catch (~L733/739), `verifyOtp`
   catch (~L788).

2. **Post-auth navigation forced even on failure.** Several methods set `selectedTabProvider = 4`
   (Profile tab) in a `finally` block — i.e. on error too. For `sendPasswordReset` and `sendOtp`,
   jumping to Profile is also semantically wrong (the UI is driven by `successMsg` / `OtpStatus.codeSent`).

(Out of scope but noted: there is **no email sign-up** anywhere in the app — email is sign-in-only.
New customers register via phone-OTP or Google. Deferred to a separate follow-up.)

## Decisions (from brainstorming)
- Fix the error leak with **one pure, tested code→message mapper** applied at every raw-error site.
- **Conservative navigation cleanup:** login methods navigate to Profile **only on success**;
  `sendPasswordReset` / `sendOtp` no longer navigate.
- **Defer email sign-up.**

## Architecture

### 1. `friendlyAuthError` — `features/auth/application/auth_error_messages.dart` (new, pure)
```dart
String friendlyAuthError(Object error)
```
Imports `package:firebase_auth/firebase_auth.dart`. If `error is FirebaseAuthException`, switch on
`error.code`; else return a generic default. Mapping:
| code | message |
|---|---|
| `invalid-credential`, `wrong-password`, `user-not-found`, `INVALID_LOGIN_CREDENTIALS` | Incorrect email or password. |
| `invalid-email` | Please enter a valid email address. |
| `user-disabled` | This account has been disabled. Please contact support. |
| `too-many-requests` | Too many attempts. Please wait a moment and try again. |
| `network-request-failed` | Network error. Check your connection and try again. |
| `email-already-in-use` | An account already exists for this email. |
| `weak-password` | Password is too weak (use at least 6 characters). |
| `invalid-verification-code` | The code you entered is incorrect. |
| `invalid-verification-id`, `session-expired`, `code-expired` | The code expired. Please request a new one. |
| `invalid-phone-number`, `missing-phone-number` | Please enter a valid phone number. |
| `account-exists-with-different-credential`, `credential-already-in-use` | This account is linked to a different sign-in method. |
| `operation-not-allowed` | This sign-in method is not enabled. Please try another. |
| any other `FirebaseAuthException` | `error.message` if non-empty, else "Authentication failed. Please try again." |
| non-`FirebaseAuthException` | Something went wrong. Please try again. |

Pure, synchronous, no side effects — fully unit-testable.

### 2. Apply the mapper in `application/notifier.dart`
Replace the raw user-facing strings with `friendlyAuthError(e)` / `friendlyAuthError(error)` at every site
listed in Problem #1. For `signInWithGoogle`, KEEP the existing `PlatformException` special-cases
(SHA-1 / `network_error`) and only route the final generic fallback (`"Error: $e"`) through the mapper.
`log(...)` of the raw error stays (developer logs are unaffected). `signOut`'s catch is left as-is
(not part of the login path).

### 3. Navigation cleanup (`application/notifier.dart`)
- `signInWithEmail`, `signInWithGoogle`, `verifyOtp`: move `ref.read(selectedTabProvider.notifier).state = 4`
  out of `finally` and into the **success branch** (where `status: AuthStatus.authenticated` is set).
  Delete the `finally` block if it then only contained that line.
- `sendPasswordReset`, `sendOtp`: remove the `finally { ... = 4 }` entirely (no navigation).
- Leave `resendOtp`'s `onAutoVerified` tab-set as-is (that IS a success path).
- Login-page success navigation is also handled by `login_page.dart`'s `ref.listen` (sets tab 4 when
  `user != null`), so success behavior is preserved.

## Testing
- `test/auth_error_messages_test.dart` (pure):
  - one assertion per mapped code: `friendlyAuthError(FirebaseAuthException(code: '<code>'))` equals the
    expected message (cover at least invalid-credential, wrong-password, user-not-found, invalid-email,
    too-many-requests, network-request-failed, email-already-in-use, weak-password,
    invalid-verification-code, session-expired, invalid-phone-number).
  - unknown Firebase code WITH a `.message` → returns the message.
  - unknown Firebase code with empty/no message → returns the generic Firebase fallback.
  - a plain `Exception('boom')` → "Something went wrong. Please try again." (never contains "boom").
- `flutter analyze lib` → 0 errors. Full suite stays green (only the pre-existing boilerplate
  `widget_test.dart` fail remains).

## Risks / mitigations
- **Mapping drift across Firebase versions:** the default falls back to `error.message` then a generic
  line, so an unmapped code still shows something reasonable (never a raw `[plugin/code]` string for the
  mapped cases). Tests pin the mapped codes.
- **Navigation regression:** login success still navigates (success-branch set + login-page listener).
  Removing navigation from reset/sendOtp is intentional and matches their UI-driven states.

## Out of scope (P4)
- Email sign-up / registration (separate follow-up).
- OTP/phone flow redesign, password-strength UI, reCAPTCHA, the `device_session_helper` Firestore-rules
  item (P1 F5).
- Any backend or trenda_shared change.
