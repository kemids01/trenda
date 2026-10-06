// trenda_frontend/lib/features/giftcards/screens/gift_cards_screen.dart
//
// The customer's gift cards: claim a code, see what each is worth, and read where it went.
// Trenda funds every card — customers cannot buy them, so the empty state explains where they
// come from rather than offering a purchase that does not exist.
//
// Canonical reference: trenda_backend/docs/GIFT_CARDS.md
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../logic/gift_card_support.dart';
import '../providers/gift_card_provider.dart';
import 'package:trenda_shared/core/timezone.dart';
import 'package:trenda_shared/core/taps/taps.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);
final _dayMonth = DateFormat('d MMM yyyy');

class GiftCardsScreen extends ConsumerWidget {
  const GiftCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(myGiftCardsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'How gift cards work',
            onPressed: () => context.push('/gift-cards/help'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddGiftCardSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add a card'),
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(
          onRetry: () => ref.invalidate(myGiftCardsProvider),
        ),
        data: (cards) {
          if (cards.isEmpty) {
            return _EmptyState(onAdd: () => showAddGiftCardSheet(context, ref));
          }

          final spendable = spendableCards(cards);
          final usedUp = cards.where((c) => !c.isSpendable).toList();
          final totalAvailable =
              spendable.fold<double>(0, (sum, c) => sum + c.balance);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myGiftCardsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _TotalBanner(total: totalAvailable, count: spendable.length),
                const SizedBox(height: 20),
                if (spendable.isNotEmpty) ...[
                  Text('Available', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final c in spendable)
                    _GiftCardTile(
                      card: c,
                      onTap: () => _showCardDetail(context, c),
                    ),
                ],
                if (usedUp.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Used and expired', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final c in usedUp)
                    _GiftCardTile(
                      card: c,
                      onTap: () => _showCardDetail(context, c),
                    ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Gift cards pay for the items in your order. The delivery fee is always paid '
                  'in cash when your order arrives.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCardDetail(BuildContext context, GiftCard card) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CardDetailSheet(card: card),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Claim
// ─────────────────────────────────────────────────────────────────────────────

/// Claiming is permanent: the first account to enter a code owns it. The sheet says so before
/// the customer commits.
Future<void> showAddGiftCardSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AddGiftCardSheet(),
  );
}

class _AddGiftCardSheet extends ConsumerStatefulWidget {
  const _AddGiftCardSheet();

  @override
  ConsumerState<_AddGiftCardSheet> createState() => _AddGiftCardSheetState();
}

class _AddGiftCardSheetState extends ConsumerState<_AddGiftCardSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code printed on your gift card.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref.read(giftCardRepositoryProvider).claim(code);

    if (!mounted) return;

    if (result.ok) {
      ref.invalidate(myGiftCardsProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gift card added to your account')),
      );
      return;
    }

    setState(() {
      _submitting = false;
      _error = claimFailureMessage(result.failure!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a gift card', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Enter the code from your card. Once added it belongs to your account and cannot be '
            'moved to another.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
            onSubmitted: (_) => _submitting ? null : _submit(),
            inputFormatters: [UpperCaseFormatter()],
            decoration: InputDecoration(
              labelText: 'Gift card code',
              hintText: 'GIFT-XXXXXXXX',
              border: const OutlineInputBorder(),
              errorText: _error,
              errorMaxLines: 3,
              prefixIcon: const Icon(Icons.card_giftcard),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : () => TapGuard.run('gift_cards.submit', _submit),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add card'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Codes are stored uppercase; typing lowercase should still match.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  final double total;
  final int count;
  const _TotalBanner({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AVAILABLE TO SPEND',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _peso.format(total),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count == 1 ? 'across 1 card' : 'across $count cards',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftCardTile extends StatelessWidget {
  final GiftCard card;
  final VoidCallback onTap;
  const _GiftCardTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spendable = card.isSpendable;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: spendable
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.card_giftcard,
                  size: 20,
                  color: spendable
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.code,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const [],
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusLine(card),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _peso.format(card.balance),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: spendable
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (card.balance != card.value)
                    Text(
                      'of ${_peso.format(card.value)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLine(GiftCard card) {
  if (card.status == 'cancelled') return 'No longer valid';
  if (card.isExpired) return 'Expired';
  if (card.balance <= 0) return 'Fully used';
  final until = card.validUntil;
  return until == null ? 'Ready to use' : 'Use by ${_dayMonth.formatPh(until)}';
}

class _CardDetailSheet extends StatelessWidget {
  final GiftCard card;
  const _CardDetailSheet({required this.card});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.code, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _statusLine(card),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _peso.format(card.balance),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'of ${_peso.format(card.value)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: card.spentShare,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 20),
            Text('History', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (card.usage.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'You have not used this card yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: card.usage.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, i) {
                    final u = card.usage[card.usage.length - 1 - i];
                    final credit = u.amount > 0;
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.label, style: theme.textTheme.bodyMedium),
                              if (u.date != null)
                                Text(
                                  _dayMonth.formatPh(u.date!),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${credit ? '+' : '−'}${_peso.format(u.amount.abs())}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: credit ? Colors.green.shade700 : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.card_giftcard,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('No gift cards yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              // Customers cannot buy cards — online payment is not available — so say where they
              // actually come from rather than offering a purchase that does not exist.
              'Trenda gift cards come from promos, events and support. When you get a code, add '
              'it here and the balance is yours to spend.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add a card'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text("Couldn't load your gift cards", style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
