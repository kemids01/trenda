// Compact per-unit price suffix for storefront listings.
// Fresh/by-weight (kg/bundle/piece) and service listings show their unit next
// to the price (e.g. "₱145 / kg"); standard 'each' listings show nothing.
String pricingUnitSuffix(String pricingUnit) {
  switch (pricingUnit) {
    case 'kg':
      return ' / kg';
    case 'bundle':
      return ' / bundle';
    case 'piece':
      return ' / piece';
    case 'per_service':
      return ' / service';
    case 'hourly':
      return ' / hr';
    case 'each':
    case 'quote':
    default:
      return '';
  }
}
