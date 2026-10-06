import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/installment_payment_provider.dart';
import '../providers/installment_provider.dart';
import '../../auth/data/providers.dart';
import 'package:trenda_shared/core/timezone.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class InstallmentPaymentScreen extends ConsumerStatefulWidget {
  final String applicationId;

  const InstallmentPaymentScreen({super.key, required this.applicationId});

  @override
  ConsumerState<InstallmentPaymentScreen> createState() =>
      _InstallmentPaymentScreenState();
}

class _InstallmentPaymentScreenState
    extends ConsumerState<InstallmentPaymentScreen> {
  bool _isProcessing = false;
  final formatter = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final paymentAsync =
        ref.watch(installmentPaymentProvider(widget.applicationId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Installment Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .invalidate(installmentPaymentProvider(widget.applicationId)),
          ),
        ],
      ),
      body: paymentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('Could not load payment schedule',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(e.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(
                    installmentPaymentProvider(widget.applicationId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No payment data available'));
          }

          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          final schedule =
              (data['schedule'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final status = data['status'] as String? ?? 'awaiting_downpayment';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card
                _buildSummaryCard(summary, status, theme),
                const SizedBox(height: 20),

                // Progress
                _buildProgressBar(summary, theme),
                const SizedBox(height: 20),

                // Schedule
                Text('Payment Schedule',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...schedule
                    .map((entry) => _buildScheduleItem(entry, status, theme)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
      Map<String, dynamic> summary, String status, ThemeData theme) {
    final totalAmount = (summary['totalAmount'] ?? 0).toDouble();
    final totalPaid = (summary['totalPaid'] ?? 0).toDouble();
    final remaining = (summary['remainingBalance'] ?? 0).toDouble();
    final paidCount = summary['paidCount'] ?? 0;
    final totalInstallments = summary['totalInstallments'] ?? 0;
    final isCompleted = summary['isCompleted'] ?? false;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'COMPLETED';
        statusIcon = Icons.check_circle;
        break;
      case 'active':
        statusColor = Colors.blue;
        statusLabel = 'ACTIVE';
        statusIcon = Icons.play_circle_fill;
        break;
      case 'defaulted':
        statusColor = Colors.red;
        statusLabel = 'DEFAULTED';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'AWAITING DOWN PAYMENT';
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.8), statusColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Row(
            children: [
              Icon(statusIcon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(statusLabel,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),

          // Remaining balance
          Text(isCompleted ? 'Fully Paid' : 'Remaining',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(formatter.format(remaining),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Bottom stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryChip('Total', formatter.format(totalAmount)),
              _summaryChip('Paid', formatter.format(totalPaid)),
              _summaryChip('Progress', '$paidCount / $totalInstallments'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }

  Widget _buildProgressBar(Map<String, dynamic> summary, ThemeData theme) {
    final paidCount = (summary['paidCount'] ?? 0) as int;
    final total = (summary['totalInstallments'] ?? 1) as int;
    final progress = total > 0 ? paidCount / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Payment Progress',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text('${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blue[700])),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.green : Colors.blue),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleItem(
      Map<String, dynamic> entry, String paymentStatus, ThemeData theme) {
    final number = entry['installmentNumber'] ?? 0;
    final amount = (entry['amount'] ?? 0).toDouble();
    final status = entry['status'] ?? 'pending';
    final dueDate = entry['dueDate'] != null
        ? DateTime.tryParse(entry['dueDate'].toString())
        : null;
    final paidAt = entry['paidAt'] != null
        ? DateTime.tryParse(entry['paidAt'].toString())
        : null;
    final isDownPayment = number == 0;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'paid':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'overdue':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      case 'waived':
        statusColor = Colors.purple;
        statusIcon = Icons.remove_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked;
    }

    final canPay = status == 'pending' || status == 'overdue';
    final isNextPayable = canPay &&
        ((isDownPayment && paymentStatus == 'awaiting_downpayment') ||
            (!isDownPayment && paymentStatus == 'active'));

    return Card(
      elevation: isNextPayable ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNextPayable
            ? BorderSide(color: Colors.blue.withOpacity(0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDownPayment ? 'Down Payment' : 'Installment #$number',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (dueDate != null)
                    Text(
                      status == 'paid' && paidAt != null
                          ? 'Paid ${DateFormat('MMM d, y').formatPh(paidAt.toLocal())}'
                          : 'Due ${DateFormat('MMM d, y').formatPh(dueDate.toLocal())}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            status == 'overdue' ? Colors.red : Colors.grey[600],
                      ),
                    ),
                  if (status == 'waived')
                    Text('Waived by admin',
                        style:
                            TextStyle(fontSize: 11, color: Colors.purple[300])),
                ],
              ),
            ),

            // Amount + action
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatter.format(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: status == 'paid'
                        ? Colors.green
                        : status == 'waived'
                            ? Colors.purple
                            : null,
                    decoration:
                        status == 'waived' ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (isNextPayable) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => TapGuard.run('installment.pay:$number',
                              () => isDownPayment
                                  ? _payDownPayment()
                                  : _payInstallment(number)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(isDownPayment ? 'Pay Now' : 'Pay'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _payDownPayment() async {
    final confirm = await _showConfirmDialog('Pay Down Payment?',
        'This will debit the down payment amount from your Trenda Wallet.');
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(installmentRepositoryProvider);
      final user = ref.read(authNotifierProvider).user;
      if (user == null) throw Exception('Not authenticated');
      final token = await user.getIdToken();

      await repo.payDownPayment(widget.applicationId, token!);
      ref.invalidate(installmentPaymentProvider(widget.applicationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('✅ Down payment successful! Installment is now active.'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _payInstallment(int number) async {
    final confirm = await _showConfirmDialog('Pay Installment #$number?',
        'This will debit the installment amount from your Trenda Wallet.');
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(installmentRepositoryProvider);
      final user = ref.read(authNotifierProvider).user;
      if (user == null) throw Exception('Not authenticated');
      final token = await user.getIdToken();

      await repo.payInstallment(widget.applicationId, token!,
          installmentNumber: number);
      ref.invalidate(installmentPaymentProvider(widget.applicationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Payment successful!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
