import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/auth/application/notifier.dart';
import 'package:trenda_frontend/features/auth/application/state.dart';
import 'package:trenda_frontend/features/auth/data/providers.dart';
import 'package:trenda_frontend/features/auth/data/repository.dart';
import 'package:trenda_frontend/features/home/application/user_profile_notifier.dart';
import 'package:trenda_frontend/features/home/models/profile_models.dart';
import 'package:trenda_frontend/features/home/presentation/profile_page.dart';

class _Repo implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth extends AuthNotifier {
  _Auth(Ref ref) : super(_Repo(), ref) {
    state = const AuthState(
        status: AuthStatus.authenticated, otpStatus: OtpStatus.idle);
  }
}

class _Profile extends UserProfileNotifier {
  _Profile({this.serverSaves = true, this.delay = Duration.zero});
  final Duration delay;
  final bool serverSaves;
  final saved = <String>[];
  @override
  Future<UserProfileState> build() async =>
      const UserProfileState(displayName: 'Maria', email: 'maria@example.com');
  @override
  Future<bool> updatePhone(String newPhone) async {
    saved.add(newPhone);
    await Future<void>.delayed(delay);
    if (serverSaves) {
      state = AsyncValue.data(state.value!.copyWith(phone: newPhone));
    }
    return serverSaves;
  }
}

Future<GoRouter> _openProfile(WidgetTester t, _Profile profile) async {
  t.view.physicalSize = const Size(1200, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(initialLocation: '/home', routes: [
    GoRoute(
        path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
  ]);
  await t.pumpWidget(ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith((ref) => _Auth(ref)),
      userProfileProvider.overrideWith(() => profile),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  router.push('/profile');
  await t.pump();
  await t.pump();
  await t.pump(const Duration(seconds: 2));
  return router;
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(seconds: 1));
  await t.pump(const Duration(
      milliseconds: 500)); // finish a pop that landed in the last frame
}

void _expectProfileShown() {
  expect(find.byType(ProfilePage), findsOneWidget);
  expect(
      find.text('HOME'), findsNothing); // the page under /profile stays covered
}

void main() {
  slowSaveTests();
  slowNameTests();
  testWidgets('saving a phone closes the dialog and keeps the profile page',
      (t) async {
    final profile = _Profile();
    await _openProfile(t, profile);
    await t.tap(find.text('Phone'));
    await _settle(t);
    await t.enterText(find.byType(TextFormField), '09171234567');
    await t.tap(find.text('Save'));
    await _settle(t);

    expect(t.takeException(), isNull);
    expect(profile.saved, ['09171234567']);
    expect(find.byType(AlertDialog), findsNothing);
    _expectProfileShown();
    expect(find.text('*******4567'), findsOneWidget);
  });

  testWidgets('cancel closes only the dialog', (t) async {
    await _openProfile(t, _Profile());
    await t.tap(find.text('Phone'));
    await _settle(t);
    await t.tap(find.text('Cancel'));
    await _settle(t);
    expect(find.byType(AlertDialog), findsNothing);
    _expectProfileShown();
  });

  testWidgets('an invalid number is refused before any save', (t) async {
    final profile = _Profile();
    await _openProfile(t, profile);
    await t.tap(find.text('Phone'));
    await _settle(t);
    await t.enterText(find.byType(TextFormField), '12345');
    await t.tap(find.text('Save'));
    await _settle(t);
    expect(profile.saved, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a failed save keeps the dialog open and says so', (t) async {
    final profile = _Profile(serverSaves: false);
    await _openProfile(t, profile);
    await t.tap(find.text('Phone'));
    await _settle(t);
    await t.enterText(find.byType(TextFormField), '09171234567');
    await t.tap(find.text('Save'));
    await _settle(t);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.text('Phone updated ✅'), findsNothing);
    _expectProfileShown();
  });

  testWidgets('cancelling the name dialog keeps the profile page', (t) async {
    await _openProfile(t, _Profile());
    await t.tap(find.text('Name'));
    await _settle(t);
    await t.tap(find.text('Cancel'));
    await _settle(t);
    expect(find.byType(AlertDialog), findsNothing);
    _expectProfileShown();
  });
}

void slowSaveTests() {
  testWidgets(
      'tapping Save again while a slow save runs never pops past the dialog',
      (t) async {
    final profile = _Profile(delay: const Duration(seconds: 2));
    await _openProfile(t, profile);
    await t.tap(find.text('Phone'));
    await _settle(t);
    await t.enterText(find.byType(TextField).last, '09171234567');
    for (var i = 0; i < 3; i++) {
      // The button itself: after the first tap its label is a spinner.
      await t.tap(find.byType(ElevatedButton).last, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(seconds: 3));
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    _expectProfileShown();
    expect(profile.saved, hasLength(1)); // one save, not three
  });
}

class _SlowName extends _Profile {
  @override
  Future<void> updatePersonalInfo({
    String? firstName,
    String? middleName,
    String? surname,
    DateTime? birthday,
    String? gender,
  }) =>
      Future<void>.delayed(const Duration(seconds: 2));
}

void slowNameTests() {
  testWidgets('tapping Save repeatedly on the name dialog pops only the dialog',
      (t) async {
    await _openProfile(t, _SlowName());
    await t.tap(find.text('Name'));
    await _settle(t);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.text('Save'), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    _expectProfileShown();
  });
}
