import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/trenda_shared.dart';
import 'package:go_router/go_router.dart';
import '../providers/installment_provider.dart';
import 'package:intl/intl.dart';

class MyInstallmentsScreen extends ConsumerWidget {
  const MyInstallmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(customerApplicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: applicationsAsync.when(
        data: (applications) {
          if (applications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No applications yet.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/main'),
                    child: const Text('Browse Products'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customerApplicationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final app = applications[index];
                return _ApplicationCard(application: app);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text('$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(customerApplicationsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final InstallmentApplication application;

  const _ApplicationCard({required this.application});

  @override
  Widget build(BuildContext context) {
    final product = application.product;
    final plan = application.plan;
    final date = DateFormat('MMM dd, yyyy')
        .formatPh(application.createdAt ?? application.applicationDate);
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDetailsBottomSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    application.referenceNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey),
                  ),
                  _StatusBadge(status: application.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      image: _getProductImage(product) != null
                          ? DecorationImage(
                              image: NetworkImage(_getProductImage(product)!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: _getProductImage(product) == null
                        ? const Icon(Icons.shopping_bag_outlined)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.productName ??
                              product?['name'] ??
                              'Product',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text('${plan?.durationMonths ?? 0} months installment',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),

              // Financial preview
              if (application.financialSnapshot != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _financialChip(
                          'Down',
                          '₱${application.financialSnapshot!.downPayment?.toStringAsFixed(0) ?? '0'}',
                          theme),
                      Container(width: 1, height: 24, color: Colors.grey[300]),
                      _financialChip(
                          'Monthly',
                          '₱${application.financialSnapshot!.monthlyAmortization?.toStringAsFixed(0) ?? '0'}',
                          theme),
                      Container(width: 1, height: 24, color: Colors.grey[300]),
                      _financialChip(
                          'Total',
                          '₱${application.financialSnapshot!.totalAmountPayable?.toStringAsFixed(0) ?? '0'}',
                          theme),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Applied on $date',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Row(
                    children: [
                      // Show "View Payments" for approved/active/completed
                      if (['Approved', 'Active', 'Completed']
                          .contains(application.status)) ...[
                        GestureDetector(
                          onTap: () => context
                              .push('/installment/payments/${application.id}'),
                          child: Row(
                            children: [
                              Icon(Icons.payment,
                                  size: 14, color: Colors.green[700]),
                              const SizedBox(width: 2),
                              Text('Payments',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text('Details',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          )),
                      Icon(Icons.chevron_right,
                          size: 18, color: theme.colorScheme.primary),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _financialChip(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            )),
      ],
    );
  }

  String? _getProductImage(Map<String, dynamic>? product) {
    if (product == null) return null;
    if (product['mainImage'] != null) return product['mainImage'];
    if (product['images'] != null && (product['images'] as List).isNotEmpty) {
      return product['images'][0];
    }
    return null;
  }

  void _showDetailsBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final app = application;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Application Details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                    _StatusBadge(status: app.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(app.referenceNumber,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 20),

                // Financial Summary
                if (app.financialSnapshot != null) ...[
                  _sectionTitle('Financial Summary'),
                  const SizedBox(height: 8),
                  _detailCard([
                    _row('Product Price',
                        '₱${app.financialSnapshot!.productPrice?.toStringAsFixed(2) ?? '0'}'),
                    _row('Down Payment',
                        '₱${app.financialSnapshot!.downPayment?.toStringAsFixed(2) ?? '0'}'),
                    _row('Loan Term',
                        '${app.financialSnapshot!.loanTermMonths ?? 0} months'),
                    const Divider(height: 16),
                    _row('Monthly Due',
                        '₱${app.financialSnapshot!.monthlyAmortization?.toStringAsFixed(2) ?? '0'}',
                        bold: true),
                    _row('Interest',
                        '₱${app.financialSnapshot!.totalInterest?.toStringAsFixed(2) ?? '0'}'),
                    _row('Total Payable',
                        '₱${app.financialSnapshot!.totalAmountPayable?.toStringAsFixed(2) ?? '0'}',
                        bold: true),
                  ], theme),
                  const SizedBox(height: 16),
                ],

                // Status Timeline
                _sectionTitle('Status'),
                const SizedBox(height: 8),
                _detailCard([
                  _row('Current Status', app.status),
                  _row(
                      'Applied On',
                      DateFormat('MMM dd, yyyy HH:mm')
                          .formatPh(app.createdAt ?? app.applicationDate)),
                  if (app.decisionDate != null)
                    _row(
                        'Decision Date',
                        DateFormat('MMM dd, yyyy HH:mm')
                            .formatPh(app.decisionDate!)),
                ], theme),
                const SizedBox(height: 16),

                // Vendor Decision
                if (app.vendorDecision != null) ...[
                  _sectionTitle('Vendor Decision'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          _getStatusColor(app.vendorDecision!['decision'] ?? '')
                              .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(
                                app.vendorDecision!['decision'] ?? '')
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getDecisionIcon(
                                  app.vendorDecision!['decision'] ?? ''),
                              size: 18,
                              color: _getStatusColor(
                                  app.vendorDecision!['decision'] ?? ''),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              app.vendorDecision!['decision'] ?? 'N/A',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(
                                    app.vendorDecision!['decision'] ?? ''),
                              ),
                            ),
                          ],
                        ),
                        if (app.vendorDecision!['rejectionReasonText'] !=
                            null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Reason: ${app.vendorDecision!['rejectionReasonText']}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (app.vendorDecision!['vendorNotes'] != null &&
                            app.vendorDecision!['vendorNotes']
                                .toString()
                                .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Notes: ${app.vendorDecision!['vendorNotes']}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Product Info
                if (app.product != null) ...[
                  _sectionTitle('Product'),
                  const SizedBox(height: 8),
                  _detailCard([
                    _row('Name',
                        app.productName ?? app.product!['name'] ?? 'N/A'),
                    if (app.plan != null) ...[
                      _row('Duration', '${app.plan!.durationMonths} months'),
                      _row('Installment Price',
                          '₱${app.plan!.finalPrice.toStringAsFixed(2)}'),
                    ],
                  ], theme),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }

  Widget _detailCard(List<Widget> children, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      case 'Info Needed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getDecisionIcon(String decision) {
    switch (decision) {
      case 'Approved':
        return Icons.check_circle;
      case 'Rejected':
        return Icons.cancel;
      case 'Info Needed':
        return Icons.info;
      default:
        return Icons.pending;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Approved':
        color = Colors.green;
        break;
      case 'Rejected':
        color = Colors.red;
        break;
      case 'Pending':
        color = Colors.amber.shade800;
        break;
      case 'Info Needed':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
