import 'package:flutter/material.dart';
import '../data/location_repository.dart';

/// Distinct barangay names — trimmed, blanks dropped, case-insensitive dedupe, sorted. Pure/testable.
List<String> barangayNames(List<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final r in raw) {
    final name = r.trim();
    if (name.isEmpty) continue;
    if (seen.add(name.toLowerCase())) out.add(name);
  }
  out.sort();
  return out;
}

/// Barangay selector fed by the admin municipality's barangays (GET /api/locations/barangays?city=NAME).
/// Pairs with MunicipalityDropdown. No Riverpod dependency.
class BarangayDropdown extends StatefulWidget {
  final String? municipality;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String labelText;
  final bool isRequired;
  final List<String>? items; // inject to skip fetch (tests/offline)

  const BarangayDropdown({
    super.key,
    required this.municipality,
    required this.value,
    required this.onChanged,
    this.labelText = 'Barangay',
    this.isRequired = false,
    this.items,
  });

  @override
  State<BarangayDropdown> createState() => _BarangayDropdownState();
}

class _BarangayDropdownState extends State<BarangayDropdown> {
  Future<List<String>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant BarangayDropdown old) {
    super.didUpdateWidget(old);
    if (old.municipality != widget.municipality) {
      setState(() => _future = _load());
    }
  }

  Future<List<String>> _load() async {
    if (widget.items != null) return widget.items!;
    final muni = widget.municipality;
    if (muni == null || muni.trim().isEmpty) return const [];
    return LocationRepository().getBarangays(muni);
  }

  @override
  Widget build(BuildContext context) {
    final muni = widget.municipality;
    if ((muni == null || muni.trim().isEmpty) && widget.items == null) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: widget.labelText,
          border: const OutlineInputBorder(),
          helperText: 'Select a municipality first',
        ),
        child: const Text(''),
      );
    }
    return FutureBuilder<List<String>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return InputDecorator(
            decoration: InputDecoration(
              labelText: widget.labelText,
              border: const OutlineInputBorder(),
              suffixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            child: const Text(''),
          );
        }
        if (snap.hasError) {
          return InkWell(
            onTap: () => setState(() => _future = _load()),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: widget.labelText,
                border: const OutlineInputBorder(),
                errorText: 'Could not load — tap to retry',
              ),
              child: const Text(''),
            ),
          );
        }
        final names = barangayNames(snap.data ?? const []);
        final safeValue =
            (widget.value != null && names.contains(widget.value)) ? widget.value : null;
        return DropdownButtonFormField<String>(
          initialValue: safeValue,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.isRequired ? '${widget.labelText} *' : widget.labelText,
            border: const OutlineInputBorder(),
          ),
          hint: const Text('Select barangay'),
          items: names.map((n) => DropdownMenuItem<String>(value: n, child: Text(n))).toList(),
          onChanged: widget.onChanged,
          validator: widget.isRequired
              ? (v) => (v == null || v.isEmpty) ? 'Please select a barangay' : null
              : null,
        );
      },
    );
  }
}
