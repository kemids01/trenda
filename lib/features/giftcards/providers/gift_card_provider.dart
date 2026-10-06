// trenda_frontend/lib/features/giftcards/providers/gift_card_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/gift_card_repository.dart';
import '../logic/gift_card_support.dart';

final giftCardRepositoryProvider =
    Provider<GiftCardRepository>((ref) => GiftCardRepository());

/// Gift cards this customer has claimed.
final myGiftCardsProvider = FutureProvider.autoDispose<List<GiftCard>>((ref) async {
  final repo = ref.watch(giftCardRepositoryProvider);
  final rows = await repo.getMyCards();
  return rows.map(GiftCard.fromJson).toList();
});

/// The cards worth offering at checkout, biggest balance first.
final spendableGiftCardsProvider =
    FutureProvider.autoDispose<List<GiftCard>>((ref) async {
  final cards = await ref.watch(myGiftCardsProvider.future);
  return spendableCards(cards);
});

/// The card the customer picked at checkout, by code. Null means pay the full amount in cash.
final selectedGiftCardCodeProvider = StateProvider<String?>((ref) => null);
