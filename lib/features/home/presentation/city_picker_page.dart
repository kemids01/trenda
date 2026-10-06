// lib/features/home/presentation/city_picker_page.dart
// The city picker as its own page (`/city`). It used to BE the Local tab; that
// tab became Food (2026-09-25), and the header city pill — which always opened
// the picker — now pushes this page instead. The picker itself is unchanged.
import 'package:flutter/material.dart';
import 'location_tab.dart';

class CityPickerPage extends StatelessWidget {
  const CityPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your city')),
      body: const LocationTab(),
    );
  }
}
