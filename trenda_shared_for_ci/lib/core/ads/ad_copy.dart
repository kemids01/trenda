// lib/core/ads/ad_copy.dart
// Turns an official ad's free-text landing body into parts a screen can lay out:
// a lead line, "featuring" chips, and labelled facts (Where / How to avail /
// Valid until …). Pure — no Flutter — so it is testable and the detail screen
// only decides how things look.
//
// The body is whatever an admin typed, so the rules are forgiving:
//   • a line "Label: value" (short label, a space after the colon) is a fact —
//     "https://…" is not, because nothing follows its colon but "//";
//   • a "Featuring:/Menu:/Items:" fact becomes chips, split on , or ;
//   • a line about how long the promo runs ("until", "valid", "ends") is the
//     Valid fact even without a label;
//   • text before the first fact is the lead; text after it is a note.
// Nothing is ever dropped: a body with no structure comes back as all lead.

enum AdFactKind { where, howTo, valid, price, contact, hours, other }

class AdFact {
  final String label;
  final String value;
  final AdFactKind kind;
  const AdFact(this.label, this.value, this.kind);

  @override
  String toString() => 'AdFact($label: $value, $kind)';
}

class AdCopy {
  final String lead;
  final List<String> features;
  final List<AdFact> facts;
  final List<String> notes;
  const AdCopy({
    this.lead = '',
    this.features = const [],
    this.facts = const [],
    this.notes = const [],
  });

  bool get isEmpty => lead.isEmpty && features.isEmpty && facts.isEmpty && notes.isEmpty;
}

final _labelled = RegExp(r'^([A-Za-z][A-Za-z &/\-]{0,23}):\s+(.+)$');
final _featureLabel = RegExp(r'^(featuring|features|menu|items|products|includes?)$', caseSensitive: false);
final _validLine = RegExp(r'\b(until|valid|runs|ends|expires?)\b', caseSensitive: false);

AdFactKind _kindFor(String label) {
  final l = label.toLowerCase();
  if (RegExp(r'where|location|address|branch|find us').hasMatch(l)) return AdFactKind.where;
  if (RegExp(r'how|avail|claim|redeem|mechanics').hasMatch(l)) return AdFactKind.howTo;
  if (RegExp(r'valid|until|runs|period|date|promo ends|expir').hasMatch(l)) return AdFactKind.valid;
  if (RegExp(r'price|cost|fee|rate').hasMatch(l)) return AdFactKind.price;
  if (RegExp(r'contact|call|phone|mobile|viber|text').hasMatch(l)) return AdFactKind.contact;
  if (RegExp(r'hours|open|schedule|time').hasMatch(l)) return AdFactKind.hours;
  return AdFactKind.other;
}

String _stripEnd(String s) => s.trim().replaceAll(RegExp(r'[.\s]+$'), '');

AdCopy parseAdCopy(String body) {
  final lines = body
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final lead = <String>[];
  final features = <String>[];
  final facts = <AdFact>[];
  final notes = <String>[];

  for (final line in lines) {
    final m = _labelled.firstMatch(line);
    if (m != null) {
      final label = m.group(1)!.trim();
      final value = m.group(2)!.trim();
      if (_featureLabel.hasMatch(label)) {
        features.addAll(value.split(RegExp(r'[,;]')).map(_stripEnd).where((s) => s.isNotEmpty));
      } else {
        facts.add(AdFact(label, value, _kindFor(label)));
      }
      continue;
    }
    if (_validLine.hasMatch(line) && line.length <= 120) {
      facts.add(AdFact('Valid', line, AdFactKind.valid));
      continue;
    }
    if (facts.isEmpty && features.isEmpty) {
      lead.add(line);
    } else {
      notes.add(line);
    }
  }

  return AdCopy(
    lead: lead.join('\n\n'),
    features: features,
    facts: facts,
    notes: notes,
  );
}
