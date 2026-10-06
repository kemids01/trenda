// trenda_frontend/lib/features/wallet/screens/customer_wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/customer_wallet_provider.dart';
import 'package:trenda_shared/core/timezone.dart';

class CustomerWalletScreen extends ConsumerWidget {
  const CustomerWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(customerWalletProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trenda Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Recharge History',
            onPressed: () => _showRechargeHistory(context, ref),
          ),
        ],
      ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text('Failed to load wallet', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(customerWalletProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (wallet) {
          final balance = (wallet['balance'] ?? 0).toDouble();
          final transactions =
              List<Map<String, dynamic>>.from(wallet['transactions'] ?? []);
          final stats = wallet['stats'] as Map<String, dynamic>? ?? {};

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerWalletProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balance Card
                _BalanceCard(
                  balance: balance,
                  totalRecharges: (stats['totalRecharges'] ?? 0).toInt(),
                  totalSpent: (stats['totalSpent'] ?? 0).toDouble(),
                  isDark: isDark,
                  onRecharge: () => context.push('/wallet/recharge'),
                ),
                const SizedBox(height: 24),

                // Recent Transactions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Transactions',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (transactions.isNotEmpty)
                      TextButton(
                        onPressed: () => _showAllTransactions(context, ref),
                        child: const Text('View All'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (transactions.isEmpty)
                  _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: 'No transactions yet',
                    subMessage: 'Recharge your wallet to get started',
                  )
                else
                  ...transactions.map((tx) => _TransactionTile(
                        transaction: tx,
                        isDark: isDark,
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRechargeHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => _RechargeHistorySheet(
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showAllTransactions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => _AllTransactionsSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// ============================================================================
// BALANCE CARD
// ============================================================================

class _BalanceCard extends StatelessWidget {
  final double balance;
  final int totalRecharges;
  final double totalSpent;
  final bool isDark;
  final VoidCallback onRecharge;

  const _BalanceCard({
    required this.balance,
    required this.totalRecharges,
    required this.totalSpent,
    required this.isDark,
    required this.onRecharge,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A237E), const Color(0xFF0D47A1)]
              : [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              const Text(
                'Trenda Wallet',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            formatter.format(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(
                label: 'Recharges',
                value: '$totalRecharges',
                icon: Icons.add_circle_outline,
              ),
              const SizedBox(width: 24),
              _MiniStat(
                label: 'Total Spent',
                value: formatter.format(totalSpent),
                icon: Icons.shopping_bag_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRecharge,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Recharge Wallet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// TRANSACTION TILE
// ============================================================================

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final bool isDark;

  const _TransactionTile({required this.transaction, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final type = transaction['type'] ?? 'credit';
    final category = transaction['category'] ?? '';
    final amount = (transaction['amount'] ?? 0).toDouble();
    final description = transaction['description'] ?? '';
    final createdAt = transaction['createdAt'] != null
        ? DateTime.tryParse(transaction['createdAt'].toString())
        : null;

    final isCredit = type == 'credit';
    final formatter = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    IconData icon;
    Color iconColor;
    switch (category) {
      case 'recharge':
        icon = Icons.add_circle;
        iconColor = Colors.green;
        break;
      case 'purchase':
        icon = Icons.shopping_cart;
        iconColor = Colors.orange;
        break;
      case 'refund':
        icon = Icons.replay;
        iconColor = Colors.blue;
        break;
      default:
        icon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;
        iconColor = isCredit ? Colors.green : Colors.red;
    }

    return Card(
      elevation: 0,
      color: isDark ? Colors.grey[850] : Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          description,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          createdAt != null
              ? DateFormat('MMM d, y · h:mm a').formatPh(createdAt.toLocal())
              : '',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: Text(
          '${isCredit ? '+' : '-'}${formatter.format(amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isCredit ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subMessage;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(subMessage,
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ============================================================================
// RECHARGE HISTORY BOTTOM SHEET
// ============================================================================

class _RechargeHistorySheet extends ConsumerWidget {
  final ScrollController scrollController;

  const _RechargeHistorySheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechargeHistoryProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Recharge History',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (state.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.error!),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(rechargeHistoryProvider.notifier)
                          .loadHistory(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (state.requests.isEmpty)
            const Expanded(
              child: Center(child: Text('No recharge requests yet')),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.requests.length,
                itemBuilder: (_, i) {
                  final req = state.requests[i];
                  return _RechargeRequestCard(request: req);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RechargeRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;

  const _RechargeRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final status = request['status'] ?? 'pending';
    final amount = (request['amount'] ?? 0).toDouble();
    final ref = request['referenceNumber'] ?? '';
    final createdAt = request['createdAt'] != null
        ? DateTime.tryParse(request['createdAt'].toString())
        : null;
    final formatter = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(formatter.format(amount),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ref, style: const TextStyle(fontSize: 12)),
            if (createdAt != null)
              Text(
                DateFormat('MMM d, y · h:mm a').formatPh(createdAt.toLocal()),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toString().toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ALL TRANSACTIONS BOTTOM SHEET
// ============================================================================

class _AllTransactionsSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _AllTransactionsSheet({required this.scrollController});

  @override
  ConsumerState<_AllTransactionsSheet> createState() =>
      _AllTransactionsSheetState();
}

class _AllTransactionsSheetState extends ConsumerState<_AllTransactionsSheet> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final repo = ref.read(customerWalletRepositoryProvider);
      final result = await repo.getTransactions(limit: 50);
      setState(() {
        _transactions =
            List<Map<String, dynamic>>.from(result['transactions'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('All Transactions',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!)))
          else if (_transactions.isEmpty)
            const Expanded(
              child: Center(child: Text('No transactions yet')),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _transactions.length,
                itemBuilder: (_, i) => _TransactionTile(
                  transaction: _transactions[i],
                  isDark: isDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
