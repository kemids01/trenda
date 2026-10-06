// lib/features/home/presentation/profile_page.dart
// The Profile screen as its own page (`/profile`), opened from the avatar at
// the top right of the main screen. It used to be bottom tab 4; that slot is
// now Vendor Ads. The content is unchanged — it is the same ProfileTab.
import 'package:flutter/material.dart';

import 'profile_tab.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: const ProfileTab(),
    );
  }
}
