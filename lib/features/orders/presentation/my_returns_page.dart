// lib/features/orders/presentation/my_returns_page.dart
// Customer's return/exchange tracking page

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../design_system/app_colors.dart';
import '../data/orders_repository.dart';
import 'return_detail_page.dart';
import 'return_guide_info_page.dart';
import 'package:trenda_shared/core/timezone.dart';

// =============================================================================
// PROVIDERS
// =============================================================================

final _myReturnsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, status) async {
  final repo = OrdersRepository();
  final raw = await repo.getMyReturns(status: status);
  return raw.cast<Map<String, dynamic>>();
});

// =============================================================================
// MY RETURNS PAGE
// =============================================================================

class MyReturnsPage extends ConsumerStatefulWidget {
  const MyReturnsPage({super.key});

  @override
  ConsumerState<MyReturnsPage> createState() => _MyReturnsPageState();
}

class _MyReturnsPageState extends ConsumerState<MyReturnsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentFilter;

  static const _tabs = [
    {'label': 'All', 'status': null},
    {'label': 'Pending', 'status': 'requested'},
    {'label': 'Processing', 'status': 'approved'},
    {'label': 'Completed', 'status': 'completed'},
    {'label': 'Rejected', 'status': 'rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentFilter = _tabs[_tabController.index]['status'];
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final returnsAsync = ref.watch(_myReturnsProvider(_currentFilter));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Returns & Exchanges'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Return Guide',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReturnGuideInfoPage()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t['label']?.toString() ?? 'All')).toList(),
        ),
      ),
      body: returnsAsync.when(
        data: (returns) => returns.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: () => ref.refresh(_myReturnsProvider(_currentFilter).future),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: returns.length,
                  itemBuilder: (context, index) =>
                      _ReturnCard(data: returns[index]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text('Failed to load returns',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(_myReturnsProvider(_currentFilter)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.assignment_return,
                    size: 64, color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),
              Text(
                _currentFilter == null
                    ? 'No returns yet'
                    : 'No ${_tabs[_tabController.index]['label']?.toString().toLowerCase()} returns',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Returns and exchanges will appear here',
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReturnGuideInfoPage()),
                ),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('How Returns Work'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withAlpha(80)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// RETURN CARD
// =============================================================================

class _ReturnCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReturnCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'requested';
    final type = data['type'] ?? 'return';
    final isExchange = type == 'exchange';
    final returnNumber = data['returnNumber'] ?? '';
    final orderNumber = data['orderNumber'] ?? '';
    final totalRefund = (data['totalRefund'] ?? 0).toDouble();
    final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final createdAt = DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now();
    final statusColor = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReturnDetailPage(returnData: data),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Return # + Type badge + Status
                Row(
                  children: [
                    Icon(
                      isExchange ? Icons.swap_horiz : Icons.assignment_return,
                      size: 20,
                      color: isExchange ? Colors.green : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        returnNumber.isNotEmpty ? returnNumber : 'Return',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),

                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isExchange
                            ? Colors.green.withAlpha(20)
                            : AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isExchange ? 'EXCHANGE' : 'RETURN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isExchange
                              ? Colors.green[700]
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withAlpha(60)),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Order reference + date
                Row(
                  children: [
                    Icon(Icons.receipt_outlined,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('Order: $orderNumber',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const Spacer(),
                    Text(
                      DateFormat.yMMMd().formatPh(createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Items preview (max 2)
                ...items.take(2).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade200),
                              color: Colors.grey[50],
                              image: item['productImage'] != null
                                  ? DecorationImage(
                                      image:
                                          NetworkImage(item['productImage']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: item['productImage'] == null
                                ? Icon(Icons.image,
                                    size: 16, color: Colors.grey[400])
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item['productName'] ?? 'Product',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'x${item['quantity'] ?? 1}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )),

                if (items.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${items.length - 2} more items',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Footer: Refund amount + action
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExchange ? 'Exchange Value' : 'Refund Amount',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        Text(
                          '₱${totalRefund.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReturnDetailPage(returnData: data),
                        ),
                      ),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'requested':
      case 'pending_review':
        return Colors.orange;
      case 'approved':
      case 'pickup_scheduled':
      case 'picked_up':
      case 'in_transit':
      case 'received':
      case 'inspecting':
      case 'refund_processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }
}
