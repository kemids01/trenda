// lib/features/checkout/presentation/promo_code_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/design_system.dart';
import '../providers/promo_provider.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class PromoCodeWidget extends ConsumerStatefulWidget {
  final double orderTotal;

  const PromoCodeWidget({super.key, required this.orderTotal});

  @override
  ConsumerState<PromoCodeWidget> createState() => _PromoCodeWidgetState();
}

class _PromoCodeWidgetState extends ConsumerState<PromoCodeWidget> {
  final _controller = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promoState = ref.watch(promoProvider);

    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_offer_outlined, color: AppColors.primary),
                    AppSpacing.horizontalSM,
                    Text('Promo Code', style: AppTypography.titleSmall),
                  ],
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          // Applied coupon display
          if (promoState.appliedCode != null) ...[
            AppSpacing.verticalSM,
            Container(
              padding: AppSpacing.paddingSM,
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: AppSpacing.borderRadiusSM,
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 18),
                  AppSpacing.horizontalSM,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          promoState.appliedCode!,
                          style: AppTypography.labelLarge,
                        ),
                        Text(
                          'Coupon applied',
                          style: AppTypography.asSecondary(
                              AppTypography.labelSmall),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-₱${promoState.discount.toStringAsFixed(2)}',
                    style: AppTypography.withColor(
                      AppTypography.titleSmall,
                      AppColors.success,
                    ),
                  ),
                  AppSpacing.horizontalXS,
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      ref.read(promoProvider.notifier).removePromoCode();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],

          // Input field (when expanded and no coupon applied)
          if (_isExpanded && promoState.appliedCode == null) ...[
            AppSpacing.verticalMD,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter promo code',
                      isDense: true,
                      contentPadding: AppSpacing.paddingSM,
                      errorText: promoState.error,
                    ),
                  ),
                ),
                AppSpacing.horizontalSM,
                ElevatedButton(
                  onPressed: promoState.isLoading
                      ? null
                      : () => TapGuard.run('promo_code.apply@132', () async {
                          final success = await ref
                              .read(promoProvider.notifier)
                              .applyPromoCode(
                                  _controller.text, widget.orderTotal);
                          if (success) {
                            _controller.clear();
                          }
                        }),
                  child: promoState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
