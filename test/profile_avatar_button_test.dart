import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/chat/providers/chat_provider.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/profile_avatar_button.dart';

Widget _app((bool, String, String) info, {int unread = 0}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(appBar: AppBar(actions: const [ProfileAvatarButton()])),
    ),
    GoRoute(path: '/profile', builder: (_, __) => const Scaffold(body: Text('PROFILE PAGE'))),
  ]);
  return ProviderScope(
    overrides: [
      profileAvatarInfoProvider.overrideWithValue(info),
      unreadMessagesCountProvider.overrideWith((ref) async => unread),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

const _badge = ValueKey('profile-unread-badge');

void main() {
  testWidgets('signed out: person glyph, tap opens /profile', (t) async {
    await t.pumpWidget(_app((false, '', ''), unread: 3));
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    // Signed out the count is never read, so no badge.
    await t.pump();
    expect(find.byKey(_badge), findsNothing);
    await t.tap(find.byType(ProfileAvatarButton));
    await t.pumpAndSettle();
    expect(find.text('PROFILE PAGE'), findsOneWidget);
  });

  testWidgets('signed in without a photo shows the initial', (t) async {
    await t.pumpWidget(_app((true, '', 'maria santos')));
    await t.pump();
    expect(find.text('M'), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
    expect(find.byKey(_badge), findsNothing);
  });

  testWidgets('unread chat messages show a count, and the avatar still opens /profile',
      (t) async {
    await t.pumpWidget(_app((true, '', 'maria santos'), unread: 2));
    await t.pump();
    expect(find.byKey(_badge), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await t.tap(find.byKey(_badge), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text('PROFILE PAGE'), findsOneWidget);
  });

  testWidgets('more than 99 reads 99+', (t) async {
    await t.pumpWidget(_app((true, '', 'maria santos'), unread: 150));
    await t.pump();
    expect(find.text('99+'), findsOneWidget);
  });
}
