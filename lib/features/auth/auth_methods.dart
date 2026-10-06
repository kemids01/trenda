// lib/features/auth/auth_methods.dart
//
// Which sign-in methods the customer app offers.
//
// ⚠️ Email/password and phone sign-in are TEMPORARILY HIDDEN (2026-09-21, user
// request) — Google is the only method shown. The code behind them is intact
// and still referenced by the login page, so flipping either flag back to
// `true` restores the section with no other edit.
const bool kEmailPasswordLoginEnabled = false;
const bool kPhoneLoginEnabled = false;
