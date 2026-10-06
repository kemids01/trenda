// trenda_shared/lib/models/listing_template.dart
// Category-driven listing templates (foundation). Pure, no I/O.
// A category resolves to exactly one template that shapes the vendor form,
// pricing unit, fulfillment, transaction mode, and tier gate.

enum StockModel { quantity, availability, none }

/// A dynamic field injected into the wizard's Details step for a template.
class SpecField {
  final String key;     // stored under Product.attributes[key]
  final String label;   // shown to the vendor
  final bool isRequired;

  const SpecField(this.key, this.label, {this.isRequired = false});
}

class ListingTemplate {
  final String id; // 'standard_physical' | 'fresh' | 'big_ticket' | 'service'
  final List<String> categories;    // categories that resolve here
  final List<String> pricingUnits;  // allowed units; first = default
  final StockModel stockModel;
  final List<String> fulfillment;   // delivery | pickup | onsite
  final String transactionMode;     // checkout | inquiry
  final List<SpecField> specFields;
  final bool requiresPaidTier;
  final bool installmentEligible;

  // pricingUnits must always have at least one unit (first = default). This is
  // guaranteed by construction for the four hardcoded templates below; keeping
  // the constructor `const` (compile-time templates) is preferred over a runtime
  // assert, since Dart const-asserts cannot evaluate `.isNotEmpty`.
  const ListingTemplate({
    required this.id,
    required this.categories,
    required this.pricingUnits,
    required this.stockModel,
    required this.fulfillment,
    required this.transactionMode,
    this.specFields = const [],
    this.requiresPaidTier = false,
    this.installmentEligible = false,
  });

  bool get isShippable => fulfillment.contains('delivery');
}

const ListingTemplate _standardPhysical = ListingTemplate(
  id: 'standard_physical',
  categories: [
    'Electronics', 'Fashion', 'Home & Garden', 'Beauty',
    'Sports', 'Books', 'Toys', 'Health', 'Automotive', 'Other',
    // Cooked meals are sold each, not by weight — so not the 'fresh' template.
    'Restaurant Food',
  ],
  pricingUnits: ['each'],
  stockModel: StockModel.quantity,
  fulfillment: ['delivery', 'pickup'],
  transactionMode: 'checkout',
);

const ListingTemplate _fresh = ListingTemplate(
  id: 'fresh',
  categories: ['Meat & Seafood', 'Fresh Produce', 'Food & Beverages'],
  pricingUnits: ['kg', 'bundle', 'piece'],
  stockModel: StockModel.quantity,
  fulfillment: ['delivery', 'pickup'],
  transactionMode: 'checkout',
);

const ListingTemplate _bigTicket = ListingTemplate(
  id: 'big_ticket',
  categories: ['Vehicles', 'Appliances', 'Furniture'],
  pricingUnits: ['each'],
  stockModel: StockModel.quantity,
  fulfillment: ['pickup', 'delivery'],
  transactionMode: 'checkout',
  requiresPaidTier: true,
  installmentEligible: true,
  specFields: [
    SpecField('model', 'Model / Variant'),
    SpecField('year', 'Year'),
    SpecField('features', 'Key Features'),
  ],
);

const ListingTemplate _service = ListingTemplate(
  id: 'service',
  categories: ['Services'],
  pricingUnits: ['per_service', 'hourly', 'quote'],
  stockModel: StockModel.none,
  fulfillment: ['onsite'],
  transactionMode: 'inquiry',
  requiresPaidTier: true,
  specFields: [
    SpecField('coverageArea', 'Coverage Area'),
    SpecField('duration', 'Typical Duration'),
  ],
);

const List<ListingTemplate> kListingTemplates = [
  _standardPhysical, _fresh, _bigTicket, _service,
];

/// Total function: every category maps to exactly one template.
/// Unknown / empty categories fall back to standard_physical (never throws).
ListingTemplate resolveTemplate(String category) {
  final c = category.trim().toLowerCase();
  for (final t in kListingTemplates) {
    if (t.categories.any((cat) => cat.toLowerCase() == c)) return t;
  }
  return _standardPhysical;
}
