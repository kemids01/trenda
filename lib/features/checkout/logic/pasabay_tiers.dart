// lib/features/checkout/logic/pasabay_tiers.dart
// What checkout says about Pasabay batch tiers — derived from the tiers the server
// actually offers, never written by hand. Widget-free so it can be tested.

import '../data/pasabay_repository.dart';

/// Only the tiers a shopper can really pick.
///
/// `/api/pasabay/fee-preview` lists a barangay's `supportedBatchTypes`, which is
/// populated WITHOUT an active filter — so a tier an admin switched off (Super
/// Saver 10 was deactivated in prod 2026-09-15) was still offered at checkout.
List<PasabayFeePreview> activePreviews(List<PasabayFeePreview> previews) =>
    previews.where((p) => p.batchType?.active != false).toList();

/// '3 hours', '24 hours', '90 minutes'.
String waitLabel(int minutes) {
  if (minutes >= 60 && minutes % 60 == 0) {
    final h = minutes ~/ 60;
    return h == 1 ? '1 hour' : '$h hours';
  }
  return minutes == 1 ? '1 minute' : '$minutes minutes';
}

/// The bullet lines of the "How Pasabay batching works" guide.
///
/// This used to be a literal naming "Saver 5 … 2 hours" and "Super Saver 10 …
/// 24 hours": the first timeout was wrong (the tier waits 180 min) and the second
/// tier was no longer offered at all.
List<String> pasabayGuideLines(List<PasabayBatchTypeInfo> tiers) {
  return [
    'Orders from the same barangay are grouped into batches to save on delivery fees.',
    for (final t in tiers)
      '${t.name}: dispatches once ${t.targetOrders} orders join'
          '${t.timeoutMinutes != null && t.timeoutMinutes! > 0 ? '. Waits up to ${waitLabel(t.timeoutMinutes!)}.' : '.'}',
    'If the timer expires and the batch does not fill up, you will be asked '
        'whether to upgrade to Express or wait in a new batch.',
  ];
}
