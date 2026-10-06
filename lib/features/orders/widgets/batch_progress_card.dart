// trenda_frontend/lib/features/orders/widgets/batch_progress_card.dart
// Shows batch progress and handles interactive choices when batch is waiting or expired
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trenda_shared/trenda_shared.dart';
import '../../checkout/data/pasabay_repository.dart';


class BatchProgressCard extends StatefulWidget {
  final String orderId;
  final DeliveryBatchInfo? batchInfo;
  final bool requiresCustomerAction;
  final String? actionRequired;
  final VoidCallback? onHowItWorks;
  final VoidCallback? onLeaveBatch;
  final VoidCallback? onRefresh;

  const BatchProgressCard({
    super.key,
    required this.orderId,
    this.batchInfo,
    required this.requiresCustomerAction,
    this.actionRequired,
    this.onHowItWorks,
    this.onLeaveBatch,
    this.onRefresh,
  });

  @override
  State<BatchProgressCard> createState() => _BatchProgressCardState();
}

class _BatchProgressCardState extends State<BatchProgressCard> {
  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;
  bool _showHelpGuide = false;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _calculateTimeRemaining();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant BatchProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _calculateTimeRemaining();
    _startTimerIfNeeded();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _calculateTimeRemaining() {
    final expiresAt = widget.batchInfo?.estimatedDispatch; // Maps to estimatedBatchDate (expiresAt)
    if (expiresAt != null) {
      final diff = expiresAt.difference(DateTime.now());
      setState(() {
        _timeRemaining = diff.isNegative ? Duration.zero : diff;
      });
    } else {
      setState(() {
        _timeRemaining = Duration.zero;
      });
    }
  }

  void _startTimerIfNeeded() {
    _countdownTimer?.cancel();
    final isCollecting = widget.batchInfo?.batchStatus?.toLowerCase() == 'collecting';
    if (isCollecting && _timeRemaining > Duration.zero) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        _calculateTimeRemaining();
        if (_timeRemaining <= Duration.zero) {
          timer.cancel();
          widget.onRefresh?.call();
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return 'Expiring soon';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s remaining';
    }
    return '${minutes}m ${seconds}s remaining';
  }

  Future<void> _handleUpgradeToExpress() async {
    setState(() => _isActionLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final repo = PasabayRepository(
        baseUrl: AppConfig.backendBaseUrl,
        getToken: () => token,
      );

      final success = await repo.upgradeToExpress(widget.orderId);
      if (success) {
        widget.onRefresh?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully upgraded to Express Delivery!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('API rejected request');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upgrade delivery. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleRejoinBatch() async {
    setState(() => _isActionLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final repo = PasabayRepository(
        baseUrl: AppConfig.backendBaseUrl,
        getToken: () => token,
      );

      final success = await repo.rejoinBatch(widget.orderId);
      if (success) {
        widget.onRefresh?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Joined a new batch successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('API rejected request');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to rejoin a new batch. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _handleShareInvitation() {
    final batchCode = widget.batchInfo?.batchCode ?? '';
    final barangay = widget.batchInfo?.barangay ?? 'your barangay';
    
    if (batchCode.isEmpty) return;

    final inviteText = 'I just placed a Pasabay batch delivery order on Trenda! '
        'Join my batch $batchCode in $barangay so we can all save up to 70% on shipping fees! '
        'Join here: https://trenda.ph/pasabay?batch=$batchCode';

    Share.share(inviteText, subject: 'Join my Pasabay Batch on Trenda!');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.requiresCustomerAction && widget.actionRequired == 'reschedule') {
      return _buildChoiceCard(context);
    }

    if (widget.batchInfo == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final batchInfo = widget.batchInfo!;
    final progress = batchInfo.progress ?? 0.0;
    final isReady = batchInfo.isReady;
    final isCollecting = batchInfo.isCollecting;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isReady
              ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
              : [const Color(0xFFF5F5F5), const Color(0xFFFAFAFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isReady
                ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isReady
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isReady ? Icons.check_circle_rounded : Icons.groups_rounded,
                  size: 20,
                  color: isReady ? Colors.white : const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pasabay Batch',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isReady ? Colors.white : null,
                      ),
                    ),
                    if (batchInfo.batchCode != null)
                      Text(
                        batchInfo.batchCode!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isReady ? Colors.white70 : Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              _buildStatusChip(theme, isReady, isCollecting, batchInfo),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${batchInfo.currentBatchSize ?? 0} of ${batchInfo.targetBatchSize ?? 0} orders',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isReady ? Colors.white : null,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isReady ? Colors.white : const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: isReady
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    isReady ? Colors.white : const Color(0xFF4CAF50),
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),

          // Info row
          if (batchInfo.savings != null && batchInfo.savings! > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isReady
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFF4CAF50).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.savings_rounded,
                    size: 14,
                    color: isReady ? Colors.white : const Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'You\'re saving ₱${batchInfo.savings!.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isReady ? Colors.white : const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Live Countdown Timer
          if (isCollecting && _timeRemaining > Duration.zero) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_timeRemaining),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ] else if (batchInfo.expiresInMinutes != null && isCollecting) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  _formatExpiresIn(batchInfo.expiresInMinutes!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],

          // Invite Neighbors CTA (Only show when collecting)
          if (isCollecting && batchInfo.batchCode != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _handleShareInvitation,
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Invite Neighbors to Save More'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                  side: const BorderSide(color: Color(0xFF4CAF50)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],

          // Collapsible Help Guide (What happens next?)
          if (isCollecting) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                setState(() {
                  _showHelpGuide = !_showHelpGuide;
                });
              },
              child: Row(
                children: [
                  Text(
                    'What happens if the batch doesn\'t fill up?',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  Icon(
                    _showHelpGuide ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
            if (_showHelpGuide) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'If the batch limit is reached and the minimum orders aren\'t met, '
                  'the batch expires. You will get to choose whether to upgrade your order to Express Delivery '
                  'immediately, or rejoin a brand new batch.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],

          // Action buttons (Leave batch)
          if (isCollecting && (widget.onLeaveBatch != null || widget.onHowItWorks != null)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.onHowItWorks != null)
                  TextButton.icon(
                    onPressed: widget.onHowItWorks,
                    icon: const Icon(Icons.help_outline_rounded, size: 16),
                    label: const Text('How it works'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                const Spacer(),
                if (widget.onLeaveBatch != null)
                  TextButton(
                    onPressed: widget.onLeaveBatch,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Leave Batch'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChoiceCard(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pasabay Batch Expired',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your previous batch did not reach the minimum size in time. Please select how you would like to proceed with your order:',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (_isActionLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _handleUpgradeToExpress,
                icon: const Icon(Icons.flash_on_rounded, size: 16),
                label: const Text('Upgrade to Express Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _handleRejoinBatch,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Wait in a New Batch'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, bool isReady, bool isCollecting, DeliveryBatchInfo batchInfo) {
    final Color bgColor;
    final Color textColor;
    final String label;

    if (isReady) {
      bgColor = Colors.white.withValues(alpha: 0.2);
      textColor = Colors.white;
      label = 'Ready!';
    } else if (isCollecting) {
      bgColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFE65100);
      label = 'Collecting';
    } else {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade600;
      label = batchInfo.batchStatus ?? 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatExpiresIn(int minutes) {
    if (minutes <= 0) return 'Expiring soon';
    if (minutes < 60) return 'Expires in $minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours < 24) {
      return mins > 0
          ? 'Expires in ${hours}h ${mins}m'
          : 'Expires in ${hours}h';
    }
    final days = hours ~/ 24;
    return 'Expires in ${days}d ${hours % 24}h';
  }
}
