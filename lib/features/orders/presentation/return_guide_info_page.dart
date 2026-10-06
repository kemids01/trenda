import 'package:flutter/material.dart';

/// Customer-facing guide explaining the return and exchange process.
/// Can be opened from the return request page or order details.
class ReturnGuideInfoPage extends StatelessWidget {
  const ReturnGuideInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          'Returns & Exchanges Guide',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero header
            _buildHeroCard(),
            const SizedBox(height: 20),

            // Section: Return vs Exchange
            _buildSectionTitle('What\'s the difference?'),
            const SizedBox(height: 12),
            _buildComparisonCards(),
            const SizedBox(height: 24),

            // Section: How returns work
            _buildSectionTitle('How Returns Work'),
            const SizedBox(height: 12),
            _buildReturnSteps(),
            const SizedBox(height: 24),

            // Section: How exchanges work
            _buildSectionTitle('How Exchanges Work'),
            const SizedBox(height: 12),
            _buildExchangeSteps(),
            const SizedBox(height: 24),

            // Section: Eligible reasons
            _buildSectionTitle('Eligible Reasons'),
            const SizedBox(height: 12),
            _buildReasonsCard(),
            const SizedBox(height: 24),

            // Section: Delivery fees
            _buildSectionTitle('Delivery Fees'),
            const SizedBox(height: 12),
            _buildFeesCard(),
            const SizedBox(height: 24),

            // Section: Timeline
            _buildSectionTitle('Processing Timeline'),
            const SizedBox(height: 12),
            _buildTimelineCard(),
            const SizedBox(height: 24),

            // FAQ
            _buildSectionTitle('Frequently Asked Questions'),
            const SizedBox(height: 12),
            _buildFAQ(),
            const SizedBox(height: 32),

            // Tips
            _buildTipsCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_return, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Easy Returns & Exchanges',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Not satisfied? We\'ve got you covered. Request a return for a refund or exchange the same product.',
                  style: TextStyle(
                    color: Colors.white.withAlpha(216),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildComparisonCards() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withAlpha(50)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.assignment_return, size: 24, color: Colors.blue[700]),
                ),
                const SizedBox(height: 10),
                Text('Return', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  'Send back the product and get a refund to your original payment method.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withAlpha(50)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.swap_horiz, size: 24, color: Colors.green[700]),
                ),
                const SizedBox(height: 10),
                Text('Exchange', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  'Get the exact same product as a replacement. No refund needed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReturnSteps() {
    final steps = [
      _StepData('Submit Request', 'Choose "Return & Refund", select a reason, and upload photos of the item.', Icons.edit_note, Colors.blue),
      _StepData('Vendor Review', 'The vendor will review your request within 1–3 business days.', Icons.store, Colors.orange),
      _StepData('Rider Pickup', 'Once approved, a rider will be assigned to pick up the item from your address.', Icons.delivery_dining, Colors.purple),
      _StepData('Refund Processed', 'After the vendor receives and inspects the item, your refund will be processed.', Icons.payments, Colors.green),
    ];

    return _buildStepsList(steps);
  }

  Widget _buildExchangeSteps() {
    final steps = [
      _StepData('Submit Request', 'Choose "Exchange (Same Product)", select a vendor-fault reason, and upload evidence.', Icons.edit_note, Colors.blue),
      _StepData('Vendor Approval', 'The vendor checks stock availability. If out of stock, it falls back to a refund.', Icons.store, Colors.orange),
      _StepData('Rider Picks Up', 'The original delivery rider picks up the damaged/defective item from you.', Icons.delivery_dining, Colors.purple),
      _StepData('Return to Vendor', 'The rider delivers the item back to the vendor for inspection.', Icons.storefront, Colors.indigo),
      _StepData('Replacement Delivery', 'The rider picks up your brand new replacement and delivers it to you.', Icons.local_shipping, Colors.teal),
      _StepData('Complete', 'Once you receive the replacement, the exchange is marked as complete.', Icons.verified, Colors.green),
    ];

    return _buildStepsList(steps);
  }

  Widget _buildStepsList(List<_StepData> steps) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: step.color.withAlpha(25),
                      shape: BoxShape.circle,
                      border: Border.all(color: step.color.withAlpha(76), width: 1.5),
                    ),
                    child: Icon(step.icon, size: 16, color: step.color),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 32,
                      color: step.color.withAlpha(38),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.title,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: step.color)),
                      const SizedBox(height: 2),
                      Text(step.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReasonsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReasonRow('Defective Product', 'Item does not function properly', true, true),
          _buildReasonRow('Damaged in Transit', 'Item was damaged during delivery', true, true),
          _buildReasonRow('Wrong Item', 'Received a different product', true, true),
          _buildReasonRow('Not as Described', 'Product does not match listing', true, true),
          const Divider(height: 16),
          _buildReasonRow('Size Issue', 'Product size is incorrect', true, false),
          _buildReasonRow('Quality Issue', 'Product quality not as expected', true, false),
          _buildReasonRow('Other', 'Other reason not listed above', true, false),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.amber[800]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '"Changed Mind" is not eligible for returns. Only reasons related to product issues are accepted.',
                    style: TextStyle(fontSize: 10, color: Colors.amber[900], height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonRow(String reason, String desc, bool returnEligible, bool exchangeEligible) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                Text(desc, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ),
          _eligibilityChip('Return', returnEligible),
          const SizedBox(width: 4),
          _eligibilityChip('Exchange', exchangeEligible),
        ],
      ),
    );
  }

  Widget _eligibilityChip(String label, bool eligible) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: eligible ? Colors.green.withAlpha(20) : Colors.grey.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            eligible ? Icons.check_circle : Icons.cancel,
            size: 10,
            color: eligible ? Colors.green[700] : Colors.grey[500],
          ),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: eligible ? Colors.green[700] : Colors.grey[500],
              )),
        ],
      ),
    );
  }

  Widget _buildFeesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who pays for return shipping?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 12),
          _buildFeeRow(
            Icons.store,
            'Vendor Pays',
            'If the product is defective, damaged, wrong item, or not as described — the vendor covers the delivery fee.',
            Colors.green,
          ),
          const SizedBox(height: 10),
          _buildFeeRow(
            Icons.person,
            'Customer Pays',
            'For other reasons (size issue, quality), the return delivery fee is deducted from your refund amount.',
            Colors.orange,
          ),
          const SizedBox(height: 10),
          _buildFeeRow(
            Icons.swap_horiz,
            'Exchange Fee',
            'Exchanges require 2 trips (pickup + new delivery), so the fee is 1.5× the standard delivery fee.',
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(IconData icon, String title, String desc, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTimelineRow('Request Window', '7 days from delivery', Icons.timer),
          const SizedBox(height: 8),
          _buildTimelineRow('Vendor Review', '1–3 business days', Icons.store),
          const SizedBox(height: 8),
          _buildTimelineRow('Rider Pickup', 'Within 1–2 days of approval', Icons.delivery_dining),
          const SizedBox(height: 8),
          _buildTimelineRow('Refund Processing', '3–7 business days after inspection', Icons.payments),
          const SizedBox(height: 8),
          _buildTimelineRow('Exchange Delivery', 'Same day as pickup (if in stock)', Icons.swap_horiz),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(String label, String duration, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.indigo.withAlpha(15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(duration,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.indigo[700])),
        ),
      ],
    );
  }

  Widget _buildFAQ() {
    final faqs = [
      _FAQ(
        'Can I exchange for a different product?',
        'No. Exchanges are only available for the exact same product. If you want a different product, please return for a refund and place a new order.',
      ),
      _FAQ(
        'What if the replacement is out of stock?',
        'If the product is out of stock at the time of vendor approval, the exchange will automatically fall back to a refund.',
      ),
      _FAQ(
        'Who will pick up my return?',
        'The same rider who delivered your order will be auto-assigned to pick up your return. This ensures familiarity with your address.',
      ),
      _FAQ(
        'Can I cancel a return request?',
        'You can cancel a return request before the vendor approves it. Once approved, the process cannot be reversed.',
      ),
      _FAQ(
        'What condition should the product be in?',
        'The product should be in its original packaging where possible. For defective/damaged items, keep the item as-is to show the issue.',
      ),
      _FAQ(
        'Do I need to upload photos?',
        'Photos are required for all return and exchange requests. They help the vendor verify the issue and speed up approval.',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: faqs.asMap().entries.map((entry) {
          final index = entry.key;
          final faq = entry.value;
          return Column(
            children: [
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                title: Text(
                  faq.question,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                leading: Icon(Icons.help_outline, size: 18, color: Colors.blue[400]),
                children: [
                  Text(
                    faq.answer,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                  ),
                ],
              ),
              if (index < faqs.length - 1)
                Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text('Tips for a Smooth Return',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.green[800])),
            ],
          ),
          const SizedBox(height: 10),
          _buildTipItem('Take clear photos of the issue — well-lit, multiple angles.'),
          _buildTipItem('Include the original packaging and accessories if possible.'),
          _buildTipItem('Submit your request as soon as possible (within 7 days).'),
          _buildTipItem('Be available at your delivery address for rider pickup.'),
          _buildTipItem('Add detailed notes explaining the problem.'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: Colors.green[700], height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class _StepData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  _StepData(this.title, this.description, this.icon, this.color);
}

class _FAQ {
  final String question;
  final String answer;

  _FAQ(this.question, this.answer);
}
