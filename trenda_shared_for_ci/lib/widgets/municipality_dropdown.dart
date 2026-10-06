import 'package:flutter/material.dart';
import '../data/municipality_repository.dart';

/// Distinct municipality names, sorted by `order` then name. Pure/testable.
List<String> municipalityNames(List<MunicipalityModel> items) {
  final seen = <String>{};
  final out = <MunicipalityModel>[];
  for (final m in items) {
    final name = m.name.trim();
    if (name.isEmpty) continue;
    final key = name.toLowerCase();
    if (seen.add(key)) out.add(m);
  }
  out.sort((a, b) {
    final byOrder = a.order.compareTo(b.order);
    return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
  });
  return out.map((m) => m.name.trim()).toList();
}

/// Self-contained municipality selector fed by the admin active-municipality list
/// (GET /api/municipalities). No Riverpod dependency — usable from any app.
class MunicipalityDropdown extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String labelText;
  final bool isRequired;
  final List<MunicipalityModel>? items; // inject to skip fetch (tests/offline)
  final bool includeInactive;

  const MunicipalityDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = 'Municipality/City',
    this.isRequired = false,
    this.items,
    this.includeInactive = false,
  });

  @override
  State<MunicipalityDropdown> createState() => _MunicipalityDropdownState();
}

class _MunicipalityDropdownState extends State<MunicipalityDropdown> {
  late Future<List<MunicipalityModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant MunicipalityDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `items` may arrive after the first build (a provider still loading). Reload when the
    // NAMES change — compare contents, not identity, so a caller that rebuilds its list every
    // frame doesn't refetch/flicker.
    if (!_sameNames(oldWidget.items, widget.items)) _future = _load();
  }

  bool _sameNames(List<MunicipalityModel>? a, List<MunicipalityModel>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name) return false;
    }
    return true;
  }

  Future<List<MunicipalityModel>> _load() async {
    if (widget.items != null) return widget.items!;
    return MunicipalityRepository()
        .getMunicipalities(includeInactive: widget.includeInactive);
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MunicipalityModel>>(
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
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            child: const Text(''),
          );
        }
        if (snap.hasError) {
          return InkWell(
            onTap: _retry,
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
        final names = municipalityNames(snap.data ?? const []);
        // Guard: never pass a value not in items (Dropdown asserts otherwise).
        final safeValue =
            (widget.value != null && names.contains(widget.value)) ? widget.value : null;
        return DropdownButtonFormField<String>(
          // Remounts when the NAMES change (not on every rebuild — ValueKey compares by
          // value) so `initialValue` is re-read fresh: DropdownButtonFormField only honours
          // `initialValue` when its FormFieldState is first created, not on later rebuilds.
          key: ValueKey(names.join('|')),
          initialValue: safeValue,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.isRequired ? '${widget.labelText} *' : widget.labelText,
            border: const OutlineInputBorder(),
          ),
          hint: const Text('Select municipality/city'),
          items: names
              .map((n) => DropdownMenuItem<String>(value: n, child: Text(n)))
              .toList(),
          onChanged: widget.onChanged,
          validator: widget.isRequired
              ? (v) => (v == null || v.isEmpty) ? 'Please select a municipality' : null
              : null,
        );
      },
    );
  }
}
