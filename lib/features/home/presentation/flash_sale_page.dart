// lib/features/home/presentation/flash_sale_page.dart
// ⚡ Flash Sale "See all" (/flash-sale): a big countdown hero for the sale
// ending soonest, then every live deal as a grid — sale by sale when more than
// one is running. Same feed as the Shop tab band (flash_sale_provider.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/flash_sale_provider.dart';
import '../utils/flash_sale_logic.dart' show FlashPalette;
import 'widgets/flash_sale_band.dart';

class FlashSalePage extends ConsumerWidget {
  const FlashSalePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(flashSaleFeedProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The bar takes the colours of the sale ending soonest (or the one coming up).
    final feedNow = async.valueOrNull;
    final barPalette = (feedNow?.featured ?? feedNow?.upcoming)?.palette ?? FlashPalette.fallback;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0E1116) : const Color(0xFFFFF4EC),
      body: RefreshIndicator(
        color: barPalette.from,
        onRefresh: () async {
          ref.invalidate(flashSaleFeedProvider);
          await ref.read(flashSaleFeedProvider.future);
        },
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: barPalette.from,
            foregroundColor: barPalette.ink,
            title: FlashPaletteScope(
              palette: barPalette,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt_rounded, color: barPalette.accent),
                const SizedBox(width: 4),
                const FlashWordmark(size: 19),
              ]),
            ),
          ),
          ...async.when(
            loading: () =>
                [const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kFlashRed)))],
            error: (_, __) => [_empty(context)],
            data: (feed) {
              if (feed.sales.isEmpty) {
                return [
                  if (feed.upcoming != null) _hero(ref, feed.upcoming!, upcoming: true),
                  _empty(context, upcoming: feed.upcoming != null),
                ];
              }
              return [
                for (final s in feed.sales) ...[
                  _hero(ref, s),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.58,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => LayoutBuilder(
                          builder: (context, box) => FlashDealCard(
                            item: s.items[i],
                            width: box.maxWidth,
                            onTap: () => context.push('/product/${s.items[i].productId}'),
                          ),
                        ),
                        childCount: s.items.length,
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Text(
                      'Flash prices last until the timer ends or the deal sells out. Flash items are checked out '
                      'on their own — one seller per order — and the price is confirmed when you place the order.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                    ),
                  ),
                ),
              ];
            },
          ),
        ]),
      ),
    );
  }

  Widget _hero(WidgetRef ref, FlashSale s, {bool upcoming = false}) => SliverToBoxAdapter(
        child: FlashPaletteScope(
          palette: s.palette,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: FlashBackdrop(
              dim: upcoming,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(children: [
                  const PulsingBolt(size: 30),
                  const SizedBox(height: 10),
                  Text(s.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: s.palette.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.5)),
                  if (s.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(s.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: s.palette.ink.withValues(alpha: 0.9), fontSize: 12.5)),
                  ],
                  const SizedBox(height: 14),
                  Text(upcoming ? 'STARTS IN' : 'ENDS IN',
                      style: TextStyle(
                          color: s.palette.accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  FlashCountdown(
                    target: upcoming ? s.startsAt : s.endsAt,
                    tile: 40,
                    onDone: () => ref.invalidate(flashSaleFeedProvider),
                  ),
                  if (!upcoming) ...[
                    const SizedBox(height: 10),
                    Text('${s.items.length} deals · ${s.items.where((i) => !i.soldOut).length} still available',
                        style: TextStyle(
                            color: s.palette.ink.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _empty(BuildContext context, {bool upcoming = false}) => SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.bolt_rounded, size: 64, color: kFlashOrange.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(upcoming ? 'Deals drop when the timer hits zero.' : 'No flash sale right now.',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Check the Shop tab — new flash deals appear there first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ]),
        ),
      );
}
