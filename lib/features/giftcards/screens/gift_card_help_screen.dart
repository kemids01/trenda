// trenda_frontend/lib/features/giftcards/screens/gift_card_help_screen.dart
//
// How gift cards work, for the customer.
//
// This is deliberately NOT the staff guide. It answers what a buyer needs — what the card pays
// for, why they still hand the rider cash, what happens to leftover balance, what a cancelled
// order does — and says nothing about rider settlement, remittance credits, vendor payment or
// Trenda's liability. Those are internal mechanics; surfacing them here would only confuse.
//
// Staff version: trenda_admin nav 13 ▸ GUIDE tab.
import 'package:flutter/material.dart';

class GiftCardHelpScreen extends StatelessWidget {
  const GiftCardHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('How gift cards work')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _Lead(theme: theme),
          const SizedBox(height: 28),

          const _Step(
            number: '1',
            title: 'Add your card',
            body: 'Tap "Add a card" and enter the code from your gift card. The balance is then '
                'yours to spend.\n\nAdding a card is permanent — once a code is on your account it '
                'cannot be moved to anyone else. If you meant to give it to someone, pass on the '
                'code rather than adding it yourself.',
          ),
          const _Step(
            number: '2',
            title: 'Use it at checkout',
            body: 'Pick your card in the Gift card section at checkout. It pays for the items in '
                'your order, and you will see exactly how much is left to pay in cash before you '
                'place it.',
          ),
          const _Step(
            number: '3',
            title: 'Pay the delivery fee at the door',
            body: 'Your rider always collects the delivery fee in cash when your order arrives, '
                'even when a gift card covers all of your items. Have that amount ready.',
            emphasis: true,
          ),

          const SizedBox(height: 8),
          _Divider(theme: theme),
          const SizedBox(height: 8),

          Text('Good to know', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),

          const _Faq(
            question: 'What if my card is worth more than my order?',
            answer: 'The rest stays on your card for next time. A ₱1,000 card used on ₱300 of '
                'items leaves ₱700 available.',
          ),
          const _Faq(
            question: 'What if my order costs more than my card?',
            answer: 'Your card pays what it can and you pay the difference in cash at the door, '
                'along with the delivery fee.',
          ),
          const _Faq(
            question: 'Can I use two gift cards on one order?',
            answer: 'Not on the same order — one card per order. You can use your other cards on '
                'later orders.',
          ),
          const _Faq(
            question: 'What happens if my order is cancelled?',
            answer: 'The amount goes back onto the same gift card, and you can spend it again. '
                'You will see it in the card\'s history as "Returned".',
          ),
          const _Faq(
            question: 'My code says it is already claimed',
            answer: 'Someone else has already added that code to their account. A gift card can '
                'only be claimed once, so contact whoever gave you the card.',
          ),
          const _Faq(
            question: 'My code is not working',
            answer: 'Check the characters carefully — codes are not case sensitive but a single '
                'wrong character will not match. If it still fails, the card may have expired.',
          ),
          const _Faq(
            question: 'Do gift cards expire?',
            answer: 'Yes. Each card shows its "Use by" date in your Gift Cards list. Any balance '
                'left after that date can no longer be spent, so use it before then.',
          ),
          const _Faq(
            question: 'Can I buy a gift card?',
            answer: 'Not at the moment. Trenda gift cards come from promos, events and customer '
                'support.',
          ),
          const _Faq(
            question: 'Can I turn my balance into cash?',
            answer: 'No — a gift card balance can only be spent on items in the app.',
          ),
        ],
      ),
    );
  }
}

class _Lead extends StatelessWidget {
  final ThemeData theme;
  const _Lead({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.card_giftcard,
            color: theme.colorScheme.onPrimaryContainer,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A gift card pays for your items',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add a code, then spend the balance on anything you order. The delivery fee is '
                  'always paid in cash when your order arrives.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.5,
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number, title, body;
  final bool emphasis;
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: emphasis
                  ? theme.colorScheme.tertiaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: emphasis
                    ? theme.colorScheme.onTertiaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.55,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  final String question, answer;
  const _Faq({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          question,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          Text(
            answer,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.55,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final ThemeData theme;
  const _Divider({required this.theme});

  @override
  Widget build(BuildContext context) => Divider(color: theme.dividerColor);
}
