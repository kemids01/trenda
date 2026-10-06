import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/profile_parts.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: ListView(children: [child])),
    );

void main() {
  // The narrowest common phone width — four tiles and three stages must fit.
  Future<void> narrow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('tool grid lays eight tools out 4+4 on a 320px screen',
      (tester) async {
    await narrow(tester);
    var tapped = '';
    await tester.pumpWidget(_host(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ProfilePanel(
        icon: Icons.apps,
        accent: kLaneTeal,
        title: 'Shortcuts',
        child: ProfileToolGrid(tools: [
          for (final t in [
            'Messages',
            'Wishlist',
            'Gift cards',
            'Addresses',
            'Installments',
            'Returns',
            'Help & FAQ',
            'Contact us',
          ])
            ProfileTool(
                icon: Icons.star,
                accent: kLaneBlue,
                label: t,
                badge: t == 'Messages' ? 120 : 0,
                onTap: () => tapped = t),
        ]),
      ),
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('99+'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Installments')).dy,
        greaterThan(tester.getTopLeft(find.text('Messages')).dy));
    await tester.tap(find.text('Returns'));
    expect(tapped, 'Returns');
  });

  testWidgets('a short last row keeps the grid columns aligned',
      (tester) async {
    await narrow(tester);
    await tester.pumpWidget(_host(ProfileToolGrid(tools: [
      for (final t in ['A', 'B', 'C', 'D', 'E'])
        ProfileTool(
            icon: Icons.star, accent: kLaneBlue, label: t, onTap: () {}),
    ])));
    expect(tester.getCenter(find.text('E')).dx,
        closeTo(tester.getCenter(find.text('A')).dx, 0.01));
  });

  testWidgets('order stages show a dash until counts load, and fit 320px',
      (tester) async {
    await narrow(tester);
    await tester.pumpWidget(_host(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ProfilePanel(
        key: const Key('orders'),
        raised: true,
        icon: Icons.receipt_long,
        accent: kProfileBlue,
        title: 'My orders',
        subtitle: 'Track deliveries and past purchases',
        actionLabel: 'View all',
        onAction: () {},
        child: const Row(children: [
          OrderStageCell(
              icon: Icons.star,
              accent: kLaneGold,
              label: 'Pending',
              count: null),
          SizedBox(width: 8),
          OrderStageCell(
              icon: Icons.star,
              accent: kLaneTeal,
              label: 'On the way',
              count: 3),
          SizedBox(width: 8),
          OrderStageCell(
              icon: Icons.star,
              accent: kLaneTeal,
              label: 'Completed',
              count: 12),
        ]),
      ),
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('–'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    // ProfileTab reserves 44px of hero + 76px below it for this panel.
    final h = tester.getSize(find.byKey(const Key('orders'))).height;
    expect(h, inInclusiveRange(110, 126));
  });

  testWidgets('hero + avatar ring render in dark mode, and tap opens photo',
      (tester) async {
    await narrow(tester);
    var tapped = 0;
    await tester.pumpWidget(_host(
      ProfileHero(
        overlap: 64,
        child: ProfileAvatarRing(
          photoUrl: null,
          monogram: 'JD',
          percent: 60,
          onTap: () => tapped++,
        ),
      ),
      brightness: Brightness.dark,
    ));
    await tester.pumpAndSettle();
    expect(find.text('JD'), findsOneWidget);
    await tester.tap(find.byType(ProfileAvatarRing));
    expect(tapped, 1);
  });

  testWidgets('avatar ignores taps while a photo is uploading', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_host(ProfileAvatarRing(
      photoUrl: null,
      monogram: 'JD',
      percent: 100,
      loading: true,
      onTap: () => tapped++,
    )));
    await tester.tap(find.text('JD'), warnIfMissed: false);
    expect(tapped, 0);
  });

  testWidgets(
      'a prompt value renders as an Add pill; a locked row shows a lock',
      (tester) async {
    await tester.pumpWidget(_host(const ProfileGroup(
        title: 'Account',
        subtitle: 'Your personal details',
        rows: [
          ProfileRow(
              icon: Icons.phone,
              accent: Colors.green,
              title: 'Phone',
              value: 'Add',
              valueIsPrompt: true),
          ProfileRow(
              icon: Icons.mail,
              accent: Colors.blue,
              title: 'Email',
              subtitle: 'From your Google sign-in',
              value: 'jo***@x.com',
              locked: true),
        ])));
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Your personal details'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('a long subtitle and value share a 320px row without overflow',
      (tester) async {
    await narrow(tester);
    await tester.pumpWidget(_host(const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ProfileGroup(title: 'Account', rows: [
        ProfileRow(
            icon: Icons.mail,
            title: 'Email',
            subtitle: 'From your Google sign-in, which cannot change',
            value: 'averyveryverylongname***@example.com',
            locked: true),
      ]),
    )));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards are white with no outline', (tester) async {
    await tester.pumpWidget(_host(const ProfileCard(child: Text('x'))));
    final m = tester.widget<Material>(find
        .descendant(
            of: find.byType(ProfileCard), matching: find.byType(Material))
        .first);
    expect(m.color, Colors.white);
    expect(m.shape, isNull);
  });
}
